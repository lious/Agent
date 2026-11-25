export 'resource_preservation.dart';
import 'resource_preservation.dart';

import 'package:studio_store/proxy_resources.dart';

import 'frame_proxy.dart';
export 'frame_proxy.dart' show TimelinePreviewFrame;
import 'preview_cache.dart';
export 'preview_cache.dart';

import 'package:studio_peer_io/compute_session.dart';
export 'package:studio_peer_io/compute_session.dart';

import 'dart:convert';
import 'dart:async';

import 'autosave_scheduler.dart';
import 'save_coordinator.dart';
export 'autosave_scheduler.dart';
export 'save_coordinator.dart' show SaveHandle, SaveReceipt;

import 'dart:io';

import 'package:studio_store/blob_store.dart';
import 'package:studio_store/atomic_file.dart';
import 'package:studio_store/project_archive.dart';
import 'package:studio_media/studio_media.dart';
import 'package:studio_store/studio_store.dart';
import 'package:studio_document/studio_document.dart';
import 'package:uuid/uuid.dart';
export 'package:studio_contracts/studio_contracts.dart';
export 'package:studio_document/studio_document.dart';
export 'package:studio_harness/studio_harness.dart';

export 'ports.dart';

export 'package:studio_store/blob_store.dart' show LocalFileGrant;
export 'package:studio_media/studio_media.dart' show NativeMedia;

/// Composition root for both hosts. No media, model, payment or upload port is
/// implicitly installed. All mutating calls use the same repository coordinator.
final class StudioWorkspace {
  StudioWorkspace.open({
    required this.profile,
    required String databasePath,
    required String tenantId,
    required String workspaceId,
    String? mediaLibraryPath,
    String? mediaRootPath,
  }) : _databasePath = File(databasePath).absolute.uri
           .normalizePath()
           .toFilePath(),
       _repository = DocumentRepository.open(
         databasePath,
         profile.namespace(tenantId, workspaceId),
       ) {
    try {
      if ((mediaLibraryPath == null) != (mediaRootPath == null)) {
        throw const StudioException('MEDIA_CONFIGURATION_INCOMPLETE');
      }
      if (mediaLibraryPath != null && mediaRootPath != null) {
        _blobs = BlobStore(Directory(mediaRootPath), _repository.namespace);
        _blobs!.noteDatabaseUsage(_databasePath);
        _media = NativeMedia.open(mediaLibraryPath, _repository.namespace);
        _saves = SaveCoordinator(_repository, _blobs!);
      }
    } catch (_) {
      _repository.close();
      rethrow;
    }
  }
  final AppProfile profile;
  final String _databasePath;
  final Set<String> _selectedInputs = {};
  final DocumentRepository _repository;
  final _uuid = const Uuid();

  /// Production editing entity IDs, shared with persistent-store allocation.
  String newEntityId() => _uuid.v7();
  WriterToken? _writer;
  BlobStore? _blobs;
  NativeMedia? _media;
  AutosaveScheduler? _autosave;
  SaveCoordinator? _saves;
  String _activeProjectId = 'demo-project';
  int _exportCancelEpoch = 0;
  bool _closed = false;
  final _persistenceEvents = StreamController<void>.broadcast(sync: true);
  Stream<void> get persistenceEvents => _persistenceEvents.stream;
  Object? get checkpointError => _autosave?.lastError;
  void _notifyPersistence() {
    if (!_closed) _persistenceEvents.add(null);
  }

  void _captureCheckpoint() {
    _repository.captureCheckpoint(_writer!);
    _notifyPersistence();
  }

  void _durableCommit() {
    _autosave?.onDurableCommit();
    _notifyPersistence();
  }

  NativeMedia? get media => _media;
  List<int>? receivedPeerBlob(String hash) {
    _requireMetadata();
    return _repository.receivedPeerBlob(hash);
  }

  String get peerStorageScope => _repository.namespace.key;
  // flutter_secure_storage_linux mutates an app-wide aggregate item. All
  // namespace identities must share this OS-user-root lock, not lock per key.
  String get peerIdentityLockPath =>
      '${Directory.systemTemp.path}/studio-peer-identity-store-${contentHash({'userRoot': Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? Directory.systemTemp.path}).substring(7)}.lock';
  ComputeSessionCoordinator createMetadataComputeSession(String sessionId) {
    _requireMetadata();
    return ComputeSessionCoordinator(
      _repository,
      _activeProjectId,
      id: sessionId,
    );
  }

  List<Map<String, dynamic>> recoverableMetadataSessions(
    String ownerFingerprint,
  ) {
    _requireMetadata();
    return _repository.metadataSessions(_activeProjectId, ownerFingerprint);
  }

  ComputeSessionCoordinator recoverMetadataSession(
    String sessionId,
    String planHash,
    String ownerFingerprint,
  ) {
    _requireMetadata();
    return ComputeSessionCoordinator.recover(
      _repository,
      _activeProjectId,
      sessionId: sessionId,
      planHash: planHash,
      ownerFingerprint: ownerFingerprint,
    );
  }

  String get projectId => _activeProjectId;
  void _requireMetadata() {
    if (!profile.features.contains('project.metadata')) {
      throw const StudioException('CAPABILITY_UNAVAILABLE');
    }
  }

  ProjectDocument openDemo() {
    clearPreviewProxies();
    _requireMetadata();
    _activeProjectId = _repository.selectedProjectId ?? 'demo-project';
    var project = _repository.read(_activeProjectId);
    if (project == null) {
      project = ProjectDocument.empty(
        namespace: _repository.namespace,
        projectId: 'demo-project',
        title: 'Untitled',
      );
      _repository.create(project);
    }
    _repository.selectProject(project.projectId);
    _writer = _repository.acquireWriter(
      project.projectId,
      _uuid.v7(),
      expectedEpoch: _repository.writerEpoch(project.projectId),
    );
    _autosave?.dispose();
    _autosave = AutosaveScheduler(
      checkpoint: _captureCheckpoint,
      onError: (_) => _notifyPersistence(),
    );
    _repository.captureCheckpoint(_writer!);
    return project;
  }

  ProjectDocument get current => _repository.read(_activeProjectId)!;
  bool get canUndo => _repository.latestCommandId(_activeProjectId) != null;
  ProjectDocument rename(String title, {required BigInt expectedRevision}) {
    stopTimelinePlayback();
    _requireMetadata();
    if (_writer == null) throw const StudioException('PROJECT_NOT_OPEN');
    final id = _uuid.v7();
    _repository.rename(
      writer: _writer!,
      commandId: id,
      receiptKey: id,
      expectedRevision: expectedRevision,
      title: title,
    );
    final result = current;
    if (result.revision != expectedRevision) _durableCommit();
    return result;
  }

  ProjectDocument undo({required BigInt expectedRevision}) {
    stopTimelinePlayback();
    _requireMetadata();
    if (_writer == null) throw const StudioException('PROJECT_NOT_OPEN');
    final target = _repository.latestCommandId(_activeProjectId);
    if (target == null) throw const StudioException('NOTHING_TO_UNDO');
    final id = _uuid.v7();
    _repository.undoLatest(
      writer: _writer!,
      commandId: id,
      receiptKey: id,
      expectedRevision: expectedRevision,
      targetCommandId: target,
    );
    final result = current;
    if (result.revision != expectedRevision) _durableCommit();
    return result;
  }

  void _requireMedia() {
    _requireMetadata();
    if (_media == null || _blobs == null) {
      throw const StudioException('MEDIA_ADAPTER_NOT_INSTALLED');
    }
    if (!profile.features.contains('media.local')) {
      throw const StudioException('CAPABILITY_UNAVAILABLE');
    }
  }

  ProjectDocument edit(
    EditOperation operation, {
    required BigInt expectedRevision,
  }) {
    if (operation is AppendVideoAsset ||
        operation is AttachPreviewProxies ||
        operation is DiscardPreviewProxies) {
      throw const StudioException('CONTROLLED_IMPORT_REQUIRED');
    }
    return _commitImportedEdit(operation, expectedRevision: expectedRevision);
  }

  ProjectDocument _commitImportedEdit(
    EditOperation operation, {
    required BigInt expectedRevision,
  }) {
    stopTimelinePlayback();
    _requireMetadata();
    if (_writer == null) throw const StudioException('PROJECT_NOT_OPEN');
    final id = _uuid.v7();
    _repository.edit(
      writer: _writer!,
      commandId: id,
      receiptKey: id,
      expectedRevision: expectedRevision,
      operation: operation,
    );
    final result = current;
    if (result.revision != expectedRevision) _durableCommit();
    return result;
  }

  Future<ProjectDocument> importVideo(
    LocalFileGrant grant, {
    required BigInt expectedRevision,
    bool acknowledgeVideoOnly = false,
    bool matchEmptySequence = true,
  }) async {
    _requireMedia();
    if (_writer == null) throw const StudioException('PROJECT_NOT_OPEN');
    final projectId = _activeProjectId, writer = _writer;
    return _blobs!.withMaintenanceLease(() async {
      if (_closed ||
          _activeProjectId != projectId ||
          !identical(_writer, writer)) {
        throw const StudioException('PROJECT_CHANGED');
      }
      _selectedInputs.add(grant.file.resolveSymbolicLinksSync());
      final blob = await _blobs!.importFile(grant);
      if (_closed ||
          _activeProjectId != projectId ||
          !identical(_writer, writer)) {
        throw const StudioException('PROJECT_CHANGED');
      }
      return _appendImportedVideo(
        blob,
        name: grant.file.uri.pathSegments.last,
        expectedRevision: expectedRevision,
        acknowledgeVideoOnly: acknowledgeVideoOnly,
        matchEmptySequence: matchEmptySequence,
      );
    });
  }

