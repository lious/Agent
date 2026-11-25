import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

import 'studio_harness.dart';

String harnessHash(Object? value) => contentHash(value).substring(7);
String harnessNamespace(Namespace namespace) =>
    'ns.${harnessHash(namespace.toJson())}';
void _id(Object? value) {
  if (value is! String ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$').hasMatch(value)) {
    throw const StudioException('HARNESS_ID');
  }
}

void _hash(Object? value) {
  if (value is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    throw const StudioException('HARNESS_HASH');
  }
}

BigInt u63(Object? value) {
  if (value is! String || !RegExp(r'^(0|[1-9][0-9]{0,18})$').hasMatch(value)) {
    throw const StudioException('HARNESS_U63');
  }
  final n = BigInt.parse(value);
  if (n > BigInt.parse('9223372036854775807')) {
    throw const StudioException('HARNESS_U63');
  }
  return n;
}

void _closed(Map data, List<String> keys) {
  if (data.length != keys.length || !keys.every(data.containsKey)) {
    throw const StudioException('HARNESS_SCHEMA');
  }
}

/// Original urn:studio:harness-runtime:1.0.0 PlanGraph wire format, not a second
/// graph language. This executor accepts ONLY the explicitly safe subset below.
final class HarnessPlan {
  HarnessPlan(Map<String, dynamic> value) : _json = jsonEncode(value) {
    final p = toJson();
    _closed(p, [
      'recordType',
      'schemaVersion',
      'ns',
      'planId',
      'version',
      'rootRunId',
      'parentPlan',
      'baseRevision',
      'effectiveIntentVersion',
      'privacyEpoch',
      'rightsEpoch',
      'createdEventSeq',
      'nodes',
      'limits',
    ]);
    if (p['recordType'] != 'PlanGraph' || p['schemaVersion'] != '1.0.0') {
      throw const StudioException('HARNESS_PROTOCOL_VERSION');
    }
    for (final key in ['ns', 'planId', 'rootRunId']) {
      _id(p[key]);
    }
    for (final key in [
      'version',
      'baseRevision',
      'effectiveIntentVersion',
      'privacyEpoch',
      'rightsEpoch',
      'createdEventSeq',
    ]) {
      u63(p[key]);
    }
    if (p['parentPlan'] != null) {
      throw const StudioException('PLAN_REPLAN_NOT_IMPLEMENTED');
    }
    final nodes = p['nodes'] as List;
    if (nodes.isEmpty || nodes.length > 64) {
      throw const StudioException('PLAN_NODE_LIMIT');
    }
    final byId = <String, Map<String, dynamic>>{};
    for (final raw in nodes) {
      final n = raw as Map<String, dynamic>;
      _closed(n, [
        'id',
        'kind',
        'deps',
        'handlerPin',
        'inputRef',
        'outputSchemaHash',
        'guard',
        'join',
        'mappedItemKey',
        'lane',
        'requiredCaps',
        'timeoutMs',
        'maxAttempts',
        'sideEffect',
        'readSetHash',
        'writeScopeHash',
      ]);
      _id(n['id']);
      if (byId.containsKey(n['id'])) {
        throw const StudioException('PLAN_DUPLICATE_NODE');
      }
      byId[n['id'] as String] = n;
      if (!['tool', 'qa', 'reduce', 'checkpoint'].contains(n['kind']) ||
          !['none', 'localCandidate'].contains(n['sideEffect']) ||
          !['localCpu', 'localGpu'].contains(n['lane']) ||
          n['join'] != 'allSuccess' ||
          n['mappedItemKey'] != null) {
        throw const StudioException('PLAN_EXECUTION_SUBSET_REQUIRED');
      }
      final guard = n['guard'] as Map;
      _closed(guard, ['kind']);
      if (guard['kind'] != 'always') {
        throw const StudioException('PLAN_GUARD_NOT_IMPLEMENTED');
      }
      if (n['kind'] != 'checkpoint' || n['handlerPin'] != null) {
        final pin = n['handlerPin'] as Map;
        _closed(pin, ['id', 'version', 'hash']);
        _id(pin['id']);
        _hash(pin['hash']);
        if (pin['version'] is! String ||
            !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(pin['version'] as String)) {
          throw const StudioException('HARNESS_PIN');
        }
      }
      for (final key in ['outputSchemaHash', 'readSetHash', 'writeScopeHash']) {
        _hash(n[key]);
      }
      final ref = n['inputRef'] as Map;
      _closed(ref, ['ns', 'id', 'version', 'hash']);
      _id(ref['id']);
      _hash(ref['hash']);
      u63(ref['version']);
      if (ref['ns'] != p['ns']) {
        throw const StudioException('NAMESPACE_MISMATCH');
      }
      for (final key in ['deps', 'requiredCaps']) {
        final v = n[key] as List;
        if (v.length > (key == 'deps' ? 64 : 32) ||
            v.toSet().length != v.length) {
          throw const StudioException('HARNESS_SCHEMA');
        }
        for (final id in v) {
          _id(id);
        }
      }
      if (u63(n['timeoutMs']) == BigInt.zero ||
          u63(n['timeoutMs']) > BigInt.from(86400000) ||
          n['maxAttempts'] is! int ||
          (n['maxAttempts'] as int) < 1 ||
          (n['maxAttempts'] as int) > 3) {
        throw const StudioException('PLAN_LIMIT');
      }
    }
    final visiting = <String>{}, done = <String>{};
    void visit(String id) {
      if (visiting.contains(id)) throw const StudioException('PLAN_CYCLE');
      if (done.contains(id)) return;
      final n = byId[id];
      if (n == null) throw const StudioException('PLAN_DEPENDENCY_MISSING');
      visiting.add(id);
      for (final dep in n['deps']) {
        visit(dep as String);
      }
      visiting.remove(id);
      done.add(id);
    }

    for (final id in byId.keys) {
      visit(id);
    }
    final limits = p['limits'] as Map;
    _closed(limits, [
      'maxNodes',
      'maxFanout',
      'maxReplans',
      'maxRepairRounds',
      'maxModelIterations',
      'maxTokens',
      'maxCostMicros',
      'currency',
      'maxWallMs',
    ]);
    if (limits['maxNodes'] is! int ||
        (limits['maxNodes'] as int) < nodes.length ||
        (limits['maxNodes'] as int) > 64 ||
        limits['maxFanout'] is! int ||
        (limits['maxFanout'] as int) < 1 ||
        (limits['maxFanout'] as int) > 8 ||
        u63(limits['maxCostMicros']) != BigInt.zero) {
      throw const StudioException('PLAN_LIMIT');
    }
    if (u63(limits['maxWallMs']) == BigInt.zero ||
        u63(limits['maxWallMs']) > BigInt.from(604800000)) {
      throw const StudioException('PLAN_LIMIT');
    }
    for (final key in ['maxTokens', 'maxWallMs']) {
      u63(limits[key]);
    }
    if (limits['maxReplans'] is! int ||
        (limits['maxReplans'] as int) < 0 ||
        (limits['maxReplans'] as int) > 3 ||
        limits['maxRepairRounds'] is! int ||
        (limits['maxRepairRounds'] as int) < 0 ||
        (limits['maxRepairRounds'] as int) > 2 ||
        limits['maxModelIterations'] is! int ||
        (limits['maxModelIterations'] as int) < 1 ||
        (limits['maxModelIterations'] as int) > 64 ||
        limits['currency'] is! String ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(limits['currency'] as String)) {
      throw const StudioException('PLAN_LIMIT');
    }
    for (final id in byId.keys) {
      if (byId.values.where((n) => (n['deps'] as List).contains(id)).length >
          (limits['maxFanout'] as int)) {
        throw const StudioException('PLAN_FANOUT');
      }
    }
  }
  final String _json;
  Map<String, dynamic> toJson() => jsonDecode(_json) as Map<String, dynamic>;
  String get hash => harnessHash(toJson());
  Map<String, dynamic> node(String id) =>
      (toJson()['nodes'] as List).cast<Map<String, dynamic>>().singleWhere(
        (n) => n['id'] == id,
        orElse: () => throw const StudioException('PLAN_NODE_MISSING'),
      );
}

