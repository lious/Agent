import 'dart:async';
import 'dart:io';

import 'atomic_file.dart';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart' show Uuid;
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

/// Created only by the trusted host after an explicit local file selection.
/// Never obtained from an LLM, archive, URL or model tool argument.
final class LocalFileGrant {
  LocalFileGrant.fromUserSelection(this.file);
  final File file;
}

final class ImportedBlob {
  ImportedBlob(this.hash, this.bytes, this.file);
  final String hash;
  final int bytes;
  final File file;
  Map<String, dynamic> toJson({String mime = 'application/octet-stream'}) => {
    'hash': hash,
    'bytes': bytes.toString(),
    'mime': mime,
    'packagePath': 'originals/${hash.substring(7)}',
    'role': 'original',
  };
}

/// Namespace-scoped immutable originals. A completed, hashed staging file is
/// published before its metadata can be placed into a project transaction.
final class BlobStore {
  BlobStore(
    Directory root,
    Namespace namespace, {
    this.maxImportBytes = 1024 * 1024 * 1024,
  }) : directory = Directory(
         p.join(
           root.absolute.path,
           contentHash(namespace.toJson()).substring(7),
           'blobs',
         ),
       ) {
    directory.createSync(recursive: true);
    _checkDirectory();
  }
  static final Map<String, Future<void>> _maintenance = {};

  /// All SDK publishers hold this through SQLite pin commit; GC uses the SAME
  /// stable lock. Do not unlink the lock file or nest this lease.
  Future<T> withMaintenanceLease<T>(Future<T> Function() action) async {
    final key = p.join(directory.parent.path, '.cas-maintenance.lock');
    final prior = _maintenance[key] ?? Future<void>.value(),
        done = Completer<void>();
    _maintenance[key] = done.future;
    await prior;
    RandomAccessFile? lock;
    var locked = false;
    try {
      _checkDirectory();
      lock = await File(key).open(mode: FileMode.append);
      await lock.lock(FileLock.blockingExclusive);
      locked = true;
      return await action();
    } finally {
      try {
        if (lock != null) {
          try {
            if (locked) await lock.unlock();
          } finally {
            await lock.close();
          }
        }
      } finally {
        done.complete();
        if (identical(_maintenance[key], done.future)) _maintenance.remove(key);
      }
    }
  }

  /// Caller holds maintenance lease AND a SQLite writer/pin-snapshot transaction.
  /// Only canonical unreferenced managed files are deleted; history pins remain.
  Map<String, int> collectUnreferenced(Set<String> retained) {
    _checkDirectory();
    var files = 0, bytes = 0;
    for (final entity in directory.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(name) ||
          retained.contains('sha256:$name')) {
        continue;
      }
      if (files >= 1000) break;
      if (FileSystemEntity.typeSync(entity.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw const StudioException('CAS_GC_UNSAFE_ENTRY');
      }
      final file = File(entity.path);
      bytes += file.lengthSync();
      file.deleteSync();
      files++;
    }
    if (files > 0) AtomicFilePublisher().syncDirectory(directory);
    return {'files': files, 'bytes': bytes};
  }

  final Directory directory;
  final int maxImportBytes;
  void _checkDirectory() {
    if (p.normalize(directory.resolveSymbolicLinksSync()) !=
        p.normalize(directory.absolute.path)) {
      throw const StudioException('SYMLINK_REFUSED');
    }
  }

  File _path(String hash) {
    if (!RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(hash)) {
      throw const StudioException('INVALID_HASH');
    }
    _checkDirectory();
    return File(p.join(directory.path, hash.substring(7)));
  }

  Future<ImportedBlob> importFile(
    LocalFileGrant grant, {
    String? expectedHash,
  }) async {
    _checkDirectory();
    if (FileSystemEntity.typeSync(grant.file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const StudioException('LOCAL_FILE_REQUIRED');
    }
    final before = grant.file.statSync();
    if (before.size > maxImportBytes) {
      throw const StudioException('IMPORT_LIMIT');
    }
    final stage = File(p.join(directory.path, '.import-${const Uuid().v7()}'));
    try {
      final sink = stage.openWrite(mode: FileMode.writeOnly);
      var size = 0;
      try {
        await for (final chunk in grant.file.openRead()) {
          size += chunk.length;
          if (size > maxImportBytes) {
            throw const StudioException('IMPORT_LIMIT');
          }
          sink.add(chunk);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      final after = grant.file.statSync();
      if (before.size != after.size ||
          before.modified != after.modified ||
          size != after.size) {
        throw const StudioException('SOURCE_CHANGED_DURING_IMPORT');
      }
      final hash = 'sha256:${await sha256.bind(stage.openRead()).first}';
      if (expectedHash != null && hash != expectedHash) {
        throw const StudioException('RELINK_HASH_MISMATCH');
      }
      final target = _path(hash);
      if (target.existsSync()) {
        await resolve(hash);
      } else {
        AtomicFilePublisher().publish(stage, target);
      }
      return ImportedBlob(hash, size, target);
    } finally {
      if (stage.existsSync()) stage.deleteSync();
    }
  }

  Future<File> resolve(String hash) async {
    final file = _path(hash);
    if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const StudioException('MISSING_MEDIA');
    }
    if ('sha256:${await sha256.bind(file.openRead()).first}' != hash) {
      throw const StudioException('BLOB_HASH_MISMATCH');
    }
    return file;
  }

  Future<void> putVerifiedBytes(String hash, List<int> bytes) async {
    if (bytes.length > maxImportBytes || rawBytesHash(bytes) != hash) {
      throw const StudioException('BLOB_HASH_MISMATCH');
    }
    final target = _path(hash);
    if (target.existsSync()) {
      await resolve(hash);
      return;
    }
    final stage = File(p.join(directory.path, '.restore-${const Uuid().v7()}'));
    try {
      stage.writeAsBytesSync(bytes, flush: true);
      AtomicFilePublisher().publish(stage, target);
    } finally {
      if (stage.existsSync()) stage.deleteSync();
    }
  }

  Future<ImportedBlob> relink(String expectedHash, LocalFileGrant grant) =>
      importFile(grant, expectedHash: expectedHash);
}

Future<String> hashLocalFile(File file) async =>
    'sha256:${await sha256.bind(file.openRead()).first}';