  Future<ProjectDocument> adoptPeerVideo(
    String rawHash, {
    required String commandId,
    required BigInt expectedRevision,
    bool acknowledgeVideoOnly = false,
    bool matchEmptySequence = true,
  }) async {
    _requireMedia();
    if (_writer == null) throw const StudioException('PROJECT_NOT_OPEN');
    final projectId = _activeProjectId, writer = _writer;
    final inputHash = contentHash({
      'rawHash': rawHash,
      'expectedRevision': expectedRevision.toString(),
      'acknowledgeVideoOnly': acknowledgeVideoOnly,
      'matchEmptySequence': matchEmptySequence,
    });
    return _blobs!.withMaintenanceLease(() async {
      if (_closed ||
          _activeProjectId != projectId ||
          !identical(_writer, writer)) {
        throw const StudioException('PROJECT_CHANGED');
      }
      if (_repository.peerAdoptionAlreadyApplied(
        _writer!,
        commandId,
        inputHash,
      )) {
        return current;
      }
      final bytes = _repository.receivedPeerBlob(rawHash);
      if (bytes == null) throw const StudioException('PEER_BLOB_NOT_RECEIVED');
      final hash = 'sha256:$rawHash';
      await _blobs!.putVerifiedBytes(hash, bytes);
      final file = await _blobs!.resolve(hash);
      if (_activeProjectId != projectId ||
          _closed ||
          !identical(_writer, writer)) {
        throw const StudioException('PROJECT_CHANGED');
      }
      return _appendImportedVideo(
        ImportedBlob(hash, bytes.length, file),
        name: 'Peer-${rawHash.substring(0, 12)}.mp4',
        expectedRevision: expectedRevision,
        acknowledgeVideoOnly: acknowledgeVideoOnly,
        matchEmptySequence: matchEmptySequence,
        adoptionId: commandId,
        adoptionInputHash: inputHash,
      );
    });
  }

  Future<ProjectDocument> _appendImportedVideo(
    ImportedBlob blob, {
    required String name,
    required BigInt expectedRevision,
    required bool acknowledgeVideoOnly,
    required bool matchEmptySequence,
    String? adoptionId,
    String? adoptionInputHash,
  }) async {
    final projectId = _activeProjectId, writer = _writer;
    final probe = await _media!.probeAsync(blob.file);
    if (_activeProjectId != projectId ||
        _closed ||
        !identical(_writer, writer)) {
      throw const StudioException('PROJECT_CHANGED');
    }
    final rawStreams = probe['streams'] as List;
    if (rawStreams.any((v) => v['type'] == 'audio') && !acknowledgeVideoOnly) {
      throw const StudioException('AUDIO_IMPORT_REQUIRES_VIDEO_ONLY_ACK');
    }
    final assetId = _uuid.v7(), rightsId = _uuid.v7();
    final streams = rawStreams
        .map((v) => streamDocument(v as Map<String, dynamic>, assetId: assetId))
        .toList();
    final asset = {
      'id': assetId,
      'version': '1',
      'name': name,
      'kind': 'video',
      'originalBlobHash': blob.hash,
      'externalLocator': null,
      'streams': streams,
      'proxyRefs': [],
      'rightsId': rightsId,
      'contentFingerprint': blob.hash,
      'status': 'ready',
    };
    final rights = {
      'id': rightsId,
      'kind': 'license',
      'assetIds': [assetId],
      'holder': 'unknown',
      'statement': 'No license evidence supplied; allow_with_warning. No rights verification claimed.',
      'evidenceBlobHash': null,
      'providerTermsRef': null,
      'allowedUses': [],
      'territories': [],
      'expiresAt': null,
      'consentId': null,
      'verified': false,
    };
    final operation = AppendVideoAsset(
      asset: asset,
      blob: blob.toJson(),
      rights: rights,
      clipId: _uuid.v7(),
      matchEmptySequence: matchEmptySequence,
    );
    if (adoptionId == null) {
      return _commitImportedEdit(operation, expectedRevision: expectedRevision);
    }
    if (_writer == null) throw const StudioException('PROJECT_NOT_OPEN');
    final changed = _repository.commitPeerAdoption(
      writer: _writer!,
      id: adoptionId,
      inputHash: adoptionInputHash!,
      expectedRevision: expectedRevision,
      operation: operation,
    );
    if (changed) _durableCommit();
    return current;
  }

  final _frameProxies = <String, FrameProxy>{};
  NativeMedia? _proxyBuilder;
  bool _proxyBusy = false;
  int _proxyEpoch = 0;
  int get previewProxyBytes =>
      _frameProxies.values.fold(0, (n, p) => n + p.bytes);
  int get previewProxyCount => _frameProxies.length;
  String _proxyKey(Map<String, dynamic> asset) => contentHash({
    'ns': _repository.namespace.toJson(),
    'blob': asset['originalBlobHash'],
    'version': asset['version'],
    'pipeline': FrameProxy.pipeline,
    'proxyRefs': asset['proxyRefs'],
    'streams': asset['streams'],
  });
  void cancelPreviewProxyBuild() {
    _proxyEpoch++;
    _proxyBuilder?.cancel();
  }

  void clearPreviewProxies() {
    stopTimelinePlayback();
    cancelPreviewProxyBuild();
    for (final proxy in _frameProxies.values) {
      proxy.dispose();
    }
    _frameProxies.clear();
    sourcePreviewCache.clear();
  }

  Map<String, dynamic> _previewProof(Map asset, Map proxy) => {
    'kind': 'studio-preview-proof',
    'version': 1,
    'sourceHash': asset['originalBlobHash'],
    'rgbaHash': proxy['blobHash'],
    'mapHash': proxy['ptsMapBlobHash'],
    'pipelineHash': previewProxyPipelineHash,
  };
  Future<void> _qualifyPreview(
    Map asset,
    Map proxy,
    Map facts,
    File source, {
    required bool ownsLease,
  }) async {
    final record = _previewProof(asset, proxy);
    if (_blobs!.hasPreviewProof(record)) return;
    Future<void> qualify() async {
      if (_blobs!.hasPreviewProof(record)) return;
      final stage = _blobs!.newProxyStage(),
          engine = NativeMedia.open(_media!.libraryPath, _repository.namespace);
      try {
        final actual = await engine.buildPreviewProxyAsync(source, stage);
        if (_closed) throw const StudioException('WORKSPACE_CLOSED');
        if (contentHash(actual) != contentHash(facts) ||
            await hashLocalFile(stage) != proxy['blobHash']) {
          throw const StudioException('PROXY_DERIVATION_MISMATCH');
        }
        await _blobs!.resolve(asset['originalBlobHash']);
        _blobs!.markPreviewProof(record);
      } finally {
        engine.close();
        if (stage.existsSync()) stage.deleteSync();
      }
    }

    if (ownsLease) {
      await _blobs!.withNamespaceDiskReservation(
        64 * 1024 * 1024 + 8192,
        qualify,
      );
    } else {
      await _blobs!.withMaintenanceLease(
        () => _blobs!.withNamespaceDiskReservation(
          64 * 1024 * 1024 + 8192,
          qualify,
        ),
      );
    }
  }

  Future<FrameProxy> _loadStoredProxy(
    Map<String, dynamic> asset,
    Map blobs, {
    bool ownsLease = false,
  }) async {
    final refs = asset['proxyRefs'] as List;
    if (refs.length != 1) {
      throw const StudioException('TIMELINE_PROXY_REQUIRED');
    }
    final ref = refs.single;
    validatePreviewProxyMetadata(asset, ref, blobs);
    final key = contentHash({
          'mapping': _proxyKey(asset),
          'raw': blobs[ref['blobHash']],
          'map': blobs[ref['ptsMapBlobHash']],
          'source': blobs[asset['originalBlobHash']],
        }),
        cached = _frameProxies[key];
    if (cached != null) return cached;
    final original = await _blobs!.resolve(asset['originalBlobHash']);
    final actual = await _media!.probeAsync(original);
    final video = (actual['streams'] as List).singleWhere(
      (v) => v['type'] == 'video',
    );
    final expected = Map<String, dynamic>.from(
      (asset['streams'] as List).singleWhere((v) => v['type'] == 'video'),
    );
    final observed = streamDocument(
      Map<String, dynamic>.from(video),
      assetId: asset['id'],
    );
    expected.remove('id');
    observed.remove('id');
    if (contentHash(expected) != contentHash(observed)) {
      throw const StudioException('PROXY_SOURCE_FACTS_MISMATCH');
    }
    final map = await _blobs!.resolve(
      ref['ptsMapBlobHash'],
      maxBytes: 1024 * 1024,
    );
    if (await map.length() > 1024 * 1024) {
      throw const StudioException('PROXY_MAP_INVALID');
    }
    final file = await _blobs!.resolve(
      ref['blobHash'],
      maxBytes: 64 * 1024 * 1024,
    );
    if (await map.length() !=
            int.parse(blobs[ref['ptsMapBlobHash']]['bytes']) ||
        await file.length() != int.parse(blobs[ref['blobHash']]['bytes']) ||
        await original.length() !=
            int.parse(blobs[asset['originalBlobHash']]['bytes'])) {
      throw const StudioException('BLOB_SIZE_MISMATCH');
    }
    final facts = validateProxyResourceBytes(
      asset,
      ref,
      await map.readAsBytes(),
      await file.readAsBytes(),
    );
    await _qualifyPreview(asset, ref, facts, original, ownsLease: ownsLease);
    final proxy = await FrameProxy.admit(file.parent, facts, dataFile: file);
    if (proxy.blobHash != ref['blobHash']) {
      proxy.dispose();
      throw const StudioException('PROXY_BLOB_HASH_MISMATCH');
    }
    if (_closed) {
      proxy.dispose();
      throw const StudioException('WORKSPACE_CLOSED');
    }
    if (previewProxyBytes + proxy.bytes > 64 * 1024 * 1024) {
      proxy.dispose();
      throw const StudioException('PROXY_CACHE_QUOTA');
    }
    _frameProxies[key] = proxy;
    return proxy;
  }

  /// Explicit logical discard only. Historical pins and every file stay intact.
  /// Corrupt immutable CAS collisions remain fail-closed on a later rebuild.
  ProjectDocument discardTimelinePreviewProxies({
    required String assetId,
    required BigInt expectedRevision,
    required bool confirmed,
  }) {
    if (!confirmed) {
      throw const StudioException('PROXY_DISCARD_CONFIRMATION_REQUIRED');
    }
    if (_proxyBusy) throw const StudioException('PROXY_BUILD_BUSY');
    final result = _commitImportedEdit(
      DiscardPreviewProxies(assetId),
      expectedRevision: expectedRevision,
    );
    clearPreviewProxies();
    return result;
  }

  Map<String, dynamic> namespaceStorageInventory() {
    _requireMedia();
    return _blobs!.namespaceInventory();
  }

  Future<Map<String, dynamic>> configureNamespaceDiskBudget(
    String? bytes, {
    required bool confirmed,
  }) {
    _requireMedia();
    return _blobs!.configureNamespaceBudget(
      bytes,
      databasePath: _databasePath,
      confirmed: confirmed,
    );
  }

  List<Map<String, dynamic>> checkpointRetentionAuditHistory() {
    _requireMedia();
    return _repository.checkpointPruneAuditHistory(_activeProjectId);
  }

  WriterToken _retentionWriter() {
    _requireMedia();
    final writer = _writer;
    if (writer == null) throw const StudioException('PROJECT_NOT_OPEN');
    return writer;
  }

