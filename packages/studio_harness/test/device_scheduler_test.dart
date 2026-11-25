import 'package:studio_harness/studio_harness.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

import 'package:studio_harness/testing_fixtures.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));
void main() {
  final ns = Namespace('studio', 'local', 'devices'),
      session = SessionRef(
        namespace: Namespace('studio', 'local', 'devices'),
        id: 'session',
      );
  test('original PlanGraph compatible subset validates DAG/version/closed shape/namespace and rejects paid execution', () {
    final raw = planFixture(ns), plan = HarnessPlan(raw);
    raw['nodes'][0]['id'] = 'mutated';
    expect(plan.node('a')['id'], 'a');
    final cycle = planFixture(ns);
    cycle['nodes'][0]['deps'] = ['c'];
    expect(() => HarnessPlan(cycle), code('PLAN_CYCLE'));
    final paid = planFixture(ns);
    paid['nodes'][0]['sideEffect'] = 'networkPaid';
    expect(() => HarnessPlan(paid), code('PLAN_EXECUTION_SUBSET_REQUIRED'));
    final version = planFixture(ns)..['schemaVersion'] = '99';
    expect(() => HarnessPlan(version), code('HARNESS_PROTOCOL_VERSION'));
    expect(
      () => HarnessPlan(planFixture(ns)..['unexpected'] = 'do things'),
      code('HARNESS_SCHEMA'),
    );
  });
  test('same-session placement uses only verified runtime/caps/model/memory/permission/load and active foreground devices', () {
    final plan = HarnessPlan(planFixture(ns)),
        good = deviceFixture('native', {'compute.audio'}),
        web = deviceFixture('browser', {'compute.digest'}, platform: 'web');
    expect(
      placeTask(session, plan, 'a', [good, web], PlacementRequirement())!.id,
      'browser',
    );
    expect(
      placeTask(session, plan, 'b', [good, web], PlacementRequirement())!.id,
      'native',
    );
    for (final d in [
      deviceFixture('x', {'compute.digest'}, revoked: true),
      deviceFixture('x', {'compute.digest'}, foreground: false),
      deviceFixture('x', {'compute.digest'}, epoch: 0),
      deviceFixture('x', {'compute.digest'}, load: 1),
    ]) {
      expect(
        placeTask(session, plan, 'a', [d], PlacementRequirement()),
        isNull,
      );
    }
    expect(
      placeTask(session, plan, 'a', [
        web,
      ], PlacementRequirement(models: {'b' * 64})),
      isNull,
    );
    expect(
      placeTask(session, plan, 'a', [
        web,
      ], PlacementRequirement(memoryBytes: 1 << 40)),
      isNull,
    );
  });
  test('exact U63 leases preserve browser/native precision; heartbeat monotonic, expiry/cancel/late result fences', () {
    final token = TaskLease(
      sessionId: 'session',
      nodeId: 'a',
      deviceId: 'device',
      planHash: 'a' * 64,
      inputHash: 'b' * 64,
      coordinatorBoot: 'boot',
      fence: BigInt.parse('9007199254740993'),
      cancelEpoch: BigInt.zero,
      untilMs: 1000,
    );
    final copy = taskLeaseFromJson(token.toJson().cast<String, dynamic>());
    expect(copy.fence, token.fence);
    final state = LeaseState(lease: copy),
        beat = state.heartbeat(token, 100, 'boot', 0.5, 500);
    expect(beat.progress, 0.5);
    expect(
      () => beat.heartbeat(token, 200, 'boot', 0.4, 500),
      code('LEASE_PROGRESS_INVALID'),
    );
    expect(
      () => beat.finish(token, 600, 'boot', {'ok': true}),
      code('LEASE_FENCED'),
    );
    expect(
      () => state.finish(token, 100, 'new-boot', {}),
      code('LEASE_FENCED'),
    );
    expect(
      () => state.cancel().finish(token, 100, 'boot', {}),
      code('LEASE_FENCED'),
    );
    final committed = state.finish(token, 100, 'boot', {'ok': true});
    expect(committed.cancel().status, 'committed');
  });
}
