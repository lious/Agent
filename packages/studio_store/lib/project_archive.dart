import 'proxy_resources.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:uuid/uuid.dart' show Uuid;
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

import 'atomic_file.dart';
import 'blob_store.dart';

/// s5b ArchiveOptions.mode. This is not a packMode enum; packMode stays
/// embedded or linked, and proxyOnly is only a sourceCompleteness value.
enum ArchiveExportMode { originals, proxies, linked }

/// DEV-PURE archive options for the I-013 unpackable-resource manifest
/// slice. sessionPolicy stays excluded; this is not job archival.
final class ArchiveOptions {
  const ArchiveOptions({
    this.mode = ArchiveExportMode.originals,
    this.sessionPolicy = 'excluded',
    this.externalLocatorPolicy = 'idsOnly',
  });

  final ArchiveExportMode mode;
  final String sessionPolicy, externalLocatorPolicy;
}

final class ArchiveOmission {
  const ArchiveOmission({required this.impact, this.targetId});

  final String impact;
  final String? targetId;
}

final class VerifiedArchive {
  VerifiedArchive(
    this.project,
    this.originals, {
    this.preservationOnly = false,
    this.packMode = 'embedded',
    this.missingExternalRefs = const [],
    this.sourceCompleteness = 'selfContained',
    this.needsRelink = false,
    this.omissions = const [],
  });
  final bool preservationOnly, needsRelink;
  final ProjectDocument project;
  final Map<String, Uint8List> originals;
  final String packMode, sourceCompleteness;
  final List<String> missingExternalRefs;
  final List<ArchiveOmission> omissions;
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
    File destination, {
    ArchiveOptions options = const ArchiveOptions(),
  }) async {
    final publisher = AtomicFilePublisher(),
        stage = AtomicFilePublisher().stagingFor(destination);
    try {
      await prepare(project, blobs, stage, options: options);
      publisher.publish(stage, destination);
    } finally {
      if (stage.existsSync()) stage.deleteSync();
    }
  }

  Future<void> prepare(
    ProjectDocument project,
    BlobStore blobs,
    File stage, {
    ArchiveOptions options = const ArchiveOptions(),
  }) => _prepare(
    project,
    stage,
    (blob, remaining) async {
      final file = await blobs.resolve(blob['hash'] as String);
      final builder = BytesBuilder(copy: false);
      var size = 0;
      await for (final chunk in file.openRead()) {
        size += chunk.length;
        if (size > remaining) throw const StudioException('ARCHIVE_LIMIT');
        builder.add(chunk);
      }
      return builder.takeBytes();
    },
    preservationOnly: false,
    options: options,
  );

  Future<void> preparePreservation(
    ProjectDocument project,
    Map<String, Uint8List> resources,
    File stage,
  ) => _prepare(project, stage, (blob, remaining) async {
    final data = resources[blob['hash']];
    if (data == null) throw const StudioException('RESOURCE_BYTES_MISSING');
    return data;
  }, preservationOnly: true);

  Future<Map<String, Uint8List>> _collectDeclared(
    ProjectDocument project,
    Future<Uint8List> Function(Map<String, dynamic>, int) load,
  ) async {
    final collected = <String, Uint8List>{};
    var remaining = maxExpandedBytes;
    for (final b in project.toJson()['blobs']) {
      final data = await load(Map<String, dynamic>.from(b), remaining);
      remaining -= data.length;
      if (remaining < 0) throw const StudioException('ARCHIVE_LIMIT');
      collected[b['hash']] = data;
    }
    return collected;
  }

  Future<void> _prepare(
    ProjectDocument project,
    File stage,
    Future<Uint8List> Function(Map<String, dynamic>, int) load, {
    required bool preservationOnly,
    ArchiveOptions options = const ArchiveOptions(),
  }) async {
    if (options.sessionPolicy != 'excluded') {
      throw const StudioException('FEATURE_NOT_IMPLEMENTED', 'sessionPolicy');
    }
    _refuseUrlLocators(project);
    if (!preservationOnly && options.mode == ArchiveExportMode.originals) {
      requireLocalEditingWritable(project);
    } else if (preservationOnly) {
      final issues =
          qualifyResourceClosure(
                project,
                await _collectDeclared(project, load),
              )['issues']
              as List;
      if (issues.isNotEmpty) {
        throw StudioException(
          issues.first['code'] as String,
          issues.first['path'] as String,
        );
      }
    }
    final files = <String, Uint8List>{};
    final snapshot = utf8.encode(project.canonicalJson),
        snapshotPath = 'snapshots/${project.hash.substring(7)}.json';
    files[snapshotPath] = Uint8List.fromList(snapshot);
    var size = snapshot.length;
    final packed = <Map<String, dynamic>>[];
    for (final blob in project.toJson()['blobs'] as List) {
      final row = Map<String, dynamic>.from(blob as Map);
      if (!_packsBlob(options.mode, row)) continue;
      packed.add(row);
      final data = await load(row, maxExpandedBytes - size);
      if (data.length.toString() != row['bytes']) {
        throw const StudioException('BLOB_SIZE_MISMATCH');
      }
      if (rawBytesHash(data) != row['hash']) {
        throw const StudioException('BLOB_HASH_MISMATCH');
      }

      size += data.length;
      if (size > maxExpandedBytes) throw const StudioException('ARCHIVE_LIMIT');
      files[row['packagePath'] as String] = data;
    }
    final packMode = options.mode == ArchiveExportMode.originals
        ? 'embedded'
        : 'linked';
    final missing = _missingOriginalAssetIds(project, packed);
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
      'packMode': packMode,
      'includedGroups': _includedGroups(
        project,
        packed,
        packMode: packMode,
        preservationOnly: preservationOnly,
      ),
      'missingExternalRefs': missing,
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
      preservationOnly: preservationOnly,
    ); // Validate the complete archive, not just the pre-ZIP maps.
    stage.createSync(exclusive: true);
    stage.writeAsBytesSync(bytes, flush: true);
  }

  VerifiedArchive open(File file, {bool preservationOnly = false}) {
    if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const StudioException('LOCAL_FILE_REQUIRED');
    }
    if (file.lengthSync() > maxArchiveBytes) {
      throw const StudioException('ARCHIVE_LIMIT');
    }
    return verifyBytes(
      file.readAsBytesSync(),
      preservationOnly: preservationOnly,
    );
  }

  VerifiedArchive verifyBytes(
    List<int> bytes, {
    bool preservationOnly = false,
  }) {
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
      final packMode = manifest['packMode'];
      if (manifest['format'] != 'studio-project' ||
          manifest['schemaVersion'] != '2.0.0' ||
          manifest['minReaderVersion'] != '2.0.0' ||
          (packMode != 'embedded' && packMode != 'linked') ||
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
          manifest['missingExternalRefs'] is! List) {
        throw const StudioException('MANIFEST_SCHEMA');
      }
      final missing = [
        for (final id in manifest['missingExternalRefs'] as List) id as String,
      ];
      for (final id in missing) {
        requireId(id);
      }
      if (packMode == 'embedded' &&
          contentHash(missing) != contentHash(<String>[])) {
        throw const StudioException('MANIFEST_SCHEMA');
      }
      final mode = packMode as String;
      final path = manifest['snapshotPath'];
      if (path is! String ||
          !RegExp(r'^snapshots/[a-f0-9]{64}\.json$').hasMatch(path)) {
        throw const StudioException('MANIFEST_SCHEMA');
      }
      final project = ProjectDocument.fromJson(jsonFile(path));
      if (!preservationOnly && mode == 'embedded') {
        requireLocalEditingWritable(project);
      }
      if (project.hash != manifest['snapshotHash'] ||
          path != 'snapshots/${project.hash.substring(7)}.json' ||
          project.projectId != manifest['projectId'] ||
          contentHash(project.namespace.toJson()) !=
              contentHash(manifest['namespace']) ||
          project.revision.toString() != manifest['revision']) {
        throw const StudioException('MANIFEST_SNAPSHOT_MISMATCH');
      }
      final packedRows = [
        for (final blob in project.toJson()['blobs'] as List)
          if (files.containsKey(blob['packagePath']))
            Map<String, dynamic>.from(blob as Map),
      ];
      if (contentHash(manifest['includedGroups']) !=
          contentHash(
            _includedGroups(
              project,
              packedRows,
              packMode: mode,
              preservationOnly: preservationOnly,
            ),
          )) {
        throw const StudioException('MANIFEST_SCHEMA');
      }
      final originals = <String, Uint8List>{};
      final expected = {'manifest.json', 'checksums.json', path};
      final missingOriginalHashes = {
        for (final a in project.toJson()['assets'] as List)
          if (missing.contains(a['id']) && a['originalBlobHash'] is String)
            a['originalBlobHash'] as String,
      };
      for (final blob in project.toJson()['blobs'] as List) {
        final blobPath = blob['packagePath'] as String;
        _safe(blobPath);
        final data = files[blobPath];
        final skippedOriginal = missingOriginalHashes.contains(blob['hash']);
        if (mode == 'linked' && skippedOriginal) {
          if (data != null) {
            throw const StudioException('ARCHIVE_UNDECLARED_ENTRY');
          }
          continue;
        }
        expected.add(blobPath);
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
      if (!preservationOnly && mode == 'embedded') {
        for (final a in project.toJson()['assets']) {
          for (final p in a['proxyRefs']) {
            validateProxyResourceBytes(
              a,
              p,
              originals[p['ptsMapBlobHash']]!,
              originals[p['blobHash']]!,
            );
          }
        }
      }
      final packedOriginals = packedRows.any((b) => b['role'] == 'original');
      final packedProxies = packedRows.any((b) => b['role'] == 'proxy');
      final hasLocatorIds = (project.toJson()['assets'] as List).any(
        (a) => a['externalLocator'] is String && a['externalLocator'] != null,
      );
      return VerifiedArchive(
        project,
        Map.unmodifiable(originals),
        preservationOnly: preservationOnly,
        packMode: mode,
        missingExternalRefs: List.unmodifiable(missing),
        sourceCompleteness: _sourceCompleteness(
          packMode: mode,
          missing: missing,
          packedOriginals: packedOriginals,
          packedProxies: packedProxies,
          hasLocatorIds: hasLocatorIds,
        ),
        needsRelink: mode == 'linked',
        omissions: _modelOmissions(project),
      );
    } on StudioException {
      rethrow;
    } on ArchiveException {
      throw const StudioException('ARCHIVE_DAMAGED');
    } on FormatException {
      throw const StudioException('ARCHIVE_DAMAGED');
    }
  }

  static bool _packsBlob(ArchiveExportMode mode, Map<String, dynamic> blob) {
    final role = blob['role'] as String?;
    switch (mode) {
      case ArchiveExportMode.originals:
        return true;
      case ArchiveExportMode.proxies:
        return role == 'proxy' || role == 'ptsMap';
      case ArchiveExportMode.linked:
        return role == 'font';
    }
  }

  static List<String> _missingOriginalAssetIds(
    ProjectDocument project,
    List<Map<String, dynamic>> packed,
  ) {
    final packedHashes = {for (final b in packed) b['hash'] as String};
    final ids = <String>[
      for (final a in project.toJson()['assets'] as List)
        if (a['originalBlobHash'] is String &&
            !packedHashes.contains(a['originalBlobHash']))
          a['id'] as String,
    ]..sort();
    for (final id in ids) {
      requireId(id);
    }
    return ids;
  }

  static List<String> _includedGroups(
    ProjectDocument project,
    List<Map<String, dynamic>> packed, {
    required String packMode,
    required bool preservationOnly,
  }) {
    final rows = packMode == 'embedded'
        ? [
            for (final b in project.toJson()['blobs'] as List)
              Map<String, dynamic>.from(b as Map),
          ]
        : packed;
    return [
      if (packMode == 'embedded') 'originals',
      if (preservationOnly && rows.any((b) => b['role'] == 'generated'))
        'generated',
      if ((packMode == 'embedded' &&
              preservationOnly &&
              rows.any((b) => b['role'] == 'font')) ||
          (packMode == 'linked' && rows.any((b) => b['role'] == 'font')))
        'fonts',
      if (rows.any((b) => b['role'] == 'proxy')) 'proxies',
    ];
  }

  static String _sourceCompleteness({
    required String packMode,
    required List<String> missing,
    required bool packedOriginals,
    required bool packedProxies,
    required bool hasLocatorIds,
  }) {
    if (packMode == 'embedded' && missing.isEmpty && packedOriginals) {
      return 'selfContained';
    }
    // An empty embedded document has no originals to pack; ZIP completion
    // alone does not make it selfContained.
    if (packMode == 'embedded' && missing.isEmpty && !packedOriginals) {
      return 'incomplete';
    }
    if (packMode == 'linked' &&
        packedProxies &&
        !packedOriginals &&
        missing.isNotEmpty) {
      return 'proxyOnly';
    }
    if (packMode == 'linked' && hasLocatorIds && !packedOriginals) {
      return 'externalRefs';
    }
    return 'incomplete';
  }

  static List<ArchiveOmission> _modelOmissions(ProjectDocument project) => [
    for (final ref in project.toJson()['modelRefs'] as List)
      ArchiveOmission(
        impact: 'reproGeneration',
        targetId: ref is Map && ref['id'] is String
            ? ref['id'] as String
            : null,
      ),
  ];

  /// External locators may be IDs only. HTTP/URL locators are not fetched
  /// and do not publish a package.
  static void _refuseUrlLocators(ProjectDocument project) {
    for (final a in project.toJson()['assets'] as List) {
      final locator = a['externalLocator'];
      if (locator is String &&
          (locator.contains('://') || locator.startsWith('http'))) {
        throw const StudioException(
          'FEATURE_NOT_IMPLEMENTED',
          'externalLocator',
        );
      }
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
  Map<String, String>? importIds,
}) {
  requireLocalEditingWritable(project);
  final d = project.toJson();
  final ids = <String, String>{project.projectId: newId()};
  void define(Map x) {
    ids[x['id'] as String] = newId();
  }

  for (final table in [
    'assets',
    'sequences',
    'audioBuses',
    'rightsRecords',
    'captions',
    'effects',
    'transitions',
    'linkGroups',
    'selectionGroups',
  ]) {
    for (final x in d[table]) {
      define(x as Map);
    }
  }
  for (final a in d['assets']) {
    for (final st in a['streams']) {
      define(st as Map);
    }
  }
  for (final seq in d['sequences']) {
    for (final t in seq['tracks']) {
      define(t as Map);
      for (final c in t['items']) {
        define(c as Map);
      }
    }
  }
  importIds?.addAll(ids);
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
    'leftClipId',
    'rightClipId',
    'effectId',
    'linkGroupId',
    'selectionGroupId',
  };
  void replace(dynamic x) {
    if (x is Map) {
      for (final e in x.entries.toList()) {
        if (refs.contains(e.key) &&
            e.value is String &&
            ids.containsKey(e.value)) {
          x[e.key] = ids[e.value];
        } else if (e.key == 'assetIds' ||
            e.key == 'inputBusIds' ||
            e.key == 'effectIds' ||
            e.key == 'memberClipIds') {
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