  Future<Map<String, dynamic>> reviewCheckpointRetention() async {
    final writer = _retentionWriter(), revision = current.revision;
    return _blobs!.withMaintenanceLease(() async {
      _blobs!.requireExclusiveRepairDatabase(_databasePath);
      return _repository.reviewCheckpointPruning(writer, revision);
    });
  }

  Future<void> configureCheckpointRetention(
    int? keepLatest, {
    required bool confirmed,
  }) async {
    final writer = _retentionWriter(), revision = current.revision;
    await _blobs!.withMaintenanceLease(() async {
      _repository.configureCheckpointRetention(
        writer,
        revision,
        keepLatest,
        confirmed: confirmed,
        validateStorageAuthority: () =>
            _blobs!.requireExclusiveRepairDatabase(_databasePath),
      );
    });
  }

  Future<String> nameCurrentCheckpoint(
    String name, {
    required BigInt expectedRevision,
  }) async {
    final writer = _retentionWriter();
    return _blobs!.withMaintenanceLease(
      () async =>
          _repository.nameCurrentCheckpoint(writer, expectedRevision, name),
    );
  }

  Future<Map<String, dynamic>> applyCheckpointRetention({
    required String reviewHash,
    required BigInt expectedRevision,
    required bool confirmed,
  }) async {
    final writer = _retentionWriter();
    return _blobs!.withMaintenanceLease(
      () async => _repository.applyCheckpointPruning(
        writer,
        expectedRevision,
        reviewHash: reviewHash,
        confirmed: confirmed,
        validateStorageAuthority: () =>
            _blobs!.requireExclusiveRepairDatabase(_databasePath),
      ),
    );
  }

  int _previewDiskPeak(ProjectDocument snapshot) =>
      192 * 1024 * 1024 +
      (snapshot.toJson()['assets'] as List).length * (1024 * 1024 + 8192);

  /// Regenerate from verified originals, then repair only exact existing hashes.
  /// No recipe conversion, metadata revision, original write or cross-project heal.
  Future<Map<String, dynamic>> repairTimelinePreviewProxies({
    required String assetId,
    required BigInt expectedRevision,
    required bool confirmed,
  }) async {
    _requireMedia();
    if (!confirmed) {
      throw const StudioException('PROXY_REPAIR_CONFIRMATION_REQUIRED');
    }
    if (_proxyBusy) throw const StudioException('PROXY_BUILD_BUSY');
    final snapshot = current, writer = _writer;
    if (writer == null) throw const StudioException('PROJECT_NOT_OPEN');
    if (snapshot.revision != expectedRevision) {
      throw const StudioException('REVISION_CONFLICT');
    }
    requireLocalEditingWritable(snapshot);
    final matches = (snapshot.toJson()['assets'] as List).where(
      (a) => a['id'] == assetId,
    );
    if (matches.length != 1 ||
        (matches.single['proxyRefs'] as List).length != 1) {
      throw const StudioException('TIMELINE_PROXY_REQUIRED');
    }
    final asset = Map<String, dynamic>.from(matches.single),
        ref = asset['proxyRefs'][0];
    final blobs = {for (final b in snapshot.toJson()['blobs']) b['hash']: b};
    validatePreviewProxyMetadata(asset, ref, blobs);
    clearPreviewProxies();
    final epoch = ++_proxyEpoch;
    final builder = NativeMedia.open(_media!.libraryPath, snapshot.namespace);
    _proxyBusy = true;
    _proxyBuilder = builder;
    void check() {
      if (_closed ||
          epoch != _proxyEpoch ||
          current.hash != snapshot.hash ||
          !identical(_writer, writer)) {
        throw const StudioException('CANCELED');
      }
    }

    try {
      return await _blobs!.withMaintenanceLease(
        () => _blobs!.withNamespaceDiskReservation(
          _previewDiskPeak(snapshot),
          () async {
            check();
            _blobs!.requireExclusiveRepairDatabase(_databasePath);
            final source = await _blobs!.resolve(asset['originalBlobHash']);
            final actual = await _media!.probeAsync(source);
            final expected = Map<String, dynamic>.from(
              (asset['streams'] as List).singleWhere(
                (v) => v['type'] == 'video',
              ),
            )..remove('id');
            final observed = streamDocument(
              Map<String, dynamic>.from(
                (actual['streams'] as List).singleWhere(
                  (v) => v['type'] == 'video',
                ),
              ),
              assetId: assetId,
            )..remove('id');
            if (contentHash(expected) != contentHash(observed)) {
              throw const StudioException('PROXY_SOURCE_FACTS_MISMATCH');
            }
            check();
            final raw = _blobs!.newProxyStage(),
                map = File('${_blobs!.directory.path}/.restore-${_uuid.v7()}');
            FrameProxy? proxy;
            try {
              final facts = await builder.buildPreviewProxyAsync(source, raw);
              check();
              proxy = await FrameProxy.admit(raw.parent, facts, dataFile: raw);
              final bytes = utf8.encode(
                jsonEncode({
                  'protocol': 'studio.preview-pts',
                  'version': 1,
                  'sourceHash': asset['originalBlobHash'],
                  'pipelineHash': previewProxyPipelineHash,
                  'rgbaHash': proxy.blobHash,
                  'facts': facts,
                  'frameHashes': proxy.frameHashes,
                }),
              );
              if (proxy.blobHash != ref['blobHash'] ||
                  rawBytesHash(bytes) != ref['ptsMapBlobHash']) {
                throw const StudioException('PROXY_REPAIR_DERIVATION_MISMATCH');
              }
              if (raw.lengthSync() !=
                      int.parse(blobs[ref['blobHash']]['bytes']) ||
                  bytes.length !=
                      int.parse(blobs[ref['ptsMapBlobHash']]['bytes'])) {
                throw const StudioException('BLOB_SIZE_MISMATCH');
              }
              validateProxyResourceBytes(
                asset,
                ref,
                bytes,
                await raw.readAsBytes(),
              );
              map.createSync(exclusive: true);
              map.writeAsBytesSync(bytes, flush: true);
              await _blobs!.resolve(asset['originalBlobHash']);
              check();
              final result = _repository.withExclusivePreviewRepair(
                writer: writer,
                expectedRevision: expectedRevision,
                expectedSnapshot: snapshot.hash,
                sourceHash: asset['originalBlobHash'],
                roles: {
                  ref['blobHash']: 'proxy',
                  ref['ptsMapBlobHash']: 'ptsMap',
                },
                publish: () => _blobs!.repairPreviewStagesSync(
                  {ref['blobHash']: raw, ref['ptsMapBlobHash']: map},
                  {
                    'projectId': snapshot.projectId,
                    'revision': expectedRevision.toString(),
                    'snapshotHash': snapshot.hash,
                    'sourceHash': asset['originalBlobHash'],
                    'pipelineHash': previewProxyPipelineHash,
                    'writerFence': writer.epoch,
                  },
                  databasePath: _databasePath,
                ),
              );
              _blobs!.markPreviewProof(_previewProof(asset, ref));
              return result;
            } finally {
              proxy?.dispose();
              if (raw.existsSync()) raw.deleteSync();
              if (map.existsSync()) map.deleteSync();
            }
          },
        ),
      );
    } catch (_) {
      if (_closed || epoch != _proxyEpoch) {
        throw const StudioException('CANCELED');
      }
      rethrow;
    } finally {
      builder.close();
      if (identical(_proxyBuilder, builder)) _proxyBuilder = null;
      _proxyBusy = false;
    }
  }

  /// Publish immutable CAS bytes under namespace maintenance ownership, then
  /// atomically attach valid SchemaProxy + map resources with revision/writer CAS.
  Future<Map<String, dynamic>> buildTimelinePreviewProxies() async {
    _requireMedia();
    if (_proxyBusy) throw const StudioException('PROXY_BUILD_BUSY');
    final snapshot = current;
    _requireTransformAdapter(snapshot);
    if ((snapshot.toJson()['effects'] as List).any(
          (e) => (e['keyframes'] as List).isNotEmpty,
        ) &&
        _media!.capabilities['linearOpacityKeyframesV1'] != true) {
      throw const StudioException('OPACITY_KEYFRAMES_ADAPTER_UNAVAILABLE');
    }
    requireLocalEditingWritable(snapshot);
    stopTimelinePlayback();
    for (final reader in _frameProxies.values) {
      reader.dispose();
    }
    _frameProxies.clear();
    final builder = NativeMedia.open(_media!.libraryPath, snapshot.namespace);
    _proxyBusy = true;
    final epoch = ++_proxyEpoch;
    _proxyBuilder = builder;
    void check() {
      if (_closed || epoch != _proxyEpoch || current.hash != snapshot.hash) {
        throw const StudioException('CANCELED');
      }
    }

    try {
      return await _blobs!.withMaintenanceLease(
        () => _blobs!.withNamespaceDiskReservation(
          _previewDiskPeak(snapshot),
          () async {
            final orphans = _blobs!.collectProxyOrphans();
            final resources = <Map<String, dynamic>>[];
            var pendingBytes = 0;
            for (final raw in snapshot.toJson()['assets']) {
              check();
              final asset = Map<String, dynamic>.from(raw as Map);
              if ((asset['proxyRefs'] as List).isNotEmpty) {
                await _loadStoredProxy(asset, {
                  for (final b in snapshot.toJson()['blobs']) b['hash']: b,
                }, ownsLease: true);
                check();
                continue;
              }
              final source = await _blobs!.resolve(asset['originalBlobHash']);
              check();
              final stage = _blobs!.newProxyStage();
              FrameProxy? staged;
              try {
                final facts = await builder.buildPreviewProxyAsync(
                  source,
                  stage,
                );
                check();
                staged = await FrameProxy.admit(
                  stage.parent,
                  facts,
                  dataFile: stage,
                );
                check();
                pendingBytes += staged.bytes;
                if (previewProxyBytes + pendingBytes > 64 * 1024 * 1024) {
                  throw const StudioException('PROXY_CACHE_QUOTA');
                }
                final original = await _blobs!.importDerivedStage(
                  stage,
                  staged.blobHash,
                );
                check();
                final manifest = {
                  'protocol': 'studio.preview-pts',
                  'version': 1,
                  'sourceHash': asset['originalBlobHash'],
                  'pipelineHash': previewProxyPipelineHash,
                  'rgbaHash': original.hash,
                  'facts': facts,
                  'frameHashes': staged.frameHashes,
                };
                final mapBytes = utf8.encode(jsonEncode(manifest)),
                    mapHash = rawBytesHash(utf8.encode(jsonEncode(manifest)));
                await _blobs!.putVerifiedBytes(mapHash, mapBytes);
                check();
                final stream = (asset['streams'] as List).singleWhere(
                  (v) => v['type'] == 'video',
                );
                final proxy = {
                  'blobHash': original.hash,
                  'pipelineHash': previewProxyPipelineHash,
                  'sourceVersion': asset['version'],
                  'ptsMapBlobHash': mapHash,
                  'width': staged.width,
                  'height': staged.height,
                  'frameRate': stream['nominalFrameRate'],
                  'colorPolicy': previewProxyColorPolicy,
                };
                await _blobs!.resolve(asset['originalBlobHash']);
                check();
                _blobs!.markPreviewProof(_previewProof(asset, proxy));
                validateProxyResourceBytes(
                  asset,
                  proxy,
                  mapBytes,
                  await original.file.readAsBytes(),
                );
                check();
                Map<String, dynamic> record(
                  String hash,
                  int bytes,
                  String role,
                  String extension,
                ) => {
                  'hash': hash,
                  'bytes': bytes.toString(),
                  'mime': 'application/octet-stream',
                  'packagePath': 'proxies/${hash.substring(7)}.$extension',
                  'role': role,
                };
                resources.add({
                  'assetId': asset['id'],
                  'sourceHash': asset['originalBlobHash'],
                  'proxy': proxy,
                  'blobs': [
                    record(original.hash, original.bytes, 'proxy', 'rgba'),
                    record(mapHash, mapBytes.length, 'ptsMap', 'pts.json'),
                  ],
                });
              } finally {
                staged?.dispose();
                if (stage.existsSync()) stage.deleteSync();
              }
            }
            check();
            if (resources.isNotEmpty) {
              _commitImportedEdit(
                AttachPreviewProxies(resources),
                expectedRevision: snapshot.revision,
              );
            }
            for (final reader in _frameProxies.values) {
              reader.dispose();
            }
            _frameProxies.clear();
            for (final a in current.toJson()['assets']) {
              await _loadStoredProxy(Map<String, dynamic>.from(a), {
                for (final b in current.toJson()['blobs']) b['hash']: b,
              }, ownsLease: true);
            }
            return {
              'pipeline': FrameProxy.pipeline,
              'proxies': previewProxyCount,
              'bytes': previewProxyBytes,
              'persistent': true,
              'built': resources.length,
              'reused':
                  (snapshot.toJson()['assets'] as List).length -
                  resources.length,
              'orphanFiles': orphans['files'],
            };
          },
        ),
      );
    } catch (_) {
      if (_closed || epoch != _proxyEpoch) {
        throw const StudioException('CANCELED');
      }
      rethrow;
    } finally {
      builder.close();
      if (identical(_proxyBuilder, builder)) _proxyBuilder = null;
      _proxyBusy = false;
    }
  }