/// Host-registry record AFTER pairing and capability qualification, never raw
/// peer advertising. It is not a credential and cannot enroll/authorize itself.
final class VerifiedDevice {
  VerifiedDevice({
    required this.id,
    required this.platform,
    required this.runtimeHash,
    required Set<String> capabilities,
    required Set<String> modelHashes,
    required Set<String> sessionIds,
    required this.freeMemoryBytes,
    required this.load,
    required this.permissionEpoch,
    this.revoked = false,
    this.foreground = true,
  }) : capabilities = Set.unmodifiable(capabilities),
       modelHashes = Set.unmodifiable(modelHashes),
       sessionIds = Set.unmodifiable(sessionIds) {
    _id(id);
    _hash(runtimeHash);
    if (![
          'web',
          'linux',
          'macos',
          'windows',
          'ios',
          'android',
        ].contains(platform) ||
        freeMemoryBytes < 0 ||
        !load.isFinite ||
        load < 0 ||
        load > 1 ||
        permissionEpoch < 0) {
      throw const StudioException('DEVICE_CAPABILITY_INVALID');
    }
    for (final c in capabilities) {
      _id(c);
    }
    for (final h in modelHashes) {
      _hash(h);
    }
  }
  final String id, platform, runtimeHash;
  final Set<String> capabilities, modelHashes, sessionIds;
  final int freeMemoryBytes, permissionEpoch;
  final double load;
  final bool revoked, foreground;
}

