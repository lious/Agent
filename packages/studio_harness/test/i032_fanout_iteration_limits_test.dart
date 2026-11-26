import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:studio_harness/testing_fixtures.dart';
import 'package:test/test.dart';

/// Increment 1.99 official I-032 remainingAcceptance wording
/// 「fanout/迭代不越上限」 on the already-admitted HarnessPlan 1.0
/// safe-subset constructor. A plan whose fan-out exceeds `maxFanout`,
/// or whose `maxFanout` / `maxModelIterations` / `maxNodes` limits are
/// outside the admitted bounds, is refused. This file does not rewrite
/// device_scheduler_test.dart, harness_transactions_test.dart, or
/// harness_takeover_test.dart, and does not invent dynamic replan,
/// model-loop execution, or a new planner surface.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  final ns = Namespace('studio', 'local', 'i032-fanout-limits');

  Map<String, dynamic> rawPlan() =>
      jsonDecode(jsonEncode(planFixture(ns))) as Map<String, dynamic>;

  Map<String, dynamic> withExtraDependentOnA(
    Map<String, dynamic> raw, {
    required int maxFanout,
  }) {
    final plan = Map<String, dynamic>.from(raw);
    final nodes = (plan['nodes'] as List)
        .map((n) => Map<String, dynamic>.from(n as Map))
        .toList();
    final extra = Map<String, dynamic>.from(nodes.first);
    extra['id'] = 'd';
    extra['deps'] = ['a'];
    extra['inputRef'] = Map<String, dynamic>.from(extra['inputRef'] as Map);
    extra['inputRef']['id'] = 'input-d';
    extra['handlerPin'] = Map<String, dynamic>.from(extra['handlerPin'] as Map);
    extra['handlerPin']['id'] = 'fixture.d';
    extra['handlerPin']['hash'] = harnessHash({
      'handler': 'd',
      'version': '1.0.0',
    });
    nodes.add(extra);
    plan['nodes'] = nodes;
    plan['limits'] = Map<String, dynamic>.from(plan['limits'] as Map);
    plan['limits']['maxFanout'] = maxFanout;
    return plan;
  }

  test(
    'a node with more dependents than maxFanout is refused as PLAN_FANOUT',
    () {
      final over = withExtraDependentOnA(rawPlan(), maxFanout: 1);
      expect(() => HarnessPlan(over), code('PLAN_FANOUT'));
      final allowed = HarnessPlan(
        withExtraDependentOnA(rawPlan(), maxFanout: 2),
      );
      expect(allowed.node('d')['deps'], ['a']);
      expect(allowed.toJson()['limits']['maxFanout'], 2);
    },
  );

  test('maxModelIterations outside 1..64 is refused as PLAN_LIMIT', () {
    for (final iterations in [0, 65]) {
      final raw = rawPlan();
      raw['limits']['maxModelIterations'] = iterations;
      expect(() => HarnessPlan(raw), code('PLAN_LIMIT'));
    }
    for (final iterations in [1, 64]) {
      final raw = rawPlan();
      raw['limits']['maxModelIterations'] = iterations;
      expect(
        HarnessPlan(raw).toJson()['limits']['maxModelIterations'],
        iterations,
      );
    }
  });

  test('maxFanout and maxNodes cannot be set outside the admitted bound', () {
    for (final fanout in [0, 9]) {
      final raw = rawPlan();
      raw['limits']['maxFanout'] = fanout;
      expect(() => HarnessPlan(raw), code('PLAN_LIMIT'));
    }
    final tooFewNodes = rawPlan();
    tooFewNodes['limits']['maxNodes'] = 2;
    expect(() => HarnessPlan(tooFewNodes), code('PLAN_LIMIT'));
    final atBound = rawPlan();
    atBound['limits']['maxFanout'] = 1;
    atBound['limits']['maxNodes'] = 3;
    expect(HarnessPlan(atBound).toJson()['limits']['maxFanout'], 1);
    expect(HarnessPlan(atBound).toJson()['limits']['maxNodes'], 3);
  });
}