  /// The sole timeline progress source is the current AudioSink confirmed sample.
  /// A timer may REQUEST rendering; it never manufactures media time.
  bool _timelineFrameBusy = false;
  Future<TimelinePreviewFrame?> renderTimelineFromAudioClock() async {
    if (_closed) throw const StudioException('WORKSPACE_CLOSED');
    if (_timelineFrameBusy) throw const StudioException('TIMELINE_RENDER_BUSY');
    _timelineFrameBusy = true;
    final generation = _playbackGeneration;
    try {
      return await _renderTimelineFromAudioClock();
    } catch (_) {
      if (_closed || generation != _playbackGeneration) {
        throw const StudioException('TIMELINE_FRAME_STALE');
      }
      rethrow;
    } finally {
      _timelineFrameBusy = false;
    }
  }

  Future<TimelinePreviewFrame?> _renderTimelineFromAudioClock() async {
    _requireMedia();
    final hash = _playbackHash,
        clock = timelinePlayback,
        generation = _playbackGeneration;
    if (clock['clockValid'] != true ||
        !{'playing', 'paused', 'finished'}.contains(clock['state'])) {
      return null;
    }
    if (hash == null ||
        clock['snapshotHash'] != hash ||
        !_repository.headMatches(_activeProjectId, hash)) {
      throw const StudioException('PLAYBACK_REVISION_CHANGED');
    }
    _requireTransformAdapter(_playbackSnapshot!);
    final graph = _playbackGraph ??= TimelineVideoGraph(_playbackSnapshot!),
        sample = clock['presentedSample'] as int,
        epoch = clock['epoch'] as int;
    var time = Q.of(sample, 48000);
    if (time >= graph.duration && time - graph.duration <= Q.of(1, 48000)) {
      time = time - Q.of(1, 48000);
    }
    final point = graph.sampleFrame(time);
    SourcePreviewFrame pixels;
    var index = -1;
    if (point.isGap) {
      final rgba = List<int>.filled(
        graph.previewWidth * graph.previewHeight * 4,
        0,
      );
      for (var i = 3; i < rgba.length; i += 4) {
        rgba[i] = 255;
      }
      pixels = SourcePreviewFrame({
        'width': graph.previewWidth,
        'height': graph.previewHeight,
        'rgba': rgba,
        'pts': '0',
        'startPts': '0',
        'timeBase': Q.of(1).toJson(),
        'packetsRead': 0,
      });
    } else if (point.opacityQ16 != 65536 ||
        point.transform2d != null ||
        point.secondary != null) {
      pixels = await previewAssetSource(
        point.assetId!,
        point.sourceTime,
        opacityQ16: point.opacityQ16,
        transform2d: point.transform2d,
        secondary: point.secondary,
        mixQ16: point.mixQ16,
      );
    } else {
      final asset = _playbackAssets[point.assetId]!;
      final proxy = await _loadStoredProxy(asset, _playbackBlobs);
      index = proxy.indexAt(point.sourceTime);
      final key = contentHash({
        'proxy': proxy.blobHash,
        'mapping': _proxyKey(asset),
        'frame': index,
      });
      final cached = sourcePreviewCache.get(key);
      pixels = cached ?? await proxy.read(index);
      if (cached == null) sourcePreviewCache.put(key, pixels);
    }
    final result = TimelinePreviewFrame(
      pixels: pixels,
      snapshotHash: hash,
      playbackGeneration: generation,
      clockEpoch: epoch,
      clockSample: sample,
      clipId: point.clipId,
      assetId: point.assetId,
      proxyIndex: index,
      gap: point.isGap,
    );
    if (!isTimelineFrameCurrent(result)) {
      throw const StudioException('TIMELINE_FRAME_STALE');
    }
    return result;
  }

  bool isTimelineFrameCurrent(TimelinePreviewFrame frame) {
    if (_closed ||
        frame.playbackGeneration != _playbackGeneration ||
        !_repository.headMatches(_activeProjectId, frame.snapshotHash)) {
      return false;
    }
    final clock = timelinePlayback;
    if (clock['snapshotHash'] != frame.snapshotHash ||
        clock['epoch'] != frame.clockEpoch ||
        clock['clockValid'] != true ||
        !{'playing', 'paused', 'finished'}.contains(clock['state'])) {
      return false;
    }
    final delta = (clock['presentedSample'] as int) - frame.clockSample;
    return delta >= 0 &&
        delta <= 960; //20ms processing freshness, NOT physical AV proof.
  }

  final sourcePreviewCache = SourcePreviewCache();
  NativeMedia? _previewMedia;
  int _previewEpoch = 0;
  Future<void> _previewTail = Future.value();
  void cancelSourcePreview() {
    ++_previewEpoch;
    _previewMedia?.cancel();
  }

  Future<SourcePreviewFrame> previewAssetSource(
    String assetId,
    Q time, {
    int? opacityQ16,
    Map<String, double>? transform2d,
    TimelineVideoPoint? secondary,
    int mixQ16 = 0,
  }) async {
    _requireMedia();
    if (time < Q.of(0)) throw const StudioException('PREVIEW_TIME_INVALID');
    if (transform2d != null) {
      // Capture caller-owned mutable data before any await/cache-key creation.
      transform2d = Map.unmodifiable(transform2d);
      validateTransform2d(Map<String, dynamic>.from(transform2d));
    }
    final project = current, epoch = ++_previewEpoch;
    _previewMedia?.cancel();
    final asset = (project.toJson()['assets'] as List).singleWhere(
      (a) => a['id'] == assetId,
      orElse: () => throw const StudioException('ASSET_NOT_FOUND'),
    );
    final hash = asset['originalBlobHash'] as String;
    Map<String, dynamic>? otherAsset;
    Map<String, double>? otherTransform;
    if (secondary != null) {
      if (mixQ16 < 0 ||
          mixQ16 > 65536 ||
          secondary.isGap ||
          secondary.sourceTime < Q.of(0)) {
        throw const StudioException('DISSOLVE_POINT_INVALID');
      }
      otherAsset = Map<String, dynamic>.from(
        (project.toJson()['assets'] as List).singleWhere(
          (a) => a['id'] == secondary.assetId,
          orElse: () => throw const StudioException('ASSET_NOT_FOUND'),
        ) as Map,
      );
      if (otherAsset['version'] != secondary.sourceVersion) {
        throw const StudioException('SOURCE_VERSION_MISSING');
      }
      if (secondary.transform2d != null) {
        otherTransform = Map.unmodifiable(secondary.transform2d!);
        validateTransform2d(Map<String, dynamic>.from(otherTransform));
      }
    }

    final key = contentHash({
      'ns': project.namespace.toJson(),
      'blob': hash,
      'time': time.toJson(),
      'preview': 'source-rgba128-1',
      'opacity-linear709-v1-q16': ?opacityQ16,
      'static-transform2d-linear709-v1': ?transform2d,
      if (secondary != null)
        'dissolve-v1': {
          'blob': otherAsset!['originalBlobHash'],
          'time': secondary.sourceTime.toJson(),
          'opacityQ16': secondary.opacityQ16,
          'transform2d': otherTransform,
          'mixQ16': mixQ16,
        },
    });
    final cached = sourcePreviewCache.get(key);
    if (cached != null) return cached;
    final prior = _previewTail, done = Completer<void>();
    _previewTail = done.future;
    await prior;
    try {
      if (epoch != _previewEpoch || _closed) {
        throw const StudioException('PREVIEW_SUPERSEDED');
      }
      _previewMedia ??= NativeMedia.open(
        _media!.libraryPath,
        _repository.namespace,
      );
      final file = await _blobs!.resolve(hash);
      if (epoch != _previewEpoch || _closed) {
        throw const StudioException('PREVIEW_SUPERSEDED');
      }
      if (current.hash != project.hash) {
        throw const StudioException('PREVIEW_PROJECT_CHANGED');
      }
      Map<String, dynamic>? rightRecipe;
      if (secondary != null) {
        final otherFile = await _blobs!.resolve(
          otherAsset!['originalBlobHash'] as String,
        );
        if (epoch != _previewEpoch || _closed || current.hash != project.hash) {
          throw const StudioException('PREVIEW_SUPERSEDED');
        }
        rightRecipe = {
          'path': otherFile.absolute.path,
          'time': secondary.sourceTime.toJson(),
          'indexed': true,
          'opacityQ16': secondary.opacityQ16,
          'transform2d': ?otherTransform,
        };
      }
      final frame = SourcePreviewFrame(
        await _previewMedia!.previewAsync(
          file,
          time,
          opacityQ16: opacityQ16,
          transform2d: transform2d,
          secondary: rightRecipe,
          mixQ16: mixQ16,
        ),
      );
      if (epoch != _previewEpoch || _closed) {
        throw const StudioException('PREVIEW_SUPERSEDED');
      }
      if (current.hash != project.hash) {
        throw const StudioException('PREVIEW_PROJECT_CHANGED');
      }
      sourcePreviewCache.put(key, frame);
      return frame;
    } catch (_) {
      if (epoch != _previewEpoch || _closed) {
        throw const StudioException('PREVIEW_SUPERSEDED');
      }
      rethrow;
    } finally {
      done.complete();
    }
  }

