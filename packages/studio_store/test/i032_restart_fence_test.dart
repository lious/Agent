import 'dart:io';

import 'package:studio_document/studio_document.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:studio_harness/testing_fixtures.dart';
import 'package:studio_store/studio_store.dart';
import 'package:test/test.dart';

/// Increment 2.35 official I-032 remainingAcceptance wording
/// 「过期fence不提交」 and 「100重启无重复副作用」 on the already-admitted
/// finishHarnessTask / DocumentRepository reopen bound. An expired
/// lease is LEASE_FENCED and does not insert a candidate receipt.
/// One hundred reopens of a committed step return the same hash and
/// do not add another outbox side effect. This file does not rewrite
/// device_scheduler_test.dart, harness_transactions_test.dart,
/// harness_takeover_test.dart, or the Increment 1.99 / 2.00 I-032
/// suites, and does not invent a new restart product surface or a
/// PlanGraph manual-lock API.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

int readyCount(DocumentRepository repo, SessionRef session) => repo
    .harnessOutbox(session)
    .where((row) => row['kind'] == 'candidate.ready')
    .length;

void main() {
  late Directory dir;
  final ns = Namespace('studio', 'local', 'i032-restart-fence');
  final session = SessionRef(namespace: ns, id: 'session');

  setUp(() {
    dir = Directory.systemTemp.createTempSync('i032-restart-fence-');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('an expired lease is LEASE_FENCED after reopen and does not commit a receipt', () {
    final path = '${dir.path}/db.sqlite';
    var repo = DocumentRepository.open(path, ns);
    late TaskLease token;
    late HarnessPlan plan;
    try {
      repo.create(
        ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'p'),
      );
      plan = HarnessPlan(planFixture(ns));
      repo.registerHarnessPlan(
        session,
        'p',
        plan,
        coordinatorBoot: 'boot',
        nowMs: 0,
      );
      token = repo.claimHarnessTask(
        session,
        plan.hash,
        'a',
        deviceFixture('browser', {'compute.digest'}),
        PlacementRequirement(),
        coordinatorBoot: 'boot',
        nowMs: 0,
        leaseMs: 500,
      );
      expect(token.untilMs, 500);
      expect(repo.harnessStep(session, plan.hash, 'a')!.status, 'running');
      expect(readyCount(repo, session), 0);
    } finally {
      repo.close();
    }

    repo = DocumentRepository.open(path, ns);
    try {
      expect(
        () => repo.finishHarnessTask(
          session,
          token,
          {'ok': true},
          coordinatorBoot: 'boot',
          nowMs: 500,
        ),
        code('LEASE_FENCED'),
      );
      expect(repo.harnessStep(session, plan.hash, 'a')!.status, 'running');
      expect(readyCount(repo, session), 0);
      expect(repo.read('p')!.revision, BigInt.zero);
    } finally {
      repo.close();
    }
  });

  test(
    'one hundred repository restarts do not duplicate a committed side effect',
    () {
      final path = '${dir.path}/db.sqlite';
      var repo = DocumentRepository.open(path, ns);
      late TaskLease token;
      late HarnessPlan plan;
      late String hash;
      const result = {'ok': true};
      try {
        repo.create(
          ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'p'),
        );
        plan = HarnessPlan(planFixture(ns));
        repo.registerHarnessPlan(
          session,
          'p',
          plan,
          coordinatorBoot: 'boot',
          nowMs: 0,
        );
        token = repo.claimHarnessTask(
          session,
          plan.hash,
          'a',
          deviceFixture('browser', {'compute.digest'}),
          PlacementRequirement(),
          coordinatorBoot: 'boot',
          nowMs: 0,
          leaseMs: 500,
        );
        hash = repo.finishHarnessTask(
          session,
          token,
          result,
          coordinatorBoot: 'boot',
          nowMs: 100,
        );
        expect(repo.harnessStep(session, plan.hash, 'a')!.status, 'committed');
        expect(readyCount(repo, session), 1);
      } finally {
        repo.close();
      }

      for (var i = 0; i < 100; i++) {
        repo = DocumentRepository.open(path, ns);
        try {
          final again = repo.finishHarnessTask(
            session,
            token,
            result,
            coordinatorBoot: 'boot',
            nowMs: 100 + i,
          );
          expect(again, hash);
          expect(
            repo.harnessStep(session, plan.hash, 'a')!.status,
            'committed',
          );
          expect(readyCount(repo, session), 1);
          expect(
            () => repo.finishHarnessTask(
              session,
              token,
              {'different': i},
              coordinatorBoot: 'boot',
              nowMs: 100 + i,
            ),
            code('IDEMPOTENCY_CONFLICT'),
          );
          expect(readyCount(repo, session), 1);
          expect(repo.read('p')!.revision, BigInt.zero);
        } finally {
          repo.close();
        }
      }
    },
  );
}
