import 'dart:io';

import 'package:studio_store/studio_store.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:studio_harness/testing_fixtures.dart';
import 'package:test/test.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));
void main() {
  late Directory dir;
  late DocumentRepository repo;
  final ns = Namespace('studio', 'local', 'devices'),
      session = SessionRef(
        namespace: Namespace('studio', 'local', 'devices'),
        id: 'session',
      );
  late HarnessPlan plan;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('coordinator-owner-');
    repo = DocumentRepository.open('${dir.path}/db', ns);
    repo.create(
      ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'p'),
    );
    plan = HarnessPlan(planFixture(ns));
    repo.registerHarnessPlan(
      session,
      'p',
      plan,
      coordinatorBoot: 'old',
      nowMs: 0,
    );
  });
  tearDown(() {
    repo.close();
    dir.deleteSync(recursive: true);
  });
  TaskLease claim(String boot, String device, int now) => repo.claimHarnessTask(
    session,
    plan.hash,
    'a',
    deviceFixture(device, {'compute.digest'}),
    PlacementRequirement(),
    coordinatorBoot: boot,
    nowMs: now,
    leaseMs: 500,
  );
  test('actual reopen requires local CAS authority; takeover fences old process, preserves attempt/fence and quarantines old device', () {
    final token = claim('old', 'alpha', 100);
    repo.close();
    repo = DocumentRepository.open('${dir.path}/db', ns);
    expect(() => claim('new', 'beta', 0), code('COORDINATOR_FENCED'));
    repo.takeoverHarnessPlan(
      session,
      plan.hash,
      expectedBoot: 'old',
      newBoot: 'new',
      operationId: 'owner-1',
      unobservedElapsedUpperBoundMs: 200,
    );
    expect(
      () => repo.finishHarnessTask(
        session,
        token,
        {},
        coordinatorBoot: 'old',
        nowMs: 200,
      ),
      code('LEASE_FENCED'),
    );
    expect(() => claim('new', 'alpha', 0), code('DEVICE_RESOURCE_QUARANTINED'));
    final second = claim('new', 'beta', 0);
    expect(second.fence, BigInt.two);
    expect(
      () => repo.finishHarnessTask(
        session,
        token,
        {},
        coordinatorBoot: 'new',
        nowMs: 0,
      ),
      code('LEASE_FENCED'),
    );
    repo.finishHarnessTask(
      session,
      second,
      {'ok': true},
      coordinatorBoot: 'new',
      nowMs: 100,
    );
    expect(repo.read('p')!.revision, BigInt.zero);
  });
  test('takeover receipt persists and is idempotent, conflicts reject, old boot identifiers cannot be reused', () {
    claim('old', 'alpha', 100);
    void takeover() => repo.takeoverHarnessPlan(
      session,
      plan.hash,
      expectedBoot: 'old',
      newBoot: 'new',
      operationId: 'owner',
      unobservedElapsedUpperBoundMs: 200,
    );
    takeover();
    repo.close();
    repo = DocumentRepository.open('${dir.path}/db', ns);
    takeover();
    expect(
      () => repo.takeoverHarnessPlan(
        session,
        plan.hash,
        expectedBoot: 'old',
        newBoot: 'else',
        operationId: 'owner',
        unobservedElapsedUpperBoundMs: 200,
      ),
      code('IDEMPOTENCY_CONFLICT'),
    );
    expect(
      () => repo.takeoverHarnessPlan(
        session,
        plan.hash,
        expectedBoot: 'new',
        newBoot: 'old',
        operationId: 'aba',
        unobservedElapsedUpperBoundMs: 200,
      ),
      code('COORDINATOR_BOOT_REUSE'),
    );
    expect(
      () => repo.takeoverHarnessPlan(
        session,
        plan.hash,
        expectedBoot: 'old',
        newBoot: 'third',
        operationId: 'stale',
        unobservedElapsedUpperBoundMs: 200,
      ),
      code('COORDINATOR_FENCED'),
    );
  });
  test('unknown downtime consumes wall budget rather than resetting it; measured charge bounds execution', () {
    claim('old', 'alpha', 100);
    repo.takeoverHarnessPlan(
      session,
      plan.hash,
      expectedBoot: 'old',
      newBoot: 'new',
      operationId: 'unknown',
    );
    expect(() => claim('new', 'beta', 0), code('PLAN_WALL_BUDGET_EXHAUSTED'));
  });
  test(
    'known downtime and subsequent ticks cannot escape original wall budget',
    () {
      claim('old', 'alpha', 100);
      repo.takeoverHarnessPlan(
        session,
        plan.hash,
        expectedBoot: 'old',
        newBoot: 'new',
        operationId: 'bounded',
        unobservedElapsedUpperBoundMs: 9800,
      );
      final t = claim('new', 'beta', 0);
      expect(t.untilMs, 100);
      expect(
        () => repo.finishHarnessTask(
          session,
          t,
          {},
          coordinatorBoot: 'new',
          nowMs: 100,
        ),
        code('LEASE_FENCED'),
      );
      expect(
        () => claim('new', 'gamma', 100),
        code('PLAN_WALL_BUDGET_EXHAUSTED'),
      );
    },
  );
  test('old-device quarantine survives another restart after its step was reassigned', () {
    claim('old', 'alpha', 100);
    repo.takeoverHarnessPlan(
      session,
      plan.hash,
      expectedBoot: 'old',
      newBoot: 'new',
      operationId: 'first',
      unobservedElapsedUpperBoundMs: 0,
    );
    claim('new', 'beta', 0); // overwrites the per-node old-alpha lease row
    repo.takeoverHarnessPlan(
      session,
      plan.hash,
      expectedBoot: 'new',
      newBoot: 'third',
      operationId: 'second',
      unobservedElapsedUpperBoundMs: 0,
    );
    expect(
      () => claim('third', 'alpha', 0),
      code('DEVICE_RESOURCE_QUARANTINED'),
    );
    final third = claim('third', 'gamma', 0);
    expect(third.fence, BigInt.from(3));
  });
  test(
    'persistent per-attempt timeout cannot be extended by repeated heartbeats',
    () {
      final t = claim('old', 'alpha', 0);
      repo.heartbeatHarness(
        session,
        t,
        coordinatorBoot: 'old',
        nowMs: 100,
        progress: 0.1,
        extendMs: 900,
      );
      repo.close();
      repo = DocumentRepository.open('${dir.path}/db', ns);
      expect(
        () => repo.heartbeatHarness(
          session,
          t,
          coordinatorBoot: 'old',
          nowMs: 900,
          progress: 0.2,
          extendMs: 900,
        ),
        code('TASK_ATTEMPT_TIMEOUT'),
      );
      expect(repo.harnessStep(session, plan.hash, 'a')!.lease.untilMs, 1000);
      expect(
        () => repo.finishHarnessTask(
          session,
          t,
          {},
          coordinatorBoot: 'old',
          nowMs: 1000,
        ),
        code('LEASE_FENCED'),
      );
    },
  );
}
