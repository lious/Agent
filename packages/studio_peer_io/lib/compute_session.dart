import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';

import 'package:studio_harness/studio_harness.dart';
import 'package:studio_document/studio_document.dart' show rawBytesHash;
import 'package:studio_harness/builtin_compute.dart';
import 'package:studio_store/studio_store.dart';

import 'studio_peer_io.dart';
import 'boot_clock.dart';

import 'package:uuid/uuid.dart';

String get nativeMetadataRuntimePin => harnessHash({
  'executor': 'native-builtin-v1',
  'pin': BuiltinCompute.pin('core.digest-json'),
});

/// User-selected project metadata only, two independent bounded CPU tasks. No
/// media/model/shell/provider execution or automatically selected local files.
final class ComputeSessionCoordinator {
  ComputeSessionCoordinator(
    this._repository,
    this.projectId, {
    required this.id,
  }) : _boot = 'boot-${const Uuid().v4()}',
       _anchor = LinuxBootClock.anchor() {
    final project = _repository.read(projectId);
    if (project == null) throw const StudioException('PROJECT_NOT_FOUND');
    final document = project.toJson();
    final values = [
      {'payload': document},
      {'payload': document['captions']},
    ];
    session = SessionRef(namespace: _repository.namespace, id: id);
    final ns = harnessNamespace(session.namespace), zero = '0' * 64;
    final nodes = <Map<String, Object?>>[];
    for (var i = 0; i < values.length; i++) {
      final hash = harnessHash(values[i]);
      _inputs[hash] = values[i];
      nodes.add({
        'id': 'digest-$i',
        'kind': 'tool',
        'deps': <String>[],
        'handlerPin': BuiltinCompute.pin('core.digest-json'),
        'inputRef': {
          'ns': ns,
          'id': 'metadata-$i',
          'version': '1',
          'hash': hash,
        },
        'outputSchemaHash': BuiltinCompute.outputSchemaHash('core.digest-json'),
        'guard': {'kind': 'always'},
        'join': 'allSuccess',
        'mappedItemKey': null,
        'lane': 'localCpu',
        'requiredCaps': ['compute.digest'],
        'timeoutMs': '5000',
        'maxAttempts': 3,
        'sideEffect': 'localCandidate',
        'readSetHash': zero,
        'writeScopeHash': zero,
      });
    }
    if (utf8.encode(jsonEncode(_inputs)).length > 65536) {
      throw const StudioException('SESSION_METADATA_LIMIT');
    }
    plan = HarnessPlan({
      'recordType': 'PlanGraph',
      'schemaVersion': '1.0.0',
      'ns': ns,
      'planId': id,
      'version': '1',
      'rootRunId': id,
      'parentPlan': null,
      'baseRevision': project.revision.toString(),
      'effectiveIntentVersion': '1',
      'privacyEpoch': '1',
      'rightsEpoch': '1',
      'createdEventSeq': '1',
      'nodes': nodes,
      'limits': {
        'maxNodes': 2,
        'maxFanout': 2,
        'maxReplans': 0,
        'maxRepairRounds': 0,
        'maxModelIterations': 1,
        'maxTokens': '0',
        'maxCostMicros': '0',
        'currency': 'CNY',
        'maxWallMs': '600000',
      },
    });
    _clock.start();
    _repository.registerHarnessPlan(
      session,
      projectId,
      plan,
      coordinatorBoot: _boot,
      nowMs: 0,
    );
  }
  ComputeSessionCoordinator._restored(
    this._repository,
    this.projectId, {
    required this.id,
    required this._boot,
    required this._anchor,
    required HarnessPlan restoredPlan,
    required Map<String, Object?> inputs,
  }) {
    session = SessionRef(namespace: _repository.namespace, id: id);
    plan = restoredPlan;
    _inputs.addAll(inputs);
    _clock.start();
  }