  /// Explicit still timeline preview uses the SAME full-size native CPU node and
  /// YUV420 buffer conversion as final export, then downsamples for display.
  Future<SourcePreviewFrame> previewTimelineAt(Q time) async {
    _requireMedia();
    _requireTransformAdapter(current);
    final snapshot = current,
        graph = TimelineVideoGraph(current),
        point = graph.sampleFrame(time);
    if (point.isGap) {
      final rgba = List<int>.filled(
        graph.previewWidth * graph.previewHeight * 4,
        0,
      );
      for (var i = 3; i < rgba.length; i += 4) {
        rgba[i] = 255;
      }
      return SourcePreviewFrame({
        'width': graph.previewWidth,
        'height': graph.previewHeight,
        'rgba': rgba,
        'pts': '0',
        'startPts': '0',
        'timeBase': Q.of(1).toJson(),
        'packetsRead': 0,
      });
    }
    final result = await previewAssetSource(
      point.assetId!,
      point.sourceTime,
      opacityQ16: point.opacityQ16 == 65536 ? null : point.opacityQ16,
      transform2d: point.transform2d,
      secondary: point.secondary,
      mixQ16: point.mixQ16,
    );
    if (current.hash != snapshot.hash) {
      throw const StudioException('PREVIEW_PROJECT_CHANGED');
    }
    return result;
  }

  ProjectDocument setDissolve(
    String leftClipId,
    String rightClipId,
    Q before,
    Q after, {
    required BigInt expectedRevision,
  }) {
    _requireMedia();
    if (_media!.capabilities['linearDissolveV1'] != true) {
      throw const StudioException('DISSOLVE_ADAPTER_UNAVAILABLE');
    }
    return edit(
      SetDissolve(leftClipId, rightClipId, before, after),
      expectedRevision: expectedRevision,
    );
  }

  ProjectDocument removeDissolve(
    String transitionId, {
    required BigInt expectedRevision,
  }) => edit(RemoveDissolve(transitionId), expectedRevision: expectedRevision);

  ProjectDocument setClipTransform(
    String clipId,
    Map<String, double> parameters, {
    required BigInt expectedRevision,
  }) {
    _requireMedia();
    if (_media?.capabilities['staticTransform2dV1'] != true) {
      throw const StudioException('TRANSFORM_ADAPTER_UNAVAILABLE');
    }
    return edit(
      SetClipTransform(clipId, parameters),
      expectedRevision: expectedRevision,
    );
  }

  void _requireTransformAdapter(ProjectDocument document) {
    if ((document.toJson()['transitions'] as List).isNotEmpty &&
        _media?.capabilities['linearDissolveV1'] != true) {
      throw const StudioException('DISSOLVE_ADAPTER_UNAVAILABLE');
    }

    if ((document.toJson()['effects'] as List).any(
          (e) => e['type'] == 'transform2d',
        ) &&
        _media?.capabilities['staticTransform2dV1'] != true) {
      throw const StudioException('TRANSFORM_ADAPTER_UNAVAILABLE');
    }
  }

  ProjectDocument setOpacityKeyframe(
    String clipId,
    Q localTime,
    double value, {
    String interpolation = 'linear',
    required BigInt expectedRevision,
  }) {
    _requireMedia();
    if (_media!.capabilities['linearOpacityKeyframesV1'] != true) {
      throw const StudioException('OPACITY_KEYFRAMES_ADAPTER_UNAVAILABLE');
    }
    return edit(
      SetOpacityKeyframe(
        clipId,
        localTime,
        value,
        interpolation: interpolation,
      ),
      expectedRevision: expectedRevision,
    );
  }

  ProjectDocument removeOpacityKeyframe(
    String clipId,
    Q localTime, {
    required BigInt expectedRevision,
  }) => edit(
    RemoveOpacityKeyframe(clipId, localTime),
    expectedRevision: expectedRevision,
  );

  ProjectDocument setClipOpacity(
    String clipId,
    double value, {
    required BigInt expectedRevision,
  }) {
    _requireMedia();
    if (_media!.capabilities['linearOpacityV1'] != true) {
      throw const StudioException('OPACITY_ADAPTER_UNAVAILABLE');
    }
    return edit(
      SetClipOpacity(clipId, value),
      expectedRevision: expectedRevision,
    );
  }

