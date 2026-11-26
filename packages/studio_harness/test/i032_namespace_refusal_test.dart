import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:studio_harness/testing_fixtures.dart';
import 'package:test/test.dart';

/// Increment 2.00 official I-032 remainingAcceptance wording
/// 「越namespace拒绝」 on the already-admitted HarnessPlan inputRef
/// and placeTask session bounds. A plan whose inputRef namespace
/// differs from the plan namespace, or whose plan namespace differs
/// from the placing session, is refused as NAMESPACE_MISMATCH. This
/// file does not rewrite device_scheduler_test.dart,
/// harness_transactions_test.dart, harness_takeover_test.dart, or
/// Increment 1.99 i032_fanout_iteration_limits_test.dart, and does
/// not invent dynamic replan, model-loop execution, or a new
/// planner surface. transactions_test.dart project/document
/// NAMESPACE_MISMATCH is not this wording and is not reused.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  final ns = Namespace('studio', 'local', 'i032-namespace-refusal');

  test(
    'an inputRef outside the plan namespace is refused as NAMESPACE_MISMATCH',
    () {
      final other = Namespace('studio', 'local', 'i032-namespace-other');
      final raw = planFixture(ns);
      raw['nodes'][0]['inputRef']['ns'] = harnessNamespace(other);
      expect(() => HarnessPlan(raw), code('NAMESPACE_MISMATCH'));
      final accepted = HarnessPlan(planFixture(ns));
      expect(accepted.toJson()['ns'], harnessNamespace(ns));
      expect(accepted.node('a')['inputRef']['ns'], harnessNamespace(ns));
    },
  );

  test(
    'placeTask refuses a plan whose namespace is not the session namespace',
    () {
      final other = Namespace('studio', 'local', 'i032-namespace-other');
      final session = SessionRef(namespace: ns, id: 'session');
      final foreign = HarnessPlan(planFixture(other));
      final device = deviceFixture('native', {'compute.digest'});
      expect(
        () =>
            placeTask(session, foreign, 'a', [device], PlacementRequirement()),
        code('NAMESPACE_MISMATCH'),
      );
      final accepted = placeTask(session, HarnessPlan(planFixture(ns)), 'a', [
        device,
      ], PlacementRequirement());
      expect(accepted, isNotNull);
      expect(accepted!.id, 'native');
    },
  );
}
