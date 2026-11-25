import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:web/web.dart' as web;
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:studio_harness/builtin_compute.dart';

import 'browser_store.dart';
import 'rtc_peer.dart';

String newPeerId() =>
    'web-${rawBytesHash(Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)))).substring(7, 39)}';
String get browserRuntimePin => harnessHash({
  'executor': 'web-builtin-v1',
  'pin': BuiltinCompute.pin('core.digest-json'),
});

/// Browser durability adapter of ORIGINAL HarnessPlan/LeaseState/TaskLease and
/// peer RPC shape. One explicit peer, two metadata-only free builtins. No SQLite
/// emulation, paid jobs, project writes, or device software-attestation claim.
final class BrowserComputeCoordinator {
  BrowserComputeCoordinator._(
    this.store,
    this.projectId,
    this.ownerFingerprint,
    this.id,
    this.boot,
    this.plan,
  ) {
    _clock.start();
  }
  final BrowserProjectStore store;
  final String projectId, ownerFingerprint, id, boot;
  final HarnessPlan plan;
  final Stopwatch _clock = Stopwatch();
  SessionRef get session => SessionRef(namespace: store.namespace, id: id);
  static Future<BrowserComputeCoordinator> create(
    BrowserProjectStore store,
    String projectId,
    String ownerFingerprint,
  ) async {
    normalizeFingerprint(ownerFingerprint);
    final doc = await store.read(projectId),
        id = newPeerId(),
        boot = newPeerId(),
        ns = harnessNamespace(store.namespace);
    final inputs = <String, Object?>{}, nodes = <Map<String, Object?>>[];
    final values = [
      {'payload': doc.toJson()},
      {'payload': doc.toJson()['captions']},
    ];
    for (var i = 0; i < 2; i++) {
      final hash = harnessHash(values[i]);
      inputs[hash] = values[i];
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
        'readSetHash': '0' * 64,
        'writeScopeHash': '0' * 64,
      });
    }
    if (utf8.encode(jsonEncode(inputs)).length > 16384) {
      throw const StudioException('WEB_METADATA_LIMIT');
    }
    final plan = HarnessPlan({
      'recordType': 'PlanGraph',
      'schemaVersion': '1.0.0',
      'ns': ns,
      'planId': id,
      'version': '1',
      'rootRunId': id,
      'parentPlan': null,
      'baseRevision': doc.revision.toString(),
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
    await store.peerTransaction(projectId, (current, runtime) {
      if (current.hash != doc.hash) {
        throw const StudioException('REVISION_CONFLICT');
      }
      final sessions = runtime['sessions'] as Map;
      if (sessions.length >= 8) {
        throw const StudioException('WEB_SESSION_RETENTION_LIMIT');
      }
      sessions[id] = {
        'plan': plan.toJson(),
        'planHash': plan.hash,
        'projectId': projectId,
        'boot': boot,
        'owner': ownerFingerprint,
        'inputs': inputs,
        'wall': DateTime.now().millisecondsSinceEpoch,
        'elapsed': 0,
        'lastWall': DateTime.now().millisecondsSinceEpoch,
        'suspended': false,
        'revoked': false,
        'grant': null,
        'steps': <String, dynamic>{},
        'receipts': <String, dynamic>{},
        'outbox': <String, dynamic>{},
      };
      return <String, dynamic>{};
    });
    return BrowserComputeCoordinator._(
      store,
      projectId,
      ownerFingerprint,
      id,
      boot,
      plan,
    );
  }

  Map<String, dynamic> _state(Map<String, dynamic> runtime) {
    final s = (runtime['sessions'] as Map)[id] as Map<String, dynamic>?;
    if (s == null || s['boot'] != boot || s['owner'] != ownerFingerprint) {
      throw const StudioException('COORDINATOR_FENCED');
    }
    if (s['planHash'] != plan.hash || harnessHash(s['plan']) != plan.hash) {
      throw const StudioException('WEB_PEER_INTEGRITY');
    }
    return s;
  }

  /// Commit clock highwater even if subsequent authorization/replay fails. Hidden
  /// tabs permanently suspend this session; no unqualified background execution.
  Future<void> _observe() async {
    await store.peerTransaction(projectId, (_, r) {
      final s = _state(r), wall = DateTime.now().millisecondsSinceEpoch;
      if (web.document.visibilityState != 'visible' ||
          wall < (s['lastWall'] as int)) {
        s['suspended'] = true;
      }
      s['lastWall'] = max(wall, s['lastWall'] as int);
      s['elapsed'] = max(
        s['elapsed'] as int,
        max(_clock.elapsedMilliseconds, wall - (s['wall'] as int)),
      );
      return <String, dynamic>{};
    });
  }

  Future<void> approve(
    String fingerprint, {
    required bool metadataConsent,
  }) async {
    final fp = normalizeFingerprint(fingerprint);
    if (!metadataConsent || fp == ownerFingerprint) {
      throw const StudioException('PEER_EXPLICIT_CONSENT_REQUIRED');
    }
    await _observe();
    await store.peerTransaction(projectId, (doc, r) {
      final s = _state(r);
      _admit(doc, s);
      if (s['grant'] != null) {
        throw const StudioException('SESSION_PAIRING_ALREADY_FIXED');
      }
      s['grant'] = {'fingerprint': fp, 'epoch': '1', 'revoked': false};
      return <String, dynamic>{};
    });
  }

  void _admit(ProjectDocument doc, Map<String, dynamic> s) {
    if (s['revoked'] == true) {
      throw const StudioException('PEER_NOT_AUTHORIZED');
    }
    if (doc.revision != u63(plan.toJson()['baseRevision'])) {
      throw const StudioException('REVISION_CONFLICT');
    }
    if (s['suspended'] == true) {
      throw const StudioException('WEB_SESSION_SUSPENDED');
    }
    if ((s['elapsed'] as int) >= 600000) {
      throw const StudioException('PLAN_WALL_BUDGET_EXHAUSTED');
    }
  }

  Map<String, dynamic> invitation() => {
    'schemaVersion': '1.0.0',
    'sessionId': id,
    'planHash': plan.hash,
    'epoch': '1',
    'nodeIds': ['digest-0'],
    'runtimePin': browserRuntimePin,
  };
  Future<Map<String, dynamic>> executePeerRequest(
    String fingerprint,
    Map<String, dynamic> request,
  ) => _execute(fingerprint, request, false);
  Future<Map<String, dynamic>> _execute(
    String fp,
    Map<String, dynamic> request,
    bool local,
  ) async {
    await _observe();
    return store.peerTransaction(projectId, (doc, r) {
      final s = _state(r);
      _admit(doc, s);
      const fields = {
        'schemaVersion',
        'id',
        'sessionId',
        'planHash',
        'epoch',
        'operation',
        'nodeId',
        'payload',
      };
      if (request.length != fields.length ||
          !request.keys.toSet().containsAll(fields) ||
          request['schemaVersion'] != '1.0.0' ||
          request['sessionId'] != id ||
          request['planHash'] != plan.hash) {
        throw const StudioException('PEER_PROTOCOL_VERSION');
      }
      final nodeId = request['nodeId'] as String, rid = request['id'] as String;
      requireId(rid);
      final grant = s['grant'] as Map?;
      if (local) {
        if (fp != ownerFingerprint ||
            nodeId != 'digest-1' ||
            request['epoch'] != 'local') {
          throw const StudioException('PEER_NOT_AUTHORIZED');
        }
      } else if (grant == null ||
          grant['revoked'] == true ||
          grant['fingerprint'] != fp ||
          grant['epoch'] != request['epoch'] ||
          nodeId != 'digest-0') {
        throw const StudioException('PEER_NOT_AUTHORIZED');
      }
      final receipts = s['receipts'] as Map,
          key = '${request['epoch']}/$rid',
          inputHash = harnessHash(request),
          steps = s['steps'] as Map,
          now = s['elapsed'] as int;
      LeaseState? state = steps[nodeId] == null
          ? null
          : leaseStateFromJson(
              Map<String, dynamic>.from(steps[nodeId]['state'] as Map),
            );
      final cached = receipts[key];
      if (cached != null) {
        if (cached['inputHash'] != inputHash) {
          throw const StudioException('IDEMPOTENCY_CONFLICT');
        }
        final response = Map<String, dynamic>.from(cached['response'] as Map);
        if (request['operation'] == 'claim') {
          final old = taskLeaseFromJson(
            Map<String, dynamic>.from(response['lease'] as Map),
          );
          if (state == null ||
              state.status != 'running' ||
              state.lease.fence != old.fence ||
              state.lease.untilMs <= now) {
            throw const StudioException('LEASE_FENCED');
          }
          response['lease'] = state.lease.toJson();
          response['remainingMs'] = state.lease.untilMs - now;
        }
        return response;
      }
      if (receipts.length >= 128) {
        throw const StudioException('PEER_REQUEST_QUOTA');
      }
      final payload = Map<String, dynamic>.from(request['payload'] as Map),
          node = plan.node(nodeId);
      Map<String, dynamic> response;
      switch (request['operation']) {
        case 'claim':
          if (payload.length != 1 || payload['leaseMs'] != 1000) {
            throw const StudioException('PEER_PROTOCOL_VERSION');
          }
          if (state?.status == 'committed') {
            throw const StudioException('ALREADY_COMMITTED');
          }
          if (state?.status == 'cancelled') {
            throw const StudioException('TASK_CANCELLED');
          }
          if (state != null && now < state.lease.untilMs) {
            throw const StudioException('LEASE_BUSY');
          }
          final deviceId = 'device-$fp';
          final device = VerifiedDevice(
            id: deviceId,
            platform: 'web',
            runtimeHash: browserRuntimePin,
            capabilities: {'compute.digest'},
            modelHashes: {},
            sessionIds: {id},
            freeMemoryBytes: 1024 * 1024,
            load: 0,
            permissionEpoch: 1,
            foreground: web.document.visibilityState == 'visible',
          );
          if (placeTask(session, plan, nodeId, [
                device,
              ], PlacementRequirement(memoryBytes: 16384)) ==
              null) {
            throw const StudioException('DEVICE_NOT_ELIGIBLE');
          }
          for (final other in (r['sessions'] as Map).values) {
            for (final step in (other['steps'] as Map).values) {
              final active = leaseStateFromJson(
                Map<String, dynamic>.from(step['state'] as Map),
              );
              if (active.lease.deviceId == deviceId &&
                  active.status != 'committed' &&
                  (active.lease.coordinatorBoot != boot ||
                      active.lease.untilMs > now)) {
                throw const StudioException('DEVICE_RESOURCE_QUARANTINED');
              }
            }
          }
          final attempt = (steps[nodeId]?['attempt'] as int? ?? 0) + 1;
          if (attempt > 3) {
            throw const StudioException('TASK_ATTEMPTS_EXHAUSTED');
          }
          final lease = TaskLease(
            sessionId: id,
            nodeId: nodeId,
            deviceId: deviceId,
            planHash: plan.hash,
            inputHash: harnessHash(node['inputRef']),
            coordinatorBoot: boot,
            fence: (state?.lease.fence ?? BigInt.zero) + BigInt.one,
            cancelEpoch: state?.lease.cancelEpoch ?? BigInt.zero,
            untilMs: min(now + 1000, 600000),
          );
          state = LeaseState(lease: lease);
          steps[nodeId] = {
            'attempt': attempt,
            'deadline': min(now + 5000, 600000),
            'state': state.toJson(),
          };
          final input = (s['inputs'] as Map)[node['inputRef']['hash']];
          response = {
            'lease': lease.toJson(),
            'input': input,
            'contentHash': harnessHash(input),
            'handlerPin': node['handlerPin'],
            'outputSchemaHash': node['outputSchemaHash'],
            'remainingMs': lease.untilMs - now,
          };
        case 'heartbeat':
          if (payload.length != 3 ||
              !payload.keys.toSet().containsAll({
                'lease',
                'progress',
                'extendMs',
              }) ||
              state == null ||
              payload['extendMs'] != 1000) {
            throw const StudioException('PEER_PROTOCOL_VERSION');
          }
          if (now + 1000 > (steps[nodeId]['deadline'] as int)) {
            throw const StudioException('TASK_ATTEMPT_TIMEOUT');
          }
          state = state.heartbeat(
            taskLeaseFromJson(
              Map<String, dynamic>.from(payload['lease'] as Map),
            ),
            now,
            boot,
            (payload['progress'] as num).toDouble(),
            1000,
          );
          steps[nodeId]['state'] = state.toJson();
          response = {'lease': state.lease.toJson()};
        case 'finish':
          if (payload.length != 3 ||
              !payload.keys.toSet().containsAll({
                'lease',
                'result',
                'resultHash',
              }) ||
              state == null) {
            throw const StudioException('PEER_PROTOCOL_VERSION');
          }
          final token = taskLeaseFromJson(
            Map<String, dynamic>.from(payload['lease'] as Map),
          );
          if (token.deviceId != 'device-$fp' ||
              token.nodeId != nodeId ||
              token.planHash != plan.hash ||
              token.sessionId != id) {
            throw const StudioException('LEASE_FENCED');
          }
          BuiltinCompute.validateResult('core.digest-json', payload['result']);
          final hash = harnessHash(payload['result']);
          if (hash != payload['resultHash']) {
            throw const StudioException('COMPUTE_RESULT_HASH');
          }
          if (state.status == 'committed') {
            if (harnessHash(state.lease.toJson()) !=
                    harnessHash(token.toJson()) ||
                state.resultHash != hash) {
              throw const StudioException('IDEMPOTENCY_CONFLICT');
            }
          } else {
            state = state.finish(token, now, boot, payload['result']);
            steps[nodeId]['state'] = state.toJson();
          }
          final outbox = s['outbox'] as Map;
          outbox[harnessHash({
            'session': id,
            'node': nodeId,
            'fence': token.fence.toString(),
          })] = {
            'kind': 'candidate.ready',
            'sessionId': id,
            'planHash': plan.hash,
            'inputHash': token.inputHash,
            'resultHash': hash,
            'sourceFingerprint': fp,
            'lease': token.toJson(),
            'result': payload['result'],
          };
          response = {'resultHash': hash};
        default:
          throw const StudioException('PEER_OPERATION_UNSUPPORTED');
      }
      receipts[key] = {'inputHash': inputHash, 'response': response};
      return response;
    });
  }

  Future<Map<String, dynamic>> runLocal() async {
    final claim = await _execute(
      ownerFingerprint,
      _request('local', newPeerId(), 'digest-1', 'claim', {'leaseMs': 1000}),
      true,
    );
    final result = BuiltinCompute.execute(
      Map<String, dynamic>.from(claim['handlerPin'] as Map),
      claim['input'],
    );
    return _execute(
      ownerFingerprint,
      _request('local', newPeerId(), 'digest-1', 'finish', {
        'lease': claim['lease'],
        'result': result,
        'resultHash': harnessHash(result),
      }),
      true,
    );
  }

  Map<String, dynamic> _request(
    String epoch,
    String rid,
    String node,
    String op,
    Map<String, dynamic> payload,
  ) => {
    'schemaVersion': '1.0.0',
    'id': rid,
    'sessionId': id,
    'planHash': plan.hash,
    'epoch': epoch,
    'operation': op,
    'nodeId': node,
    'payload': payload,
  };
  Future<Map<String, dynamic>> status() => store.peerTransaction(
    projectId,
    (_, r) => Map<String, dynamic>.from(_state(r)),
  );
  Future<void> revoke() async {
    await store.peerTransaction(projectId, (_, r) {
      final s = _state(r), grant = s['grant'] as Map?;
      s['revoked'] = true;
      if (grant != null) grant['revoked'] = true;
      for (final step in (s['steps'] as Map).values) {
        final state = leaseStateFromJson(
          Map<String, dynamic>.from(step['state'] as Map),
        );
        step['state'] = state.cancel().toJson();
      }
      return <String, dynamic>{};
    });
  }
}

