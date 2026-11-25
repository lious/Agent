import 'dart:async';
import 'dart:io';

import 'package:studio_store/studio_store.dart';
import 'package:studio_store/atomic_file.dart';
import 'package:studio_store/blob_store.dart';
import 'package:studio_store/project_archive.dart';
import 'package:studio_document/studio_document.dart';

final class SaveReceipt {
  SaveReceipt(this.operationId, this.snapshot, this.artifactHash);
  final String operationId, artifactHash;
  final ProjectDocument snapshot;
}

final class SaveHandle {
  SaveHandle(this.operationId, this.snapshot);
  final String operationId;
  final ProjectDocument snapshot;
  final _result = Completer<SaveReceipt>();
  final _events = StreamController<String>.broadcast();
  Future<SaveReceipt> get result => _result.future;
  Stream<String> get progress => _events.stream;
  String phase = 'queued';
  bool _cancelled = false;
  String cancel() {
    if (phase == 'committed') return 'ALREADY_PUBLISHED';
    if (phase == 'publishing' || phase == 'published' || phase == 'uncertain') {
      return 'PUBLICATION_UNCERTAIN';
    }
    _cancelled = true;
    return 'CANCELLED_BEFORE_PUBLICATION';
  }

  void _phase(String next) {
    phase = next;
    _events.add(next);
  }
}

/// Serializes actual archive publications. SQLite remains authoritative: a
/// completed Future is delivered only AFTER fsync publication and a FULL receipt.
final class SaveCoordinator {
  SaveCoordinator(this.repository, this.blobs, {this.onPhase});
  final void Function(String phase, String operationId)? onPhase;
  static final _targetTails = <String, Future<void>>{};
  final DocumentRepository repository;
  final BlobStore blobs;
  final _inflight = <String, SaveHandle>{};
  Future<void>? _tail;
  int _reconciling = 0;
  bool get pending => _inflight.isNotEmpty || _reconciling > 0;
  Future<void> drain() => _tail ?? Future<void>.value();
  SaveHandle request(
    WriterToken writer,
    ProjectDocument snapshot,
    File destination,
  ) {
    final target = destination.absolute.uri.normalizePath().toFilePath();
    final key = contentHash({
      'snapshot': snapshot.hash,
      'target': target,
      'kind': 'explicitArchive',
      'owner': writer.owner,
      'fence': writer.epoch.toString(),
    });
    final previous = _inflight[key];
    if (previous != null) return previous;
    final stage = AtomicFilePublisher().stagingFor(destination);
    final id = repository.beginSave(
      writer,
      snapshot,
      targetPath: target,
      stagePath: stage.absolute.path,
      explicit: true,
    );
    final handle = SaveHandle(id, snapshot);
    _inflight[key] = handle;
    unawaited(
      _enqueue<void>(
        target,
        () => _execute(writer, snapshot, destination, stage, key, handle),
      ).catchError((Object error, StackTrace stack) {
        if (!handle._result.isCompleted) {
          handle._result.completeError(error, stack);
        }
      }),
    );
    return handle;
  }

  // fcntl locks are process-scoped: both the in-process queue and the
  // cross-process lock are needed, including reconciliation, not just saves.
  Future<T> _enqueue<T>(String target, Future<T> Function() action) {
    final result = Completer<T>();
    _tail = (_tail ?? Future<void>.value()).then((_) {
      final prior = _targetTails[target] ?? Future<void>.value();
      final task = prior.then((_) async {
        try {
          result.complete(await action());
        } catch (error, stack) {
          result.completeError(error, stack);
        }
      });
      _targetTails[target] = task;
      return task.whenComplete(() {
        if (identical(_targetTails[target], task)) _targetTails.remove(target);
      });
    });
    return result.future;
  }

