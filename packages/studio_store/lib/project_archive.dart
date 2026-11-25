import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:uuid/uuid.dart' show Uuid;
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

import 'atomic_file.dart';
import 'blob_store.dart';

final class VerifiedArchive {
  VerifiedArchive(this.project, this.originals);
  final ProjectDocument project;
  final Map<String, Uint8List> originals;
}

/// Embedded original-media archive for the admitted local-video subset. No ZIP
/// entry is ever extracted to an entry-supplied path, and no code is executed.
final class ProjectArchive {
  ProjectArchive({
    this.maxArchiveBytes = 128 * 1024 * 1024,
    this.maxExpandedBytes = 256 * 1024 * 1024,
  });
  final int maxArchiveBytes, maxExpandedBytes;
  Future<void> save(
    ProjectDocument project,
    BlobStore blobs,
    File destination,
  ) async {
    final publisher = AtomicFilePublisher(),
        stage = AtomicFilePublisher().stagingFor(destination);
    try {
      await prepare(project, blobs, stage);
      publisher.publish(stage, destination);
    } finally {
      if (stage.existsSync()) stage.deleteSync();
    }
  }

  Future<void> prepare(
    ProjectDocument project,
    BlobStore blobs,
    File stage,
  ) async {
    requireLocalEditingWritable(project);
    final files = <String, Uint8List>{};
    final snapshot = utf8.encode(project.canonicalJson),
        snapshotPath = 'snapshots/${project.hash.substring(7)}.json';
    files[snapshotPath] = Uint8List.fromList(snapshot);
    var size = snapshot.length;
    for (final blob in project.toJson()['blobs'] as List) {
      final file = await blobs.resolve(blob['hash'] as String);
      if (file.lengthSync() != int.parse(blob['bytes'] as String)) {
        throw const StudioException('BLOB_SIZE_MISMATCH');
      }
      size += file.lengthSync();
      if (size > maxExpandedBytes) throw const StudioException('ARCHIVE_LIMIT');
      files[blob['packagePath'] as String] = await file.readAsBytes();
    }
    final manifest = {
      'format': 'studio-project',
      'schemaVersion': '2.0.0',
      'minReaderVersion': '2.0.0',
      'archiveId': const Uuid().v7(),
      'projectId': project.projectId,
      'namespace': project.namespace.toJson(),
      'revision': project.revision.toString(),
      'snapshotPath': snapshotPath,
      'snapshotHash': project.hash,
      'packMode': 'embedded',
      'includedGroups': ['originals'],
      'missingExternalRefs': [],
      'checksumsPath': 'checksums.json',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'writerVersion': '0.2.0',
      'sessionArchive': null,
    };
    files['manifest.json'] = Uint8List.fromList(
      utf8.encode(jsonEncode(manifest)),
    );
    files['checksums.json'] = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'files': [
            for (final entry in files.entries)
              {
                'path': entry.key,
                'hash': rawBytesHash(entry.value),
                'bytes': entry.value.length.toString(),
              },
          ],
        }),
      ),
    );
    final zip = Archive();
    for (final entry in files.entries) {
      _safe(entry.key);
      zip.add(ArchiveFile.bytes(entry.key, entry.value));
    }
    final bytes = ZipEncoder().encode(zip);
    if (bytes.length > maxArchiveBytes) {
      throw const StudioException('ARCHIVE_LIMIT');
    }
    verifyBytes(
      bytes,
    ); // Validate the complete archive, not just the pre-ZIP maps.
    stage.createSync(exclusive: true);
    stage.writeAsBytesSync(bytes, flush: true);
  }

  VerifiedArchive open(File file) {
    if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const StudioException('LOCAL_FILE_REQUIRED');
    }
    if (file.lengthSync() > maxArchiveBytes) {
      throw const StudioException('ARCHIVE_LIMIT');
    }
    return verifyBytes(file.readAsBytesSync());
  }

  VerifiedArchive verifyBytes(List<int> bytes) {
    if (bytes.length > maxArchiveBytes) {
      throw const StudioException('ARCHIVE_LIMIT');
    }
    try {
      final directory = ZipDirectory()
        ..read(InputMemoryStream(bytes), verify: true);
      if (directory.fileHeaders.length > 10000) {
        throw const StudioException('ARCHIVE_LIMIT');
      }
      final names = <String>{};
      var expanded = 0;
      for (final h in directory.fileHeaders) {
        _safe(h.filename);
        if (!names.add(h.filename)) {
          throw const StudioException('ARCHIVE_DUPLICATE_PATH');
        }
        if (h.generalPurposeBitFlag & 1 != 0 ||
            h.externalFileAttributes >> 16 & 0xf000 == 0xa000) {
          throw const StudioException('ARCHIVE_UNSAFE_ENTRY');
        }
        expanded += h.uncompressedSize;
        if (h.uncompressedSize < 0 || expanded > maxExpandedBytes) {
          throw const StudioException('ARCHIVE_LIMIT');
        }
      }
      final archive = ZipDecoder().decodeBytes(
        bytes,
        verify: true,
        throwOnError: true,
      );
      if (archive.length != names.length) {
        throw const StudioException('ARCHIVE_DIRECTORY_MISMATCH');
      }
      final files = <String, Uint8List>{};
      for (final entry in archive) {
        _safe(entry.name);
        if (!names.contains(entry.name) || files.containsKey(entry.name)) {
          throw const StudioException('ARCHIVE_DIRECTORY_MISMATCH');
        }
        if (!entry.isFile || entry.isSymbolicLink) {
          throw const StudioException('ARCHIVE_UNSAFE_ENTRY');
        }
        final content = entry.content;
        if (content.length != entry.size) {
          throw const StudioException('ARCHIVE_SIZE_MISMATCH');
        }
        files[entry.name] = content;
      }
      Map<String, dynamic> jsonFile(String path) {
        final b = files[path];
        if (b == null) throw const StudioException('ARCHIVE_MISSING_ENTRY');
        final value = readStrictJson(b);
        if (value is! Map<String, dynamic>) {
          throw const StudioException('INVALID_JSON');
        }
        return value;
      }

      final checks = jsonFile('checksums.json');
      if (checks.keys.length != 1 || checks['files'] is! List) {
        throw const StudioException('CHECKSUM_SCHEMA');
      }
      final checked = <String>{'checksums.json'};
      for (final check in checks['files'] as List) {
        if (check is! Map ||
            check.length != 3 ||
            check['path'] is! String ||
            check['hash'] is! String ||
            check['bytes'] is! String) {
          throw const StudioException('CHECKSUM_SCHEMA');
        }
        final path = check['path'] as String;
        _safe(path);
        if (!checked.add(path)) {
          throw const StudioException('ARCHIVE_DUPLICATE_PATH');
        }
        final data = files[path];
        if (data == null ||
            rawBytesHash(data) != check['hash'] ||
            data.length.toString() != check['bytes']) {
          throw const StudioException('ARCHIVE_CHECKSUM_MISMATCH');
        }
      }
      if (checked.length != files.length ||
          !files.keys.every(checked.contains)) {
        throw const StudioException('ARCHIVE_UNCHECKED_ENTRY');
      }
      final manifest = jsonFile('manifest.json');
      const required = [
        'format',
        'schemaVersion',
        'minReaderVersion',
        'archiveId',
        'projectId',
        'namespace',
        'revision',
        'snapshotPath',
        'snapshotHash',
        'packMode',
        'includedGroups',
        'missingExternalRefs',
        'checksumsPath',
        'createdAt',
        'writerVersion',
        'sessionArchive',
      ];
      if (manifest.length != required.length ||
          !required.every(manifest.containsKey)) {
        throw const StudioException('MANIFEST_SCHEMA');
      }
      if (manifest['format'] != 'studio-project' ||
          manifest['schemaVersion'] != '2.0.0' ||
          manifest['minReaderVersion'] != '2.0.0' ||
          manifest['packMode'] != 'embedded' ||
          manifest['sessionArchive'] != null ||
          manifest['checksumsPath'] != 'checksums.json') {
        throw const StudioException('ARCHIVE_VERSION_UNSUPPORTED');
      }
      if (manifest['archiveId'] is! String ||
          !RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(manifest['archiveId'] as String) ||
          manifest['writerVersion'] is! String ||
          !RegExp(r'^\d+\.\d+\.\d+$')
              .hasMatch(manifest['writerVersion'] as String) ||
          manifest['createdAt'] is! String ||
          !((manifest['createdAt'] as String).endsWith('Z')) ||
          DateTime.tryParse(manifest['createdAt'] as String) == null ||
          contentHash(manifest['includedGroups']) !=
              contentHash(['originals']) ||
          contentHash(manifest['missingExternalRefs']) != contentHash([])) {
        throw const StudioException('MANIFEST_SCHEMA');
      }
      final path = manifest['snapshotPath'];
      if (path is! String ||
          !RegExp(r'^snapshots/[a-f0-9]{64}\.json$').hasMatch(path)) {
        throw const StudioException('MANIFEST_SCHEMA');
      }
      final project = ProjectDocument.fromJson(jsonFile(path));
      requireLocalEditingWritable(project);
      if (project.hash != manifest['snapshotHash'] ||
          path != 'snapshots/${project.hash.substring(7)}.json' ||
          project.projectId != manifest['projectId'] ||
          contentHash(project.namespace.toJson()) !=
              contentHash(manifest['namespace']) ||
          project.revision.toString() != manifest['revision']) {
        throw const StudioException('MANIFEST_SNAPSHOT_MISMATCH');
      }
      final originals = <String, Uint8List>{};
      final expected = {'manifest.json', 'checksums.json', path};
      for (final blob in project.toJson()['blobs'] as List) {
        final blobPath = blob['packagePath'] as String;
        _safe(blobPath);
        expected.add(blobPath);
        final data = files[blobPath];
        if (data == null ||
            rawBytesHash(data) != blob['hash'] ||
            data.length.toString() != blob['bytes']) {
          throw const StudioException('BLOB_HASH_MISMATCH');
        }
        originals[blob['hash'] as String] = data;
      }
      if (expected.length != files.length ||
          !files.keys.every(expected.contains)) {
        throw const StudioException('ARCHIVE_UNDECLARED_ENTRY');
      }
      return VerifiedArchive(project, Map.unmodifiable(originals));
    } on StudioException {
      rethrow;
    } on ArchiveException {
      throw const StudioException('ARCHIVE_DAMAGED');
    } on FormatException {
      throw const StudioException('ARCHIVE_DAMAGED');
    }
  }

  static void _safe(String path) {
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.contains('\\') ||
        path.contains('%') ||
        path.contains(':') ||
        path.contains('\x00') ||
        path.split('/').any((s) => s.isEmpty || s == '.' || s == '..')) {
      throw const StudioException('ARCHIVE_UNSAFE_PATH');
    }
  }
}

