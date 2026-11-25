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
    if (operation is AppendVideoAsset) {
      throw const StudioException('CONTROLLED_IMPORT_REQUIRED');
    }
    return _commitImportedEdit(operation, expectedRevision: expectedRevision);
  }

  ProjectDocument _commitImportedEdit(
    EditOperation operation, {
    required BigInt expectedRevision,
  }) {
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

  final sourcePreviewCache = SourcePreviewCache();
  NativeMedia? _previewMedia;
  int _previewEpoch = 0;
  Future<void> _previewTail = Future.value();
  void cancelSourcePreview() {
    ++_previewEpoch;
    _previewMedia?.cancel();
  }

  Future<SourcePreviewFrame> previewAssetSource(String assetId, Q time) async {
    _requireMedia();
    if (time < Q.of(0)) throw const StudioException('PREVIEW_TIME_INVALID');
    final project = current, epoch = ++_previewEpoch;
    _previewMedia?.cancel();
    final asset = (project.toJson()['assets'] as List).singleWhere(
      (a) => a['id'] == assetId,
      orElse: () => throw const StudioException('ASSET_NOT_FOUND'),
    );
    final hash = asset['originalBlobHash'] as String;
    final key = contentHash({
      'ns': project.namespace.toJson(),
      'blob': hash,
      'time': time.toJson(),
      'preview': 'source-rgba128-1',
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
      final frame = SourcePreviewFrame(
        await _previewMedia!.previewAsync(file, time),
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

  Future<Map<String, int>> collectLocalGarbage() async {
    _requireMedia();
    return _blobs!.withMaintenanceLease(() async {
      final cas = _repository.withRetainedBlobPins(
        (pins) => _blobs!.collectUnreferenced(pins),
      );
      final inbox = _repository.collectPeerInbox(
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
      return {'casFiles': cas['files']!, 'casBytes': cas['bytes']!, ...inbox};
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

  Future<ProjectDocument> restoreArchive(LocalFileGrant source) async {
    _requireMedia();
    return _blobs!.withMaintenanceLease(() => _restoreArchiveLocked(source));
  }

  Future<ProjectDocument> _restoreArchiveLocked(LocalFileGrant source) async {
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
  }) async {
    _requireMedia();
    final generation = _exportCancelEpoch;
    if (_exportBusy) throw const StudioException('EXPORT_BUSY');
    _exportBusy = true;
    try {
      return await _exportVideo(
        destination,
        includeEmbeddedAudio: includeEmbeddedAudio,
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
  }) async {
    _requireMedia();
    _protectOutput(destination);
    final snapshot = current;
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
    final count = fps
        .frameIndex(Q.fromJson(s['duration']), Rounding.tiesToEven)
        .toInt();
    if (count <= 0) throw const StudioException('EMPTY_SEQUENCE');
    final assets = {for (final a in d['assets'] as List) a['id']: a};
    final segments = <Map<String, dynamic>>[];
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
        if (stream['variableFrameRate'] != false) {
          throw const StudioException('VFR_RENDER_NOT_VALIDATED');
        }
        final color = stream['color'];
        if (color == null ||
            color['primaries'] != 'bt709' ||
            color['transfer'] != 'bt709' ||
            color['matrix'] != 'bt709' ||
            color['range'] != 'limited' ||
            color['bitDepth'] != 8 ||
            color['alpha'] != 'none') {
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
        segments.add({
          'path': file.absolute.path,
          'startFrame': fps
              .frameIndex(
                Q.fromJson(clip['timelineRange']['start']),
                Rounding.tiesToEven,
              )
              .toInt(),
          'frameCount': fps
              .frameIndex(
                Q.fromJson(clip['timelineRange']['duration']),
                Rounding.tiesToEven,
              )
              .toInt(),
          'sourceStart': clip['sourceRange']['start'],
          'streamIndex': index,
        });
      }
    }
    final publisher = AtomicFilePublisher(),
        stage = AtomicFilePublisher().stagingFor(destination);
    Directory? audioDirectory;
    Map<String, dynamic>? audioPcm;
    try {
      checkCanceled();
      if (includeEmbeddedAudio) {
        if (!audioSegments.any((v) => v['streamIndex'] != null)) {
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
        'width': s['canvas']['width'],
        'height': s['canvas']['height'],
        'fps': s['frameRate'],
        'frameCount': count,
        'segments': segments,
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
      if (includeEmbeddedAudio) {
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
        'audio': includeEmbeddedAudio ? 'aac' : 'video-only',
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
    if (!_closed) {
      if (_saves?.pending == true) {
        throw const StudioException('SAVE_IN_PROGRESS');
      }
      flushCheckpoint();
      _autosave?.dispose();
      cancelExport();
      _closed = true;
      unawaited(_persistenceEvents.close());
      cancelSourcePreview();
      _previewMedia?.close();
      sourcePreviewCache.clear();
      _media?.close();
      _repository.close();
    }
  }
}