final class PlacementRequirement {
  PlacementRequirement({this.memoryBytes = 0, Set<String> models = const {}})
    : models = Set.unmodifiable(models) {
    if (memoryBytes < 0) throw const StudioException('DEVICE_RESOURCE_LIMIT');
    for (final hash in models) {
      _hash(hash);
    }
  }
  final int memoryBytes;
  final Set<String> models;
}

VerifiedDevice? placeTask(
  SessionRef session,
  HarnessPlan plan,
  String nodeId,
  List<VerifiedDevice> devices,
  PlacementRequirement need,
) {
  if (plan.toJson()['ns'] != harnessNamespace(session.namespace)) {
    throw const StudioException('NAMESPACE_MISMATCH');
  }
  final node = plan.node(nodeId),
      caps = Set<String>.from(node['requiredCaps'] as List);
  final candidates = devices
      .where(
        (d) =>
            !d.revoked &&
            d.foreground &&
            d.permissionEpoch > 0 &&
            d.sessionIds.contains(session.id) &&
            d.capabilities.containsAll(caps) &&
            d.modelHashes.containsAll(need.models) &&
            d.freeMemoryBytes >= need.memoryBytes &&
            (node['lane'] != 'localGpu' ||
                d.capabilities.contains('compute.gpu')) &&
            d.load < 1,
      )
      .toList();
  candidates.sort((a, b) {
    final load = a.load.compareTo(b.load);
    if (load != 0) return load;
    final memory = b.freeMemoryBytes.compareTo(a.freeMemoryBytes);
    return memory != 0 ? memory : a.id.compareTo(b.id);
  });
  return candidates.isEmpty ? null : candidates.first;
}

/// Pure state reducer used by durable adapters and web workers. monotonic time is
/// meaningful ONLY with the coordinator boot epoch; never trust worker clocks.
final class TaskLease {
  TaskLease({
    required this.sessionId,
    required this.nodeId,
    required this.deviceId,
    required this.planHash,
    required this.inputHash,
    required this.coordinatorBoot,
    required this.fence,
    required this.cancelEpoch,
    required this.untilMs,
  });
  final String sessionId,
      nodeId,
      deviceId,
      planHash,
      inputHash,
      coordinatorBoot;
  final BigInt fence, cancelEpoch;
  final int untilMs;
}

final class LeaseState {
  LeaseState({
    required this.lease,
    this.status = 'running',
    this.progress = 0,
    this.resultHash,
  });
  final TaskLease lease;
  final String status;
  final double progress;
  final String? resultHash;
  void check(TaskLease token, int nowMs, String boot) {
    if (nowMs < 0 ||
        status != 'running' ||
        lease.fence != token.fence ||
        lease.cancelEpoch != token.cancelEpoch ||
        lease.coordinatorBoot != boot ||
        token.coordinatorBoot != boot ||
        lease.deviceId != token.deviceId ||
        lease.sessionId != token.sessionId ||
        lease.nodeId != token.nodeId ||
        lease.planHash != token.planHash ||
        lease.inputHash != token.inputHash ||
        nowMs >= lease.untilMs) {
      throw const StudioException('LEASE_FENCED');
    }
  }

