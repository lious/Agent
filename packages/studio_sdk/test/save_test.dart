import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_sdk/save_coordinator.dart';
import 'package:studio_store/studio_store.dart';
import 'package:studio_store/blob_store.dart';
import 'package:studio_store/project_archive.dart';
import 'package:test/test.dart';

Matcher error(String code) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', code));
void main() {
  test('virtual monotonic clock: idle, continuous maximum, 50 commits, lifecycle flush', () {
    fakeAsync((clock) {
      var saves = 0;
      final a = AutosaveScheduler(checkpoint: () => saves++);
      a.onDurableCommit();
      clock.elapse(const Duration(milliseconds: 1999));
      expect(saves, 0);
      clock.elapse(const Duration(milliseconds: 1));
      expect(saves, 1);
      for (var i = 0; i < 30; i++) {
        a.onDurableCommit();
        clock.elapse(const Duration(seconds: 1));
      }
      expect(saves, 2);
      for (var i = 0; i < 50; i++) {
        a.onDurableCommit();
      }
      expect(saves, 3);
      a.onDurableCommit();
      a.flush();
      expect(saves, 4);
      a.dispose();
      clock.elapse(const Duration(minutes: 5));
      expect(saves, 4);
    });
  });
  test(
    'scheduler surfaces failure, retains pending and explicit retry succeeds',
    () {
      fakeAsync((clock) {
        var fail = true, errors = 0, saved = 0;
        final a = AutosaveScheduler(
          checkpoint: () {
            if (fail) throw StateError('disk');
            saved++;
          },
          onError: (_) => errors++,
        );
        a.onDurableCommit();
        clock.elapse(const Duration(seconds: 2));
        expect(errors, 1);
        expect(a.pending, true);
        expect(a.lastError, isNotNull);
        fail = false;
        a.flush();
        expect(saved, 1);
        expect(a.pending, false);
        expect(a.lastError, isNull);
        a.dispose();
      });
    },
  );
  test('actual workspace autosave derives checkpoint without claiming user/package save', () {
    fakeAsync((clock) {
      final dir = Directory.systemTemp.createTempSync('checkpoint-clock-');
      final w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'test',
          region: 'local',
          features: {'project.metadata'},
        ),
        databasePath: '${dir.path}/db.sqlite',
        tenantId: 'local',
        workspaceId: 'clock',
      );
      try {
        w.openDemo();
        w.rename('committed', expectedRevision: BigInt.zero);
        expect(w.persistence().headRevision, BigInt.one);
        expect(w.persistence().checkpointRevision, BigInt.zero);
        clock.elapse(const Duration(seconds: 2));
        expect(w.persistence().checkpointRevision, BigInt.one);
        expect(w.persistence().userSavedRevision, isNull);
        expect(w.saveManaged(), BigInt.one);
        expect(w.persistence().userSavedRevision, BigInt.one);
      } finally {
        w.close();
        dir.deleteSync(recursive: true);
      }
    });
  });
  group('real save journal/filesystem', () {
    late Directory dir;
    late DocumentRepository repo;
    late BlobStore blobs;
    late WriterToken writer;
    late ProjectDocument before;
    late File target;
    var command = 0;
    setUp(() async {
      dir = Directory.systemTemp.createTempSync('save-journal-');
      final ns = Namespace('test', 'local', 'saves');
      repo = DocumentRepository.open('${dir.path}/db.sqlite', ns);
      before = ProjectDocument.empty(
        namespace: ns,
        projectId: 'p',
        title: 'before',
      );
      repo.create(before);
      writer = repo.acquireWriter('p', 'owner', expectedEpoch: 0);
      blobs = BlobStore(Directory('${dir.path}/media'), ns);
      target = File('${dir.path}/good.archive');
      await ProjectArchive().save(before, blobs, target);
    });
    tearDown(() {
      repo.close();
      dir.deleteSync(recursive: true);
    });
    void rename() {
      final id = 'rename-${command++}';
      repo.rename(
        writer: writer,
        commandId: id,
        receiptKey: id,
        expectedRevision: repo.read('p')!.revision,
        title: id,
      );
    }

    test('identical requests coalesce; edits during save never move head or saved receipt backwards', () async {
      final c = SaveCoordinator(repo, blobs),
          a = c.request(writer, before, target),
          b = c.request(writer, before, target);
      expect(identical(a, b), true);
      rename();
      final head = repo.read('p')!;
      final later = c.request(writer, head, target);
      expect((await a.result).snapshot.hash, before.hash);
      expect(repo.read('p')!.hash, head.hash);
      await later.result;
      expect(ProjectArchive().open(target).project.hash, head.hash);
      final view = repo.persistenceView('p', targetPath: target.absolute.path);
      expect(view.headRevision, BigInt.one);
      expect(view.targetSavedRevision, BigInt.one);
      expect(view.userSavedRevision, BigInt.one);
      expect(view.packageBehind, false);
      expect(
        dir.listSync().where((e) => e.path.contains('.studio-backup-')),
        isNotEmpty,
      );
    });
    test('queued cancellation does not publish or manufacture a receipt; retry works', () async {
      rename();
      final c = SaveCoordinator(repo, blobs),
          h = c.request(writer, repo.read('p')!, target);
      expect(h.cancel(), 'CANCELLED_BEFORE_PUBLICATION');
      await expectLater(h.result, error('CANCELLED_BEFORE_PUBLICATION'));
      expect(ProjectArchive().open(target).project.hash, before.hash);
      expect(repo.persistenceView('p').userSavedRevision, isNull);
      await c.request(writer, repo.read('p')!, target).result;
    });
    test('actual receipt INSERT failure leaves uncertain publication and explicit regrant reconciles after reopen', () async {
      rename();
      final c = SaveCoordinator(repo, blobs),
          db = sqlite3.open('${dir.path}/db.sqlite');
      db.execute(
        "CREATE TRIGGER receipt_failure BEFORE INSERT ON save_receipts BEGIN SELECT RAISE(ABORT,'injected receipt failure'); END",
      );
      final h = c.request(writer, repo.read('p')!, target);
      await expectLater(h.result, throwsA(isA<SqliteException>()));
      expect(h.phase, 'uncertain');
      expect(repo.pendingSaveOperations('p').single['state'], 'uncertain');
      expect(repo.persistenceView('p').userSavedRevision, isNull);
      expect(ProjectArchive().open(target).project.revision, BigInt.one);
      db.execute('DROP TRIGGER receipt_failure');
      db.dispose();
      repo.close();
      repo = DocumentRepository.open('${dir.path}/db.sqlite', before.namespace);
      writer = repo.acquireWriter('p', 'reopened', expectedEpoch: 1);
      final reopened = SaveCoordinator(repo, blobs);
      await expectLater(
        reopened.reconcile(
          writer,
          h.operationId,
          LocalFileGrant.fromUserSelection(File('${dir.path}/wrong')),
        ),
        error('CHECKPOINT_SCOPE_MISMATCH'),
      );
      final hash = await hashLocalFile(target);
      await reopened.reconcile(
        writer,
        h.operationId,
        LocalFileGrant.fromUserSelection(target),
      );
      expect(await hashLocalFile(target), hash);
      expect(repo.pendingSaveOperations('p'), isEmpty);
      expect(repo.read('p')!.revision, BigInt.one);
      expect(
        repo
            .persistenceView('p', targetPath: target.absolute.path)
            .targetSavedRevision,
        BigInt.one,
      );
    });
    test(
      'receipt replay is idempotent only for its committed artifact hash',
      () async {
        final receipt = await SaveCoordinator(
          repo,
          blobs,
        ).request(writer, before, target).result;
        repo.finishSave(writer, receipt.operationId, receipt.artifactHash);
        expect(
          () => repo.finishSave(
            writer,
            receipt.operationId,
            'sha256:${'a' * 64}',
          ),
          error('SAVE_HASH_MISMATCH'),
        );
        expect(repo.persistenceView('p').userSavedRevision, BigInt.zero);
      },
    );
    test('corrupt only-copy target and corrupt backup never get overwritten; queue remains usable', () async {
      target.writeAsStringSync('unique corrupt user bytes');
      final c = SaveCoordinator(repo, blobs);
      await expectLater(
        c.request(writer, before, target).result,
        throwsA(isA<StudioException>()),
      );
      expect(target.readAsStringSync(), 'unique corrupt user bytes');
      final other = File('${dir.path}/new.archive');
      await c.request(writer, before, other).result;
      final hash = await hashLocalFile(other);
      final backup = File(
        '${dir.path}/.studio-backup-${hash.substring(7)}.archive',
      )..writeAsStringSync('corrupt backup');
      rename();
      await expectLater(
        c.request(writer, repo.read('p')!, other).result,
        error('BACKUP_HASH_MISMATCH'),
      );
      expect(await hashLocalFile(other), hash);
      expect(backup.readAsStringSync(), 'corrupt backup');
    });
    test('staging failure preserves old copy and no successful receipt; explicit retry succeeds', () async {
      final hash = await hashLocalFile(target);
      final c = SaveCoordinator(
        repo,
        blobs,
        onPhase: (phase, _) {
          if (phase == 'verifying') {
            throw StateError('injected after real stage write');
          }
        },
      );
      await expectLater(
        c.request(writer, before, target).result,
        throwsStateError,
      );
      expect(await hashLocalFile(target), hash);
      expect(repo.persistenceView('p').userSavedRevision, isNull);
      expect(dir.listSync().where((f) => f.path.endsWith('.pending')), isEmpty);
      await SaveCoordinator(repo, blobs).request(writer, before, target).result;
      expect(repo.persistenceView('p').userSavedRevision, BigInt.zero);
    });
    test(
      'external target change and stale writer refuse publication',
      () async {
        rename();
        final c = SaveCoordinator(
          repo,
          blobs,
          onPhase: (phase, _) {
            if (phase == 'verifying') {
              target.writeAsStringSync('external modification');
            }
          },
        );
        await expectLater(
          c.request(writer, repo.read('p')!, target).result,
          error('TARGET_VERSION_CONFLICT'),
        );
        expect(target.readAsStringSync(), 'external modification');
        final fresh = repo.acquireWriter('p', 'new-owner', expectedEpoch: 1);
        expect(fresh.epoch, 2);
        expect(
          () => c.request(
            writer,
            repo.read('p')!,
            File('${dir.path}/new.archive'),
          ),
          error('WRITER_FENCED'),
        );
      },
    );
    test('two coordinators serialize a shared target and older snapshots cannot overwrite newer receipts', () async {
      final first = SaveCoordinator(
        repo,
        blobs,
      ).request(writer, before, target);
      rename();
      final current = repo.read('p')!;
      final second = SaveCoordinator(
        repo,
        blobs,
      ).request(writer, current, target);
      await Future.wait([first.result, second.result]);
      expect(ProjectArchive().open(target).project.hash, current.hash);
      await expectLater(
        SaveCoordinator(repo, blobs).request(writer, before, target).result,
        error('SAVE_PLAN_STALE'),
      );
      expect(ProjectArchive().open(target).project.hash, current.hash);
    });
  });
}