Future<Map<String, dynamic>> runBrowserPeerDigest(
  RtcPeerLink link,
  Map<String, dynamic> invite, {
  required String operationId,
  required bool metadataConsent,
}) async {
  if (!metadataConsent || web.document.visibilityState != 'visible') {
    throw const StudioException('PEER_EXPLICIT_CONSENT_REQUIRED');
  }
  if (invite['schemaVersion'] != '1.0.0' ||
      invite['runtimePin'] != browserRuntimePin ||
      harnessHash(invite['nodeIds']) != harnessHash(['digest-0'])) {
    throw const StudioException('RUNTIME_PIN_MISMATCH');
  }
  Map<String, dynamic> request(
    String suffix,
    String op,
    Map<String, dynamic> payload,
  ) => {
    'schemaVersion': '1.0.0',
    'id': '$operationId-$suffix',
    'sessionId': invite['sessionId'],
    'planHash': invite['planHash'],
    'epoch': invite['epoch'],
    'nodeId': 'digest-0',
    'operation': op,
    'payload': payload,
  };
  final clock = Stopwatch()..start(),
      claim = await link.request(request('claim', 'claim', {'leaseMs': 1000}));
  if (harnessHash(claim['input']) != claim['contentHash'] ||
      harnessHash(claim['handlerPin']) !=
          harnessHash(BuiltinCompute.pin('core.digest-json')) ||
      claim['outputSchemaHash'] !=
          BuiltinCompute.outputSchemaHash('core.digest-json')) {
    throw const StudioException('COMPUTE_INPUT_HASH');
  }
  final result = BuiltinCompute.execute(
    Map<String, dynamic>.from(claim['handlerPin'] as Map),
    claim['input'],
  );
  if (web.document.visibilityState != 'visible' ||
      clock.elapsedMilliseconds >= (claim['remainingMs'] as int)) {
    throw const StudioException('LEASE_FENCED');
  }
  return link.request(
    request('finish', 'finish', {
      'lease': claim['lease'],
      'result': result,
      'resultHash': harnessHash(result),
    }),
  );
}