  LeaseState heartbeat(
    TaskLease token,
    int nowMs,
    String boot,
    double progress,
    int extendMs,
  ) {
    check(token, nowMs, boot);
    if (!progress.isFinite ||
        progress < this.progress ||
        progress > 1 ||
        extendMs < 1 ||
        extendMs > 86400000) {
      throw const StudioException('LEASE_PROGRESS_INVALID');
    }
    return LeaseState(
      lease: TaskLease(
        sessionId: lease.sessionId,
        nodeId: lease.nodeId,
        deviceId: lease.deviceId,
        planHash: lease.planHash,
        inputHash: lease.inputHash,
        coordinatorBoot: boot,
        fence: lease.fence,
        cancelEpoch: lease.cancelEpoch,
        untilMs: nowMs + extendMs,
      ),
      progress: progress,
    );
  }

  LeaseState cancel() => status != 'running'
      ? this
      : LeaseState(
          lease: TaskLease(
            sessionId: lease.sessionId,
            nodeId: lease.nodeId,
            deviceId: lease.deviceId,
            planHash: lease.planHash,
            inputHash: lease.inputHash,
            coordinatorBoot: lease.coordinatorBoot,
            fence: lease.fence + BigInt.one,
            cancelEpoch: lease.cancelEpoch + BigInt.one,
            untilMs: lease.untilMs,
          ),
          status: 'cancelled',
          progress: progress,
        );
  LeaseState finish(TaskLease token, int nowMs, String boot, Object? result) {
    check(token, nowMs, boot);
    return LeaseState(
      lease: lease,
      status: 'committed',
      progress: 1,
      resultHash: harnessHash(result),
    );
  }
}

extension TaskLeaseCodec on TaskLease {
  Map<String, Object?> toJson() => {
    'recordType': 'TaskLease',
    'protocolVersion': '1.0.0',
    'sessionId': sessionId,
    'nodeId': nodeId,
    'deviceId': deviceId,
    'planHash': planHash,
    'inputHash': inputHash,
    'coordinatorBoot': coordinatorBoot,
    'fence': fence.toString(),
    'cancelEpoch': cancelEpoch.toString(),
    'untilMs': untilMs.toString(),
  };
}

TaskLease taskLeaseFromJson(Map<String, dynamic> j) {
  _closed(j, [
    'recordType',
    'protocolVersion',
    'sessionId',
    'nodeId',
    'deviceId',
    'planHash',
    'inputHash',
    'coordinatorBoot',
    'fence',
    'cancelEpoch',
    'untilMs',
  ]);
  if (j['recordType'] != 'TaskLease' || j['protocolVersion'] != '1.0.0') {
    throw const StudioException('HARNESS_PROTOCOL_VERSION');
  }
  for (final key in ['sessionId', 'nodeId', 'deviceId', 'coordinatorBoot']) {
    _id(j[key]);
  }
  for (final key in ['planHash', 'inputHash']) {
    _hash(j[key]);
  }
  final until = u63(j['untilMs']);
  if (until > BigInt.from(9007199254740991)) {
    throw const StudioException('LEASE_CLOCK_RANGE');
  }
  return TaskLease(
    sessionId: j['sessionId'] as String,
    nodeId: j['nodeId'] as String,
    deviceId: j['deviceId'] as String,
    planHash: j['planHash'] as String,
    inputHash: j['inputHash'] as String,
    coordinatorBoot: j['coordinatorBoot'] as String,
    fence: u63(j['fence']),
    cancelEpoch: u63(j['cancelEpoch']),
    untilMs: until.toInt(),
  );
}

extension LeaseStateCodec on LeaseState {
  Map<String, Object?> toJson() => {
    'lease': lease.toJson(),
    'status': status,
    'progress': progress,
    'resultHash': resultHash,
  };
}

LeaseState leaseStateFromJson(Map<String, dynamic> j) {
  _closed(j, ['lease', 'status', 'progress', 'resultHash']);
  if (!['running', 'committed', 'cancelled'].contains(j['status']) ||
      j['progress'] is! num ||
      (j['progress'] as num) < 0 ||
      (j['progress'] as num) > 1 ||
      !(j['progress'] as num).isFinite) {
    throw const StudioException('LEASE_STATE_INVALID');
  }
  if (j['resultHash'] != null) _hash(j['resultHash']);
  return LeaseState(
    lease: taskLeaseFromJson(j['lease'] as Map<String, dynamic>),
    status: j['status'] as String,
    progress: (j['progress'] as num).toDouble(),
    resultHash: j['resultHash'] as String?,
  );
}