  final String _boot;
  final Map<String, Object>? _anchor;
  int get _elapsedMs => _anchor == null
      ? _clock.elapsedMilliseconds
      : LinuxBootClock.ticksMs() - (_anchor['tickMs'] as int);
  bool get isListening => _server != null;

  void enableRecovery(String ownerFingerprint) =>
      _repository.withHarnessCoordinator(
        session,
        plan.hash,
        _boot,
        () => _repository.rememberMetadataSession(
          session,
          plan.hash,
          ownerFingerprint: ownerFingerprint,
          inputs: _inputs,
          anchor: _anchor,
        ),
      );

  static ComputeSessionCoordinator recover(
    DocumentRepository repository,
    String projectId, {
    required String sessionId,
    required String planHash,
    required String ownerFingerprint,
  }) {
    final session = SessionRef(namespace: repository.namespace, id: sessionId);
    final record = repository.metadataRecoveryRecord(
      session,
      planHash,
      ownerFingerprint,
    );
    if (record['projectId'] != projectId) {
      throw const StudioException('NAMESPACE_MISMATCH');
    }
    final now = LinuxBootClock.anchor(), old = record['anchor'] as Map?;
    int? downtime;
    if (record['boot'] == record['currentBoot'] &&
        now != null &&
        old != null &&
        old['schemaVersion'] == 'linux-boottime-1' &&
        old['bootId'] == now['bootId'] &&
        old['tickMs'] is int) {
      final elapsed =
          (now['tickMs'] as int) -
          (old['tickMs'] as int) -
          (record['lastMs'] as int);
      if (elapsed >= 0 && elapsed <= 604800000) downtime = elapsed;
    }
    final boot = 'boot-${const Uuid().v4()}';
    repository.authorizeMetadataRecovery(
      session,
      planHash,
      ownerFingerprint: ownerFingerprint,
      expectedBoot: record['currentBoot'] as String,
      newBoot: boot,
      operationId: 'recover-${const Uuid().v4()}',
      newAnchor: now,
      unobservedElapsedUpperBoundMs: downtime,
    );
    return ComputeSessionCoordinator._restored(
      repository,
      projectId,
      id: sessionId,
      boot: boot,
      anchor: now,
      restoredPlan: HarnessPlan(record['plan'] as Map<String, dynamic>),
      inputs: Map<String, Object?>.from(record['inputs'] as Map),
    );
  }

  final DocumentRepository _repository;
  final String projectId, id;
  late final SessionRef session;
  late final HarnessPlan plan;
  final _clock = Stopwatch(), _inputs = <String, Object?>{};
  PeerTlsServer? _server;
  String? _peerFingerprint;
  int? _epoch;
  bool _closed = false;
  Map<String, int> _blobGrants = {};
  String? get peerFingerprint => _peerFingerprint;
  String get runtimePin => nativeMetadataRuntimePin;