  Future<Map<String, int>> collectLocalGarbage() async {
    _requireMedia();
    return _blobs!.withMaintenanceLease(() async {
      final cas = _repository.withRetainedBlobPins(
        (pins) => _blobs!.collectUnreferenced(pins),
      );
      final proxyOrphans = _blobs!.collectProxyOrphans();
      final inbox = _repository.collectPeerInbox(
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
      return {
        'casFiles': cas['files']!,
        'casBytes': cas['bytes']!,
        'proxyOrphans': proxyOrphans['files']!,
        ...inbox,
      };
    });
  }

  void _protectOutput(File destination) {
    AtomicFilePublisher().stagingFor(
      destination,
    ); // validate local parent/target
    final path = destination.absolute.uri.normalizePath().toFilePath();
    final cas = _blobs?.directory.absolute.path;
    if (path == _databasePath ||
        path.startsWith('$_databasePath-') ||
        (cas != null &&
            (path == cas ||
                path.startsWith('$cas${Platform.pathSeparator}'))) ||
        _selectedInputs.contains(path)) {
      throw const StudioException('PROTECTED_SOURCE_OUTPUT');
    }
  }

  Future<CaptionImport> importCaptions(
    LocalFileGrant source,
    CaptionFormat format, {
    required BigInt expectedRevision,
  }) async {
    _requireMetadata();
    final selectedProject = _activeProjectId;
    _selectedInputs.add(source.file.resolveSymbolicLinksSync());
    if (await source.file.length() > 16 * 1024 * 1024) {
      throw const StudioException('SUBTITLE_RESOURCE_LIMIT');
    }
    final imported = CaptionFormats.decode(
      await source.file.readAsString(),
      format,
    );
    if (_closed || selectedProject != _activeProjectId) {
      throw const StudioException('PROJECT_CHANGED');
    }
    final old = (current.toJson()['captions'] as List).map(
      (c) => CaptionCue.fromProjectJson(c as Map<String, dynamic>),
    );
    final values = [
      ...old,
      for (final c in imported.captions.cues)
        CaptionCue(
          _uuid.v7(),
          c.range,
          c.text,
          language: c.language,
          manualFields: {'text', 'timing'},
        ),
    ];
    edit(SetCaptions(CaptionStore(values)), expectedRevision: expectedRevision);
    return imported;
  }

  BigInt exportCaptions(File target, CaptionFormat format) {
    _requireMetadata();
    _protectOutput(target);
    final snapshot = current;
    _requireTransformAdapter(snapshot);
    if ((snapshot.toJson()['effects'] as List).any(
          (e) => (e['keyframes'] as List).isNotEmpty,
        ) &&
        _media!.capabilities['linearOpacityKeyframesV1'] != true) {
      throw const StudioException('OPACITY_KEYFRAMES_ADAPTER_UNAVAILABLE');
    }
    requireLocalEditingWritable(snapshot);
    final cues = (snapshot.toJson()['captions'] as List)
        .map((c) => CaptionCue.fromProjectJson(c as Map<String, dynamic>))
        .toList();
    AtomicFilePublisher().write(
      target,
      utf8.encode(CaptionFormats.encode(CaptionStore(cues), format)),
    );
    return snapshot.revision;
  }

  PersistenceView persistence({File? target}) => _repository.persistenceView(
    _activeProjectId,
    targetPath: target?.absolute.uri.normalizePath().toFilePath(),
  );
  void flushCheckpoint() => _autosave?.flush();
  BigInt saveManaged() {
    _requireMetadata();
    if (_writer == null) throw const StudioException('PROJECT_NOT_OPEN');
    flushCheckpoint();
    final revision = _repository.saveManaged(_writer!);
    _notifyPersistence();
    return revision;
  }

  SaveHandle requestArchiveSave(File destination) {
    _requireMedia();
    _protectOutput(destination);
    if (_writer == null) throw const StudioException('PROJECT_NOT_OPEN');
    _saves ??= SaveCoordinator(_repository, _blobs!);
    return _saves!.request(_writer!, current, destination);
  }

  Future<BigInt> saveArchive(File destination) async =>
      (await requestArchiveSave(destination).result).snapshot.revision;
  List<Map<String, dynamic>> get pendingSaves =>
      _repository.pendingSaveOperations(_activeProjectId);
  Future<SaveReceipt> reconcileSave(String id, LocalFileGrant target) {
    _requireMedia();
    _protectOutput(target.file);
    _saves ??= SaveCoordinator(_repository, _blobs!);
    return _saves!.reconcile(_writer!, id, target);
  }

  Future<void> closeAsync() async {
    flushCheckpoint();
    await _saves?.drain();
    close();
  }

  NativeMedia? _resourceImportEngine;
  int _resourceImportEpoch = 0;
  void cancelResourceImport() {
    _resourceImportEpoch++;
    _resourceImportEngine?.cancel();
  }

  Map<String, dynamic>? get currentImportMap =>
      _repository.importMap(current.projectId);

  /// Explicitly creates a NEW writable fork only for the already implemented
  /// timeline renderer profile. Never drops unsupported/opaque records.
  Future<ProjectDocument> adoptPreservedResources(
    ResourcePreservationSession session, {
    required String expectedCollectionReviewHash,
    required String expectedActiveHash,
    required bool confirmed,
  }) async {
    _requireMedia();
    if (!confirmed) {
      throw const StudioException('RESOURCE_COLLECTION_CONFIRMATION_REQUIRED');
    }
    final writer = _writer;
    if (writer == null) throw const StudioException('PROJECT_NOT_OPEN');
    if (_resourceImportEngine != null) {
      throw const StudioException('RESOURCE_IMPORT_BUSY');
    }
    if (current.hash != expectedActiveHash) {
      throw const StudioException('REVISION_CONFLICT');
    }
    final resources = session.writableCollection(expectedCollectionReviewHash);
    final source = session.project;
    _requireTransformAdapter(source);
    final graph = TimelineVideoGraph(source);
    if ((source.toJson()['effects'] as List).any(
          (e) => (e['keyframes'] as List).isNotEmpty,
        ) &&
        _media!.capabilities['linearOpacityKeyframesV1'] != true) {
      throw const StudioException('OPACITY_KEYFRAMES_ADAPTER_UNAVAILABLE');
    }
    if ((source.toJson()['effects'] as List).isNotEmpty &&
        _media!.capabilities['linearOpacityV1'] != true) {
      throw const StudioException('OPACITY_ADAPTER_UNAVAILABLE');
    }
    if (graph.duration > Q.of(120)) {
      throw const StudioException('RESOURCE_IMPORT_DURATION_LIMIT');
    }
    final epoch = _resourceImportEpoch;
    final engine = NativeMedia.open(_media!.libraryPath, _repository.namespace);
    _resourceImportEngine = engine;
    void check() {
      if (_closed || epoch != _resourceImportEpoch) {
        throw const StudioException('CANCELED');
      }
      if (!identical(_writer, writer) || current.hash != expectedActiveHash) {
        throw const StudioException('REVISION_CONFLICT');
      }
    }

    try {
      return await _blobs!.withMaintenanceLease(() async {
        check();
        for (final entry in resources.entries) {
          await _blobs!.putVerifiedBytes(entry.key, entry.value);
          check();
        }
        for (final asset in source.toJson()['assets']) {
          final file = await _blobs!.resolve(asset['originalBlobHash']);
          final facts = await engine.probeAsync(file);
          check();
          final raw = facts['streams'] as List,
              declared = asset['streams'] as List;
          if (raw.length != declared.length) {
            throw const StudioException('SOURCE_STREAM_CHANGED');
          }
          for (var i = 0; i < raw.length; i++) {
            final observed = streamDocument(
              Map<String, dynamic>.from(raw[i]),
              assetId: asset['id'],
            )..remove('id');
            final expected = Map<String, dynamic>.from(declared[i])
              ..remove('id');
            if (contentHash(observed) != contentHash(expected)) {
              throw const StudioException('SOURCE_STREAM_CHANGED');
            }
            if (raw[i]['type'] == 'video') {
              if (observed['variableFrameRate'] != false) {
                throw const StudioException('VFR_RENDER_NOT_VALIDATED');
              }
              await engine.previewAsync(file, Q.of(0));
            } else {
              final stage = _blobs!.newProxyStage();
              try {
                await _blobs!.withNamespaceDiskReservation(8192, () async {
                  final st = raw[i];
                  final origin =
                      Q(BigInt.parse(st['startPTS']), BigInt.one) *
                      Q.of(st['timeBase']['n'], st['timeBase']['d']);
                  await engine.decodeAudioAsync({
                    'path': file.absolute.path,
                    'outputPath': stage.path,
                    'streamIndex': st['index'],
                    'startSample': sampleIndex(
                      origin,
                      48000,
                      Rounding.tiesToEven,
                    ).toInt(),
                    'sampleCount': 1024,
                  });
                });
              } finally {
                if (stage.existsSync()) stage.deleteSync();
              }
            }
            check();
          }
          for (final proxy in asset['proxyRefs']) {
            final facts = validateProxyResourceBytes(
              asset,
              proxy,
              resources[proxy['ptsMapBlobHash']]!,
              resources[proxy['blobHash']]!,
            );
            await _qualifyPreview(asset, proxy, facts, file, ownsLease: true);
            check();
          }
        }
        // Admission tests the actual enabled node against qualified originals;
        // a matching schema/capability flag alone is not render qualification.
        final definition = source.toJson();
        final qualifiedNodes = <String>{};
        for (final track in definition['sequences'][0]['tracks']) {
          if (track['kind'] != 'video') continue;
          for (final clip in track['items']) {
            if (clip['source'] == null || clip['enabled'] == false) continue;
            final opacity = clipOpacityQ16(
              definition,
              Map<String, dynamic>.from(clip as Map),
            );
            final transform = clipTransform2d(definition, clip);
            if (opacity == 65536 && transform == null) continue;
            final asset = (definition['assets'] as List).singleWhere(
              (a) => a['id'] == clip['source']['id'],
            );
            if (!qualifiedNodes.add(
              contentHash({
                'asset': asset['id'],
                'opacity': opacity,
                'transform': transform,
              }),
            )) {
              continue;
            }
            if (qualifiedNodes.length > 64) {
              throw const StudioException(
                'RESOURCE_EFFECT_QUALIFICATION_LIMIT',
              );
            }
            final original = await _blobs!.resolve(asset['originalBlobHash']);
            check();
            await engine.previewAsync(
              original,
              Q.fromJson(clip['sourceRange']['start']),
              opacityQ16: opacity,
              transform2d: transform,
            );
            check();
          }
        }
        // A capability bit or two individually decoded sources cannot qualify
        // their joint colour/format/dimension consumer. Probe an actual window.
        for (final t in definition['transitions']) {
          if (t['enabled'] != true) continue;
          if (qualifiedNodes.length >= 64) {
            throw const StudioException('RESOURCE_EFFECT_QUALIFICATION_LIMIT');
          }
          qualifiedNodes.add('dissolve:${t['id']}');
          final midpoint =
              Q.fromJson(t['cut']) +
              (Q.fromJson(t['after']) - Q.fromJson(t['before'])) / Q.of(2);
          final point = graph.sampleFrame(midpoint), right = point.secondary!;
          final primaryAsset = (definition['assets'] as List).singleWhere(
                (v) => v['id'] == point.assetId,
              ),
              otherAsset = (definition['assets'] as List).singleWhere(
                (v) => v['id'] == right.assetId,
              );
          final primary = await _blobs!.resolve(
            primaryAsset['originalBlobHash'],
          );
          check();
          final other = await _blobs!.resolve(otherAsset['originalBlobHash']);
          check();
          await engine.previewAsync(
            primary,
            point.sourceTime,
            opacityQ16: point.opacityQ16,
            transform2d: point.transform2d,
            secondary: {
              'path': other.absolute.path,
              'time': right.sourceTime.toJson(),
              'indexed': true,
              'opacityQ16': right.opacityQ16,
              if (right.transform2d != null) 'transform2d': right.transform2d,
            },
            mixQ16: point.mixQ16,
          );
          check();
        }
        for (final hash in resources.keys) {
          await _blobs!.resolve(hash);
          check();
        }
        check();
        // No awaits between final authority check and the repository transaction.
        flushCheckpoint();
        final imported = _repository.createResourceFork(
          source: source,
          activeWriter: writer,
          expectedActiveHash: expectedActiveHash,
          newId: _uuid.v7,
        );
        _autosave?.dispose();
        clearPreviewProxies();
        _activeProjectId = imported.project.projectId;
        _writer = imported.writer;
        _autosave = AutosaveScheduler(
          checkpoint: _captureCheckpoint,
          onError: (_) => _notifyPersistence(),
        );
        return current;
      });
    } finally {
      engine.close();
      _resourceImportEngine = null;
    }
  }

  Future<ProjectDocument> restoreArchive(LocalFileGrant source) async {
    _requireMedia();
    return _blobs!.withMaintenanceLease(() => _restoreArchiveLocked(source));
  }

  Future<ProjectDocument> _restoreArchiveLocked(LocalFileGrant source) async {
    clearPreviewProxies();
    _requireMedia();
    final verified = ProjectArchive().open(source.file);
    final fork = forkLocalProject(
      verified.project,
      _repository.namespace,
      newId: _uuid.v7,
    );
    for (final e in verified.originals.entries) {
      await _blobs!.putVerifiedBytes(e.key, e.value);
    }
    for (final a in fork.toJson()['assets']) {
      for (final p in a['proxyRefs']) {
        final mf = await _blobs!.resolve(
              p['ptsMapBlobHash'],
              maxBytes: 1024 * 1024,
            ),
            rf = await _blobs!.resolve(
              p['blobHash'],
              maxBytes: 64 * 1024 * 1024,
            );
        final facts = validateProxyResourceBytes(
          a,
          p,
          await mf.readAsBytes(),
          await rf.readAsBytes(),
        );
        await _qualifyPreview(
          a,
          p,
          facts,
          await _blobs!.resolve(a['originalBlobHash']),
          ownsLease: true,
        );
      }
    }
    if (_closed) throw const StudioException('WORKSPACE_CLOSED');
    flushCheckpoint();
    _autosave?.dispose();
    _repository.create(fork);
    _repository.selectProject(fork.projectId);
    _activeProjectId = fork.projectId;
    _writer = _repository.acquireWriter(
      fork.projectId,
      _uuid.v7(),
      expectedEpoch: 0,
    );
    _autosave = AutosaveScheduler(
      checkpoint: _captureCheckpoint,
      onError: (_) => _notifyPersistence(),
    );
    _repository.captureCheckpoint(_writer!);
    return current;
  }

  void cancelExport() {
    _exportCancelEpoch++;
    _media?.cancel();
  }

  NativeMedia? _playbackMedia;
  Directory? _playbackDirectory;
  int _playbackGeneration = 0;
  String? _playbackHash;
  ProjectDocument? _playbackSnapshot;
  TimelineVideoGraph? _playbackGraph;
  Map<String, Map<String, dynamic>> _playbackAssets = const {};
  Map<String, dynamic> _playbackBlobs = const {};
  Map<String, dynamic> get timelinePlayback {
    final result =
        _playbackMedia?.playback({'op': 'status'}) ?? {'state': 'stopped'};
    return {
      ...result,
      'snapshotHash': _playbackHash,
      'playbackGeneration': _playbackGeneration,
    };
  }

  void stopTimelinePlayback() {
    _playbackGeneration++;
    _playbackMedia?.cancel();
    _playbackMedia?.close();
    _playbackMedia = null;
    final dir = _playbackDirectory;
    _playbackDirectory = null;
    _playbackHash = null;
    _playbackSnapshot = null;
    _playbackGraph = null;
    _playbackAssets = const {};
    _playbackBlobs = const {};
    if (dir != null && dir.existsSync()) dir.deleteSync(recursive: true);
  }

  /// Backgrounding never auto-resumes or lets an in-flight preparation start audio.
  void pauseTimelinePlaybackForLifecycle() {
    if (_playbackMedia == null) return;
    final state = timelinePlayback['state'];
    if (state == 'stopped') {
      stopTimelinePlayback(); // PCM is still being prepared, not opened yet.
    } else if ({'playing', 'transition', 'connecting'}.contains(state)) {
      controlTimelinePlayback('pause');
    }
  }

  Map<String, dynamic> controlTimelinePlayback(
    String op, {
    int? sample,
    String? sink,
  }) {
    if (!{'pause', 'resume', 'seek', 'rebind'}.contains(op)) {
      throw const StudioException('PLAYBACK_COMMAND_UNKNOWN');
    }
    final media = _playbackMedia;
    if (media == null) throw const StudioException('PLAYBACK_NOT_OPEN');
    if (current.hash != _playbackHash) {
      stopTimelinePlayback();
      throw const StudioException('PLAYBACK_REVISION_CHANGED');
    }
    return media.playback({'op': op, 'sample': ?sample, 'sink': ?sink});
  }

  /// Bounded pre-rendered audio timeline audition, NOT a video RenderGraph.
  Future<Map<String, dynamic>> playTimeline({String? sink}) async {
    _requireMedia();
    if (_media!.capabilities['pulseServicePlaybackV1'] != true) {
      throw const StudioException('AUDIO_SINK_ADAPTER_UNAVAILABLE');
    }
    stopTimelinePlayback();
    final generation = _playbackGeneration,
        snapshot = current,
        d = snapshot.toJson(),
        sequence = snapshot.toJson()['sequences'][0];
    requireLocalEditingWritable(snapshot);
    final tracks = (sequence['tracks'] as List)
        .where((t) => t['kind'] == 'audio')
        .toList();
    if (tracks.isEmpty ||
        !tracks.any(
          (t) => (t['items'] as List).any((c) => c['source'] != null),
        )) {
      throw const StudioException('PERSISTENT_AUDIO_REQUIRED');
    }
    final media = NativeMedia.open(_media!.libraryPath, snapshot.namespace);
    _playbackMedia = media;
    _playbackHash = snapshot.hash;
    _playbackSnapshot = snapshot;
    _playbackBlobs = {for (final b in d['blobs']) b['hash'] as String: b};
    _playbackAssets = {
      for (final a in d['assets'])
        a['id'] as String: Map<String, dynamic>.from(a as Map),
    };
    Directory? owned;
    // The preparation owns its directory until all native/isolate calls finish.
    // Stop/close cancels the handle, but must never delete a file under an isolate.
    var adopted = false;
    void check() {
      if (_closed ||
          generation != _playbackGeneration ||
          current.hash != snapshot.hash) {
        throw const StudioException('CANCELED');
      }
    }

    try {
      final dir = await Directory.systemTemp.createTemp('studio-audition-');
      owned = dir;
      check();
      final segments = <Map<String, dynamic>>[];
      for (final track in tracks) {
        if (track['muted'] == true) continue;
        for (final clip in track['items']) {
          if (clip['source'] == null || clip['enabled'] == false) continue;
          if (Q.fromJson(clip['timeMap']['rate']) != Q.of(1)) {
            throw const StudioException('RETIME_RENDER_NOT_IMPLEMENTED');
          }
          final asset = (d['assets'] as List).singleWhere(
            (a) => a['id'] == clip['source']['id'],
          );
          final expected = (asset['streams'] as List).singleWhere(
            (st) => st['id'] == clip['source']['streamId'],
          );
          final file = await _blobs!.resolve(
            asset['originalBlobHash'] as String,
          );
          check();
          final fact = await media.probeAsync(file);
          check();
          final raw = (fact['streams'] as List).singleWhere(
            (st) =>
                '${asset['id']}:stream-${st['index']}' ==
                clip['source']['streamId'],
          );
          if (contentHash(
                streamDocument(
                  Map<String, dynamic>.from(raw as Map),
                  assetId: asset['id'] as String,
                ),
              ) !=
              contentHash(expected)) {
            throw const StudioException('SOURCE_STREAM_CHANGED');
          }
          final origin =
              Q(BigInt.parse(raw['startPTS'] as String), BigInt.one) *
              Q.of(raw['timeBase']['n'] as int, raw['timeBase']['d'] as int);
          final start = sampleIndex(
                Q.fromJson(clip['timelineRange']['start']),
                48000,
                Rounding.tiesToEven,
              ).toInt(),
              end = sampleIndex(
                Q.fromJson(clip['timelineRange']['start']) +
                    Q.fromJson(clip['timelineRange']['duration']),
                48000,
                Rounding.tiesToEven,
              ).toInt();
          segments.add({
            'path': file.absolute.path,
            'streamIndex': raw['index'],
            'destStart': start,
            'sampleCount': end - start,
            'startSample': sampleIndex(
              origin + Q.fromJson(clip['sourceRange']['start']),
              48000,
              Rounding.tiesToEven,
            ).toInt(),
          });
        }
      }
      final pcm = await media.prepareAudioAsync({
        'directory': dir.path,
        'sampleCount': sampleIndex(
          Q.fromJson(sequence['duration']),
          48000,
          Rounding.tiesToEven,
        ).toInt(),
        'segments': segments,
        'buses': d['audioBuses'],
        'masterId': sequence['masterBusId'],
      });
      check();
      media.playback({
        'op': 'open',
        'path': pcm['path'],
        'sampleCount': pcm['sampleCount'],
        'sink': ?sink,
      });
      check();
      _playbackDirectory = dir;
      adopted = true;
      return timelinePlayback;
    } catch (_) {
      // A canceled owner can close while an isolate is attaching/probing. Do not
      // leak a stale-handle error as a new current-project media failure.
      if (_closed || generation != _playbackGeneration) {
        throw const StudioException('CANCELED');
      }
      rethrow;
    } finally {
      if (!adopted) {
        media.close();
        if (identical(_playbackMedia, media)) {
          _playbackMedia = null;
          _playbackHash = null;
          _playbackSnapshot = null;
          _playbackGraph = null;
          _playbackAssets = const {};
          _playbackBlobs = const {};
        }
        if (owned != null && owned.existsSync()) {
          owned.deleteSync(recursive: true);
        }
      }
    }
  }

  bool _exportBusy = false;
  ProjectDocument setMasterAudio({
    double gainDb = 0,
    double pan = 0,
    bool muted = false,
    bool solo = false,
    required BigInt expectedRevision,
  }) => edit(
    SetMasterAudio(gainDb: gainDb, pan: pan, muted: muted, solo: solo),
    expectedRevision: expectedRevision,
  );
  Future<Map<String, dynamic>> exportVideo(
    File destination, {
    bool includeEmbeddedAudio = false,
    List<int> captureFrames = const [],
  }) async {
    _requireMedia();
    if (captureFrames.length > 4) throw const StudioException('CAPTURE_LIMIT');
    final generation = _exportCancelEpoch;
    if (_exportBusy) throw const StudioException('EXPORT_BUSY');
    _exportBusy = true;
    try {
      return await _exportVideo(
        destination,
        includeEmbeddedAudio: includeEmbeddedAudio,
        captureFrames: List<int>.of(captureFrames),
      );
    } catch (_) {
      if (_closed || generation != _exportCancelEpoch) {
        throw const StudioException('CANCELED');
      }
      rethrow;
    } finally {
      _exportBusy = false;
    }
  }

  Future<Map<String, dynamic>> _exportVideo(
    File destination, {
    required bool includeEmbeddedAudio,
    required List<int> captureFrames,
  }) async {
    _requireMedia();
    _protectOutput(destination);
    final snapshot = current;
    _requireTransformAdapter(snapshot);
    if ((snapshot.toJson()['effects'] as List).any(
          (e) => (e['keyframes'] as List).isNotEmpty,
        ) &&
        _media!.capabilities['linearOpacityKeyframesV1'] != true) {
      throw const StudioException('OPACITY_KEYFRAMES_ADAPTER_UNAVAILABLE');
    }
    requireLocalEditingWritable(snapshot);
    if ((snapshot.toJson()['captions'] as List).isNotEmpty) {
      throw const StudioException('CAPTION_RENDER_POLICY_NOT_IMPLEMENTED');
    }
    final epoch = _exportCancelEpoch;
    void checkCanceled() {
      if (_closed || epoch != _exportCancelEpoch) {
        throw const StudioException('CANCELED');
      }
    }

    final d = snapshot.toJson(), s = snapshot.toJson()['sequences'][0];
    final fps = FrameRate(
      s['frameRate']['n'] as int,
      s['frameRate']['d'] as int,
    );
    if (Q.fromJson(s['canvas']['pixelAspect']) != Q.of(1) ||
        s['workingColor'] != 'linear-rec709' ||
        s['outputColor'] != 'rec709' ||
        contentHash(s['backgroundRGBA']) != contentHash([0, 0, 0, 1])) {
      throw const StudioException('CANVAS_RENDER_POLICY_NOT_IMPLEMENTED');
    }
    if (captureFrames.length > 4 ||
        captureFrames.toSet().length != captureFrames.length) {
      throw const StudioException('CAPTURE_LIMIT');
    }
    final videoGraph = TimelineVideoGraph(snapshot);
    if (((d['effects'] as List).isNotEmpty || captureFrames.isNotEmpty) &&
        _media!.capabilities['linearOpacityV1'] != true) {
      throw const StudioException('OPACITY_ADAPTER_UNAVAILABLE');
    }
    final count = fps
        .frameIndex(Q.fromJson(s['duration']), Rounding.tiesToEven)
        .toInt();
    if (count <= 0) throw const StudioException('EMPTY_SEQUENCE');
    // Bound the TOTAL before allocating any per-clip keyframe schedules.
    // Native already enforces this same delivery-frame resource limit.
    if (count > 120000) throw const StudioException('RENDER_FRAME_LIMIT');
    if (captureFrames.any((n) => n < 0 || n >= count)) {
      throw const StudioException('CAPTURE_RANGE');
    }
    final persistentAudio = (s['tracks'] as List).any(
      (t) =>
          t['kind'] == 'audio' &&
          (t['items'] as List).any((c) => c['source'] != null),
    );
    if (persistentAudio && includeEmbeddedAudio) {
      throw const StudioException('AUDIO_SOURCE_MODE_AMBIGUOUS');
    }
    final renderAudio = persistentAudio || includeEmbeddedAudio;
    final assets = {for (final a in d['assets'] as List) a['id']: a};
    final segments = <Map<String, dynamic>>[];
    final segmentsByClip = <String, Map<String, dynamic>>{};
    final audioSegments = <Map<String, dynamic>>[];
    final probed = <String, Map<String, dynamic>>{};
    for (final track in s['tracks']) {
      if (track['muted'] == true) continue;
      for (final clip in track['items']) {
        if (clip['source'] == null || clip['enabled'] == false) continue;
        if (Q.fromJson(clip['timeMap']['rate']) != Q.of(1)) {
          throw const StudioException('RETIME_RENDER_NOT_IMPLEMENTED');
        }
        final a = assets[clip['source']['id']];
        final stream = (a['streams'] as List).singleWhere(
          (v) => v['id'] == clip['source']['streamId'],
        );
        if (track['kind'] == 'video' && stream['variableFrameRate'] != false) {
          throw const StudioException('VFR_RENDER_NOT_VALIDATED');
        }
        final color = stream['color'];
        if (track['kind'] == 'video' &&
            (color == null ||
                color['primaries'] != 'bt709' ||
                color['transfer'] != 'bt709' ||
                color['matrix'] != 'bt709' ||
                color['range'] != 'limited' ||
                color['bitDepth'] != 8 ||
                color['alpha'] != 'none')) {
          throw const StudioException('COLOR_POLICY_REQUIRED');
        }
        final file = await _blobs!.resolve(a['originalBlobHash'] as String);
        checkCanceled();
        final fact = probed[a['originalBlobHash']] ??= await _media!.probeAsync(
          file,
        );
        checkCanceled();
        final position = (a['streams'] as List).indexWhere(
          (v) => v['id'] == stream['id'],
        );
        final raw = (fact['streams'] as List)[position] as Map<String, dynamic>;
        final actual = streamDocument(raw, assetId: 'verification')
          ..remove('id');
        final expected = Map<String, dynamic>.from(stream as Map)..remove('id');
        if (contentHash(actual) != contentHash(expected)) {
          throw const StudioException('SOURCE_STREAM_CHANGED');
        }
        final index = raw['index'] as int;
        if (track['kind'] == 'audio') {
          if (raw['type'] != 'audio') {
            throw const StudioException('AUDIO_STREAM_REQUIRED');
          }
          final start = sampleIndex(
                Q.fromJson(clip['timelineRange']['start']),
                48000,
                Rounding.tiesToEven,
              ).toInt(),
              end = sampleIndex(
                Q.fromJson(clip['timelineRange']['start']) +
                    Q.fromJson(clip['timelineRange']['duration']),
                48000,
                Rounding.tiesToEven,
              ).toInt();
          final origin =
              Q(BigInt.parse(raw['startPTS'] as String), BigInt.one) *
              Q.of(raw['timeBase']['n'] as int, raw['timeBase']['d'] as int);
          audioSegments.add({
            'path': file.absolute.path,
            'streamIndex': index,
            'destStart': start,
            'sampleCount': end - start,
            'startSample': sampleIndex(
              origin + Q.fromJson(clip['sourceRange']['start']),
              48000,
              Rounding.tiesToEven,
            ).toInt(),
          });
          continue;
        }
        if (includeEmbeddedAudio) {
          final audios = (fact['streams'] as List)
              .where((v) => v['type'] == 'audio')
              .toList();
          if (audios.length > 1) {
            throw const StudioException('AUDIO_STREAM_SELECTION_REQUIRED');
          }
          final start = sampleIndex(
            Q.fromJson(clip['timelineRange']['start']),
            48000,
            Rounding.tiesToEven,
          ).toInt();
          final end = sampleIndex(
            Q.fromJson(clip['timelineRange']['start']) +
                Q.fromJson(clip['timelineRange']['duration']),
            48000,
            Rounding.tiesToEven,
          ).toInt();
          final origin = Q(
            BigInt.parse(raw['startPTS'] as String) *
                BigInt.from(raw['timeBase']['n'] as int),
            BigInt.from(raw['timeBase']['d'] as int),
          );
          audioSegments.add({
            'path': file.absolute.path,
            'streamIndex': audios.isEmpty ? null : audios.single['index'],
            'destStart': start,
            'sampleCount': end - start,
            'startSample': sampleIndex(
              origin + Q.fromJson(clip['sourceRange']['start']),
              48000,
              Rounding.tiesToEven,
            ).toInt(),
          });
        }
        final segment = videoGraph.encoderSegment(
          clip['id'] as String,
          originalPath: file.absolute.path,
          streamIndex: index,
          frameRate: fps,
        );
        segments.add(segment);
        segmentsByClip[clip['id'] as String] = segment;
      }
    }
    final publisher = AtomicFilePublisher(),
        stage = AtomicFilePublisher().stagingFor(destination);
    Directory? audioDirectory;
    Map<String, dynamic>? audioPcm;
    try {
      checkCanceled();
      if (renderAudio) {
        if (!persistentAudio &&
            !audioSegments.any((v) => v['streamIndex'] != null)) {
          throw const StudioException('EMBEDDED_AUDIO_REQUIRED');
        }
        audioDirectory = await Directory.systemTemp.createTemp(
          'studio-offline-audio-',
        );
        checkCanceled();
        audioPcm = await _media!.prepareAudioAsync({
          'directory': audioDirectory.path,
          'sampleCount': sampleIndex(
            Q.fromJson(s['duration']),
            48000,
            Rounding.tiesToEven,
          ).toInt(),
          'segments': audioSegments,
          'buses': d['audioBuses'],
          'masterId': s['masterBusId'],
        });
        if (epoch != _exportCancelEpoch || _closed) {
          throw const StudioException('CANCELED');
        }
      }
      final result = await _media!.renderAsync({
        'outputPath': stage.absolute.path,
        if (captureFrames.isNotEmpty) 'captureFrames': captureFrames,
        'width': s['canvas']['width'],
        'height': s['canvas']['height'],
        'fps': s['frameRate'],
        'frameCount': count,
        'segments': (d['transitions'] as List).isEmpty
            ? segments
            : videoGraph.compileDissolves(segmentsByClip),
        if (audioPcm != null)
          'audio': {
            'path': audioPcm['path'],
            'sampleCount': audioPcm['sampleCount'],
          },
      });
      if (epoch != _exportCancelEpoch || _closed) {
        throw const StudioException('CANCELED');
      }
      final verified = await _media!.probeAsync(stage);
      checkCanceled();
      final video = (verified['streams'] as List).singleWhere(
        (v) => v['type'] == 'video',
      );
      final sd = streamDocument(
        video as Map<String, dynamic>,
        assetId: 'export',
      );
      if (sd['codec'] != 'h264' ||
          video['profile'] != 'Main' ||
          video['level'] != 40 ||
          video['pixelFormat'] != 'yuv420p' ||
          Q.fromJson(sd['duration']) != Q.fromJson(s['duration'])) {
        throw const StudioException('EXPORT_VERIFICATION_FAILED');
      }
      if (renderAudio) {
        final audios = (verified['streams'] as List)
            .where((v) => v['type'] == 'audio')
            .toList();
        if (audios.length != 1) {
          throw const StudioException('AUDIO_EXPORT_VERIFICATION_FAILED');
        }
        final a = audios.single as Map<String, dynamic>,
            tb = Q.of(a['timeBase']['n'] as int, a['timeBase']['d'] as int);
        final duration =
            Q(BigInt.parse(a['durationTicks'] as String), BigInt.one) *
            Q.of(
              a['durationTimeBase']['n'] as int,
              a['durationTimeBase']['d'] as int,
            );
        if (a['codec'] != 'aac' ||
            a['sampleRate'] != 48000 ||
            a['channels'] != 2 ||
            BigInt.parse(a['startPTS'] as String) != BigInt.zero ||
            duration != Q.of(audioPcm!['sampleCount'] as int, 48000)) {
          throw const StudioException('AUDIO_EXPORT_VERIFICATION_FAILED');
        }
        if (tb <= Q.of(0)) {
          throw const StudioException('AUDIO_EXPORT_VERIFICATION_FAILED');
        }
        final decoded = await _media!.decodeAudioAsync({
          'path': stage.path,
          'outputPath': '${audioDirectory!.path}/verified.f32',
          'streamIndex': a['index'],
          'startSample': 0,
          'sampleCount': audioPcm['sampleCount'],
        });
        if (decoded['writtenSamples'] != audioPcm['sampleCount'] ||
            decoded['firstDecodedSample'] != 0) {
          throw const StudioException('AUDIO_EXPORT_VERIFICATION_FAILED');
        }
      }
      final hash = await hashLocalFile(stage);
      if (epoch != _exportCancelEpoch || _closed) {
        throw const StudioException('CANCELED');
      }
      publisher.publish(stage, destination);
      return {
        ...result,
        'snapshotHash': snapshot.hash,
        'revision': snapshot.revision.toString(),
        'outputHash': hash,
        'audio': renderAudio ? 'aac' : 'video-only',
        if (audioPcm != null) 'audioSamples': audioPcm['sampleCount'],
        'warnings': [
          ...?audioPcm?['warnings'] as List?,
          if (includeEmbeddedAudio)
            'EMBEDDED_AUDIO_EXPORT_OPTION_NOT_AUDIOCLIP_LINK',
          (d['rightsRecords'] as List).any((r) => r['verified'] != true)
              ? 'LICENSE_EVIDENCE_MISSING'
              : null,
        ].whereType<String>().toList(),
      };
    } finally {
      if (stage.existsSync()) stage.deleteSync();
      if (audioDirectory != null && audioDirectory.existsSync()) {
        audioDirectory.deleteSync(recursive: true);
      }
    }
  }

  void close() {
    cancelResourceImport();
    stopTimelinePlayback();
    if (!_closed) {
      if (_saves?.pending == true) {
        throw const StudioException('SAVE_IN_PROGRESS');
      }
      try {
        flushCheckpoint();
      } on StudioException catch (error) {
        // Already-durable edits stay in SQLite. A superseded writer must not
        // overwrite the new owner's checkpoint, nor leak resources on shutdown.
        if (error.code != 'WRITER_FENCED') rethrow;
      }
      _autosave?.dispose();
      cancelExport();
      _closed = true;
      unawaited(_persistenceEvents.close());
      cancelPreviewProxyBuild();
      for (final proxy in _frameProxies.values) {
        proxy.dispose();
      }
      _frameProxies.clear();
      cancelSourcePreview();
      _previewMedia?.close();
      _previewMedia = null;
      sourcePreviewCache.clear();
      _media?.close();
      _repository.close();
    }
  }
}
