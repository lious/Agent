import 'package:studio_harness/studio_harness.dart';
import 'package:studio_contracts/studio_contracts.dart';

Map<String, dynamic> planFixture(Namespace ns) {
  final zero = '0' * 64, scope = harnessNamespace(ns);
  Map<String, Object?> node(
    String id,
    List<String> deps,
    String capability,
  ) => {
    'id': id,
    'kind': 'tool',
    'deps': deps,
    'handlerPin': {
      'id': 'fixture.$id',
      'version': '1.0.0',
      'hash': harnessHash({'handler': id, 'version': '1.0.0'}),
    },
    'inputRef': {'ns': scope, 'id': 'input-$id', 'version': '1', 'hash': zero},
    'outputSchemaHash': zero,
    'guard': {'kind': 'always'},
    'join': 'allSuccess',
    'mappedItemKey': null,
    'lane': 'localCpu',
    'requiredCaps': [capability],
    'timeoutMs': '1000',
    'maxAttempts': 3,
    'sideEffect': 'localCandidate',
    'readSetHash': zero,
    'writeScopeHash': zero,
  };
  return {
    'recordType': 'PlanGraph',
    'schemaVersion': '1.0.0',
    'ns': scope,
    'planId': 'plan',
    'version': '1',
    'rootRunId': 'root',
    'parentPlan': null,
    'baseRevision': '0',
    'effectiveIntentVersion': '1',
    'privacyEpoch': '1',
    'rightsEpoch': '1',
    'createdEventSeq': '1',
    'nodes': [
      node('a', [], 'compute.digest'),
      node('b', [], 'compute.audio'),
      node('c', ['a', 'b'], 'compute.reduce'),
    ],
    'limits': {
      'maxNodes': 64,
      'maxFanout': 8,
      'maxReplans': 0,
      'maxRepairRounds': 0,
      'maxModelIterations': 1,
      'maxTokens': '0',
      'maxCostMicros': '0',
      'currency': 'CNY',
      'maxWallMs': '10000',
    },
  };
}

VerifiedDevice deviceFixture(
  String id,
  Set<String> caps, {
  String platform = 'linux',
  bool revoked = false,
  bool foreground = true,
  int epoch = 1,
  double load = 0.1,
  Set<String> models = const {},
}) => VerifiedDevice(
  id: id,
  platform: platform,
  runtimeHash: 'a' * 64,
  capabilities: caps,
  modelHashes: models,
  sessionIds: {'session'},
  freeMemoryBytes: 1024 * 1024 * 1024,
  load: load,
  permissionEpoch: epoch,
  revoked: revoked,
  foreground: foreground,
);