  Future<RandomAccessFile> _lock(File destination) async {
    AtomicFilePublisher().stagingFor(destination);
    final target = destination.absolute.uri.normalizePath().toFilePath();
    final file = File(
      '${destination.absolute.parent.path}/.studio-lock-${contentHash(target).substring(7)}',
    );
    final type = FileSystemEntity.typeSync(file.path, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw const StudioException('UNSAFE_OUTPUT_TARGET');
    }
    final lock = await file.open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.blockingExclusive);
      return lock;
    } catch (_) {
      await lock.close();
      rethrow;
    }
  }

  Future<void> _execute(
    WriterToken writer,
    ProjectDocument snapshot,
    File destination,
    File stage,
    String key,
    SaveHandle handle,
  ) async {
    RandomAccessFile? lock;
    var publicationStarted = false;
    Object? failure;
    StackTrace? failureStack;
    SaveReceipt? receipt;
    void phase(String value) {
      handle._phase(value);
      onPhase?.call(value, handle.operationId);
    }

    void cancel() {
      if (handle._cancelled) {
        throw const StudioException('CANCELLED_BEFORE_PUBLICATION');
      }
    }

    try {
      cancel();
      repository.validateWriter(writer);
      final target = destination.absolute.uri.normalizePath().toFilePath();
      lock = await _lock(destination);
      cancel();
      phase('preparing');
      final old = destination.existsSync()
          ? await hashLocalFile(destination)
          : null;
      if (old != null) {
        ProjectArchive().open(
          destination,
        ); // Never replace a corrupt unique copy.
        final backup = File(
          '${destination.absolute.parent.path}/.studio-backup-${old.substring(7)}.archive',
        );
        if (backup.existsSync()) {
          if (await hashLocalFile(backup) != old) {
            throw const StudioException('BACKUP_HASH_MISMATCH');
          }
        } else {
          AtomicFilePublisher().write(backup, await destination.readAsBytes());
        }
      }
      await ProjectArchive().prepare(snapshot, blobs, stage);
      cancel();
      phase('verifying');
      if (ProjectArchive().open(stage).project.hash != snapshot.hash) {
        throw const StudioException('SAVE_HASH_MISMATCH');
      }
      final hash = await hashLocalFile(stage),
          now = destination.existsSync()
              ? await hashLocalFile(destination)
              : null;
      if (now != old) throw const StudioException('TARGET_VERSION_CONFLICT');
      final last = repository
          .persistenceView(snapshot.projectId, targetPath: target)
          .targetSavedRevision;
      if (last != null && last > snapshot.revision) {
        throw const StudioException('SAVE_PLAN_STALE');
      }
      repository.validateWriter(writer);
      cancel();
      repository.markSavePublishing(
        writer,
        handle.operationId,
        hash,
        oldHash: old,
      );
      phase('publishing');
      publicationStarted = true;
      AtomicFilePublisher().publish(stage, destination);
      phase('published');
      repository.finishSave(writer, handle.operationId, hash);
      phase('committed');
      receipt = SaveReceipt(handle.operationId, snapshot, hash);
    } catch (e, stack) {
      failure = e;
      failureStack = stack;
      try {
        repository.failSave(
          handle.operationId,
          e is StudioException ? e.code : 'LOCAL_SAVE_IO_FAILED',
          uncertain: publicationStarted,
          cancelled: handle._cancelled,
        );
      } catch (_) {
        /* Existing durable journal remains uncertain; never ACK. */
      }
      phase(
        publicationStarted
            ? 'uncertain'
            : handle._cancelled
            ? 'cancelled'
            : 'failed',
      );
    } finally {
      try {
        if (stage.existsSync()) stage.deleteSync();
      } catch (e, stack) {
        failure ??= e;
        failureStack ??= stack;
      }
      if (lock != null) {
        try {
          await lock.unlock();
        } catch (e, stack) {
          failure ??= e;
          failureStack ??= stack;
        } finally {
          try {
            await lock.close();
          } catch (e, stack) {
            failure ??= e;
            failureStack ??= stack;
          }
        }
      }
      _inflight.remove(key);
      unawaited(handle._events.close());
    }
    if (failure != null) {
      handle._result.completeError(failure, failureStack);
    } else {
      handle._result.complete(receipt!);
    }
  }

  /// Explicit host regrant only. Never execute a target path supplied by an
  /// archive/journal alone, never overwrite it while reconciling an uncertain ACK.
  Future<SaveReceipt> reconcile(
    WriterToken writer,
    String id,
    LocalFileGrant grant,
  ) {
    final target = grant.file.absolute.uri.normalizePath().toFilePath();
    _reconciling++;
    return _enqueue(target, () async {
      repository.validateWriter(writer);
      final op = repository.saveOperation(id);
      if (op['project_id'] != writer.projectId || op['target_path'] != target) {
        throw const StudioException('CHECKPOINT_SCOPE_MISMATCH');
      }
      if (!['publishing', 'uncertain'].contains(op['state'])) {
        throw const StudioException('SAVE_STATE_CONFLICT');
      }
      final lock = await _lock(grant.file);
      try {
        final verified = ProjectArchive().open(grant.file);
        final hash = await hashLocalFile(grant.file);
        if (hash != op['new_hash'] ||
            verified.project.hash != op['snapshot_hash']) {
          throw const StudioException('SAVE_RECONCILIATION_REQUIRED');
        }
        // An old receipt must not supersede a newer publication of this target.
        final last = repository
            .persistenceView(writer.projectId, targetPath: target)
            .targetSavedRevision;
        if (last != null && last > verified.project.revision) {
          throw const StudioException('SAVE_PLAN_STALE');
        }
        repository.validateWriter(writer);
        if (await hashLocalFile(grant.file) != hash) {
          throw const StudioException('TARGET_VERSION_CONFLICT');
        }
        AtomicFilePublisher().syncPublished(grant.file);
        repository.finishSave(writer, id, hash);
        return SaveReceipt(id, verified.project, hash);
      } finally {
        try {
          await lock.unlock();
        } finally {
          await lock.close();
        }
      }
    }).whenComplete(() => _reconciling--);
  }
}