/// Explicit fork: remap namespace and every owned/reference ID; never migrate
/// approvals, sessions, secrets or runtime file handles through the archive.
ProjectDocument forkLocalProject(
  ProjectDocument project,
  Namespace target, {
  required String Function() newId,
}) {
  requireLocalEditingWritable(project);
  final d = project.toJson();
  final ids = <String, String>{project.projectId: newId()};
  void collect(dynamic x) {
    if (x is Map) {
      if (x['id'] is String) ids.putIfAbsent(x['id'] as String, newId);
      for (final e in x.entries) {
        if (e.key != 'namespace') collect(e.value);
      }
    } else if (x is List) {
      for (final v in x) {
        collect(v);
      }
    }
  }

  collect(d);
  const refs = {
    'id',
    'projectId',
    'rootSequenceId',
    'sequenceId',
    'trackId',
    'masterBusId',
    'busId',
    'outputBusId',
    'rightsId',
    'streamId',
    'clipId',
    'anchorClipId',
    'linkGroupId',
  };
  void replace(dynamic x) {
    if (x is Map) {
      for (final e in x.entries.toList()) {
        if (refs.contains(e.key) &&
            e.value is String &&
            ids.containsKey(e.value)) {
          x[e.key] = ids[e.value];
        } else if (e.key == 'assetIds' || e.key == 'inputBusIds') {
          x[e.key] = (e.value as List).map((v) => ids[v] ?? v).toList();
        } else if (e.key != 'namespace') {
          replace(e.value);
        }
      }
    } else if (x is List) {
      for (final v in x) {
        replace(v);
      }
    }
  }

  replace(d);
  d['namespace'] = target.toJson();
  d['revision'] = '0';
  final fork = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(fork);
  return fork;
}