  /// Local owner approval, never RPC. Full fingerprint must be independently
  /// confirmed; selecting a node is selecting its exact frozen metadata input.
  int grant({
    required String fingerprint,
    required String deviceId,
    required Set<String> nodes,
    Map<String, int> allowedBlobs = const {},
  }) {
    final epoch = _repository.withHarnessCoordinator(
      session,
      plan.hash,
      _boot,
      () {
        if (_peerFingerprint != null || _closed) {
          throw const StudioException('SESSION_PAIRING_ALREADY_FIXED');
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        final offer = _repository.createPeerOffer(
          session,
          plan.hash,
          certificateFingerprint: fingerprint,
          device: VerifiedDevice(
            id: deviceId,
            platform: 'linux',
            runtimeHash: runtimePin,
            capabilities: {'compute.digest'},
            modelHashes: {},
            sessionIds: {session.id},
            freeMemoryBytes: 1024 * 1024,
            load: 0,
            permissionEpoch: 1,
          ),
          nodeIds: nodes,
          nowMs: now,
          offerExpiresMs: now + 120000,
          grantExpiresMs: now + 600000,
          allowedBlobs: allowedBlobs,
        );
        return _repository.confirmPeerOffer(offer, fingerprint, nowMs: now);
      },
    );
    _peerFingerprint = fingerprint;
    _blobGrants = Map.from(allowedBlobs);
    return _epoch = epoch;
  }

  Future<int> listen(
    SecurityContext context,
    InternetAddress address, {
    bool allowLan = false,
  }) async {
    if (_closed) throw const StudioException('SESSION_CLOSED');
    _repository.requireHarnessCoordinator(session, plan.hash, _boot);
    if (_server != null) {
      throw const StudioException('SESSION_ALREADY_LISTENING');
    }
    final server = await PeerTlsServer.bind(
      repository: _repository,
      context: context,
      coordinatorBoot: _boot,
      monotonicMs: () => _elapsedMs,
      wallMs: () => DateTime.now().millisecondsSinceEpoch,
      inputsByHash: _inputs,
      address: address,
      allowLan: allowLan,
    );
    try {
      if (_closed) throw const StudioException('SESSION_CLOSED');
      _repository.requireHarnessCoordinator(session, plan.hash, _boot);
    } catch (_) {
      await server.close();
      rethrow;
    }
    _server = server;
    return server.port;
  }

  Map<String, Object> invitation({
    required String endpoint,
    required String certificatePem,
    required Set<String> nodes,
  }) {
    _repository.requireHarnessCoordinator(session, plan.hash, _boot);
    if (_epoch == null) throw const StudioException('PEER_NOT_AUTHORIZED');
    return {
      'schemaVersion': '1.0.0',
      'endpoint': endpoint,
      'certificatePem': certificatePem,
      'sessionId': session.id,
      'planHash': plan.hash,
      'nodeIds': nodes.toList()..sort(),
      'epoch': '$_epoch',
      'runtimePin': runtimePin,
      'granteeFingerprint': _peerFingerprint!,
      'allowedBlobs': _blobGrants,
    };
  }

  Map<String, String> get statuses => {
    for (final n in ['digest-0', 'digest-1'])
      n: _repository.harnessStep(session, plan.hash, n)?.status ?? 'pending',
  };
  void revoke() {
    if (_peerFingerprint != null) {
      _repository.withHarnessCoordinator(
        session,
        plan.hash,
        _boot,
        () => _repository.revokePeer(
          _peerFingerprint!,
          session,
          plan.hash,
          nowMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  Future<String> runLocalNode(String node) async {
    if (_closed) throw const StudioException('SESSION_CLOSED');
    if (_repository.read(projectId)!.revision !=
        u63(plan.toJson()['baseRevision'])) {
      throw const StudioException('REVISION_CONFLICT');
    }
    final token = _repository.claimHarnessTask(
      session,
      plan.hash,
      node,
      VerifiedDevice(
        // This logical local slot must be stable across sessions sharing this
        // namespace/database, not a fresh device identity for every new plan.
        id: 'local-${harnessHash(_repository.namespace.key)}',
        platform: 'linux',
        runtimeHash: runtimePin,
        capabilities: {'compute.digest'},
        modelHashes: {},
        sessionIds: {session.id},
        freeMemoryBytes: 1024 * 1024,
        load: 0,
        permissionEpoch: 1,
      ),
      PlacementRequirement(),
      coordinatorBoot: _boot,
      nowMs: _elapsedMs,
      leaseMs: 1000,
    );
    final input = _inputs[plan.node(node)['inputRef']['hash']],
        pin = plan.node(node)['handlerPin'] as Map<String, dynamic>;
    final result = await Isolate.run(() => BuiltinCompute.execute(pin, input));
    if (_closed ||
        _repository.read(projectId)!.revision !=
            u63(plan.toJson()['baseRevision'])) {
      throw const StudioException('REVISION_CONFLICT');
    }
    return _repository.finishHarnessTask(
      session,
      token,
      result,
      coordinatorBoot: _boot,
      nowMs: _elapsedMs,
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      revoke();
    } on StudioException catch (e) {
      // Stale cleanup must NOT revoke a newly approved current-owner grant.
      if (e.code != 'COORDINATOR_FENCED') rethrow;
    } finally {
      await _server?.close();
      _server = null;
    }
  }
}

Future<Map<String, dynamic>> runPeerDigest(
  PeerTlsClient client,
  Map<String, dynamic> invite,
  String node, {
  required String operationId,
}) async {
  if (invite['schemaVersion'] != '1.0.0' ||
      !(invite['nodeIds'] as List).contains(node)) {
    throw const StudioException('PEER_NOT_AUTHORIZED');
  }
  Map<String, dynamic> request(String op, Map<String, dynamic> payload) => {
    'schemaVersion': '1.0.0',
    'id': '$operationId-$op',
    'sessionId': invite['sessionId'],
    'planHash': invite['planHash'],
    'epoch': invite['epoch'],
    'operation': op,
    'nodeId': node,
    'payload': payload,
  };
  final timer = Stopwatch()..start(),
      claim = await client.send(request('claim', {'leaseMs': 1000}));
  if (harnessHash(claim['input']) != claim['contentHash']) {
    throw const StudioException('COMPUTE_INPUT_HASH');
  }
  final input = claim['input'],
      pin = claim['handlerPin'] as Map<String, dynamic>;
  final result = await Isolate.run(() => BuiltinCompute.execute(pin, input));
  if (timer.elapsedMilliseconds >= (claim['remainingMs'] as int)) {
    throw const StudioException('LEASE_FENCED');
  }
  return client.send(
    request('finish', {
      'lease': claim['lease'],
      'result': result,
      'resultHash': harnessHash(result),
    }),
  );
}

/// Explicit frozen selected bytes only; no remote filename or local path is sent.
/// Status/bitmap is durable at receiver; every chunk and replay rechecks grants.
Future<Map<String, dynamic>> uploadPeerBlob(
  PeerTlsClient client,
  Map<String, dynamic> invite,
  String node,
  List<int> frozenBytes, {
  required String operationId,
}) async {
  if (frozenBytes.length > 16 * 1024 * 1024) {
    throw const StudioException('PEER_BLOB_QUOTA');
  }
  final bytes = Uint8List.fromList(frozenBytes).asUnmodifiableView(),
      hash = rawBytesHash(bytes).substring(7);
  if (invite['schemaVersion'] != '1.0.0' ||
      !(invite['nodeIds'] as List).contains(node) ||
      (invite['allowedBlobs'] as Map? ?? const {})[hash] != bytes.length) {
    throw const StudioException('PEER_BLOB_NOT_GRANTED');
  }
  var serial = 0;
  Future<Map<String, dynamic>> request(
    String op,
    Map<String, dynamic> payload,
  ) => client.send({
    'schemaVersion': '1.0.0',
    'id': '$operationId-${serial++}-$op',
    'sessionId': invite['sessionId'],
    'planHash': invite['planHash'],
    'epoch': invite['epoch'],
    'operation': op,
    'nodeId': node,
    'payload': {'blobHash': hash, ...payload},
  });
  final status = await request('blob.begin', {}),
      present = Set<int>.from(status['received'] as List);
  for (var index = 0; index < (bytes.length + 65535) ~/ 65536; index++) {
    if (present.contains(index)) continue;
    final end = (index + 1) * 65536 < bytes.length
            ? (index + 1) * 65536
            : bytes.length,
        part = bytes.sublist(index * 65536, end);
    await request('blob.chunk', {
      'index': index,
      'base64': base64.encode(part),
      'chunkHash': rawBytesHash(part).substring(7),
    });
  }
  return request('blob.finish', {});
}
