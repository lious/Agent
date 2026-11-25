import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:uuid/uuid.dart' show Uuid;
import 'package:studio_document/studio_document.dart';
import 'package:studio_store/atomic_file.dart';
import 'package:studio_store/blob_store.dart';
import 'package:studio_store/project_archive.dart';
import 'package:studio_contracts/studio_contracts.dart';

/// Read-only, file-backed resource preservation, NOT an editing Workspace.
/// Never selects a project, writes SQLite/CAS, installs fonts/plugins/models,
/// follows locators, or obtains files except an explicit LocalFileGrant.
final class ResourcePreservationSession {
  ResourcePreservationSession._(this.project);
  final ProjectDocument project;
  final Map<String, Uint8List> _resources = {};
  int _epoch = 0;
  static const maxResourceBytes = 64 * 1024 * 1024,
      maxCollectedBytes = 128 * 1024 * 1024,
      maxJsonBytes = 1024 * 1024;

  static Future<Uint8List> _read(LocalFileGrant grant, int max) async {
    final file = grant.file;
    if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const StudioException('LOCAL_FILE_REQUIRED');
    }
    final before = file.statSync();
    if (before.size > max) throw const StudioException('RESOURCE_LIMIT');
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in file.openRead()) {
      length += chunk.length;
      if (length > max || length > before.size) {
        throw const StudioException('RESOURCE_LIMIT');
      }
      builder.add(chunk);
    }
    final after = file.statSync();
    if (length != before.size ||
        after.size != before.size ||
        after.modified != before.modified) {
      throw const StudioException('SOURCE_CHANGED_DURING_IMPORT');
    }
    return builder.takeBytes();
  }

  static Future<ResourcePreservationSession> openJson(
    LocalFileGrant grant,
  ) async {
    final value = readStrictJson(
      await _read(grant, maxJsonBytes),
      maxBytes: maxJsonBytes,
    );
    if (value is! Map<String, dynamic>) {
      throw const StudioException('PROJECT_OBJECT_REQUIRED');
    }
    return ResourcePreservationSession._(ProjectDocument.fromJson(value));
  }

  static Future<ResourcePreservationSession> openArchive(
    LocalFileGrant grant,
  ) async {
    final archive = ProjectArchive().verifyBytes(
      await _read(grant, 128 * 1024 * 1024),
      preservationOnly: true,
    );
    final session = ResourcePreservationSession._(archive.project);
    var total = 0;
    for (final item in archive.originals.entries) {
      total += item.value.length;
      if (item.value.length > maxResourceBytes || total > maxCollectedBytes) {
        throw const StudioException('RESOURCE_LIMIT');
      }
      session._resources[item.key] = Uint8List.fromList(item.value);
    }
    return session;
  }

  Future<String> attach(LocalFileGrant grant) async {
    final epoch = _epoch;
    final bytes = await _read(grant, maxResourceBytes);
    if (epoch != _epoch) throw const StudioException('CANCELED');
    // Use the actual bytes, never filename/extension or a caller-claimed digest.
    final actual = rawBytesHash(bytes);
    final declared = (project.toJson()['blobs'] as List).where(
      (b) => b['hash'] == actual,
    );
    if (declared.length != 1) {
      throw const StudioException('DECLARED_RESOURCE_REQUIRED');
    }
    if (declared.single['bytes'] != bytes.length.toString()) {
      throw const StudioException('BLOB_SIZE_MISMATCH');
    }
    final total = _resources.entries
        .where((e) => e.key != actual)
        .fold<int>(bytes.length, (n, e) => n + e.value.length);
    if (total > maxCollectedBytes) {
      throw const StudioException('RESOURCE_LIMIT');
    }
    _resources[actual] = Uint8List.fromList(bytes);
    return actual;
  }

  Map<String, dynamic> get report {
    final result = qualifyResourceClosure(project, _resources);
    for (final r in result['resources']) {
      final data = _resources[r['hash']];
      r['byteIntegrity'] = data == null ? 'missing' : 'hashAndSizeVerified';
    }
    result['missingBytes'] = (result['resources'] as List)
        .where((r) => r['byteIntegrity'] == 'missing')
        .map((r) => r['hash'])
        .toList();
    result['allDeclaredBytesPresent'] =
        (result['missingBytes'] as List).isEmpty;
    result['writesWorkspaceOrCas'] = false;
    try {
      final document = project.toJson();
      final sequence = (document['sequences'] as List).singleWhere(
        (s) => s['id'] == document['rootSequenceId'],
      );
      result['definitionIdentity'] = {
        'profile': DefinitionFingerprinter.profile,
        'rootSequenceHash': DefinitionFingerprinter(
          project,
          _resources,
        ).source('sequence', sequence['id'], sequence['version']),
        'provesRenderEquivalence': false,
        'persistentStoreHashProfileUpgraded': false,
      };
    } on StudioException catch (e) {
      result['definitionIdentity'] = {
        'profile': DefinitionFingerprinter.profile,
        'unqualified': e.code,
        'provesRenderEquivalence': false,
      };
    }
    try {
      TimelineVideoGraph(project);
      result['writableProfile'] = 'eligibleForNativeQualification';
    } on StudioException catch (e) {
      result['writableProfile'] = 'readOnly';
      result['writableProfileReason'] = e.code;
    }
    return result;
  }

  String get collectionReviewHash => contentHash({
    'project': project.hash,
    'resources': _resources.keys.toList()..sort(),
  });
  void cancelPending() => _epoch++;
  ResourcePreservationSession fork(Namespace target) {
    final fork = ResourcePreservationSession._(
      forkResourceProject(project, target, newId: const Uuid().v7),
    );
    for (final entry in _resources.entries) {
      fork._resources[entry.key] = Uint8List.fromList(entry.value);
    }
    return fork;
  }

  /// Explicit consent authorizes only a local fork of the implemented renderer
  /// profile. Unsupported/opaque content is retained, never stripped to pass.
  Map<String, Uint8List> writableCollection(String expectedReviewHash) {
    if (expectedReviewHash != collectionReviewHash) {
      throw const StudioException('RESOURCE_COLLECTION_REVIEW_STALE');
    }
    requireLocalEditingWritable(project);
    TimelineVideoGraph(project);
    final r = report;
    if ((r['issues'] as List).isNotEmpty ||
        !(r['allDeclaredBytesPresent'] as bool)) {
      throw const StudioException('RESOURCE_CLOSURE_NOT_QUALIFIED');
    }
    return Map.unmodifiable(
      _resources.map((k, v) => MapEntry(k, Uint8List.fromList(v))),
    );
  }

  Future<void> saveMetadata(File target) async {
    final publisher = AtomicFilePublisher(),
        stage = AtomicFilePublisher().stagingFor(target);
    try {
      stage.createSync(exclusive: true);
      stage.writeAsBytesSync(utf8.encode(project.canonicalJson), flush: true);
      publisher.publishNew(stage, target);
    } finally {
      if (stage.existsSync()) stage.deleteSync();
    }
  }

  Future<void> saveArchive(
    File target, {
    required bool confirmedCollection,
    required String expectedCollectionReviewHash,
  }) async {
    if (!confirmedCollection) {
      throw const StudioException('RESOURCE_COLLECTION_CONFIRMATION_REQUIRED');
    }
    if (expectedCollectionReviewHash != collectionReviewHash) {
      throw const StudioException('RESOURCE_COLLECTION_REVIEW_STALE');
    }
    final snapshot = Map<String, Uint8List>.unmodifiable(_resources),
        epoch = _epoch;
    final publisher = AtomicFilePublisher(),
        stage = AtomicFilePublisher().stagingFor(target);
    try {
      await ProjectArchive().preparePreservation(project, snapshot, stage);
      if (epoch != _epoch) throw const StudioException('CANCELED');
      publisher.publishNew(stage, target);
    } finally {
      if (stage.existsSync()) stage.deleteSync();
    }
  }
}
