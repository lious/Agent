import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'dart:convert';

import 'package:studio_store/studio_store.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:test/test.dart';

import 'package:studio_harness/testing_fixtures.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));
void main() {
  test('real SQLite same-session durable DAG dispatch/retry/heartbeat/receipt/cancel/reopen/outbox, project revision isolated', () {
    final dir = Directory.systemTemp.createTempSync('distributed-sql-'),
        ns = Namespace('studio', 'local', 'devices'),
        session = SessionRef(
          namespace: Namespace('studio', 'local', 'devices'),
          id: 'session',
        ),
        plan = HarnessPlan(
          planFixture(Namespace('studio', 'local', 'devices')),
        );
    var repo = DocumentRepository.open('${dir.path}/db', ns);
    try {
      repo.create(
        ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'p'),
      );
      repo.registerHarnessPlan(
        session,
        'p',
        plan,
        coordinatorBoot: 'boot',
        nowMs: 0,
      );
      TaskLease claim(String node, String device, int now) =>
          repo.claimHarnessTask(
            session,
            plan.hash,
            node,
            deviceFixture(device, {
              'compute.digest',
              'compute.audio',
              'compute.reduce',
            }),
            PlacementRequirement(),
            coordinatorBoot: 'boot',
            nowMs: now,
            leaseMs: 500,
          );
      expect(() => claim('c', 'native', 0), code('PLAN_DEPENDENCY_PENDING'));
      final first = claim('a', 'browser', 0);
      repo.heartbeatHarness(
        session,
        first,
        coordinatorBoot: 'boot',
        nowMs: 100,
        progress: 0.5,
        extendMs: 500,
      );
      expect(() => claim('a', 'native', 400), code('LEASE_BUSY'));
      final retry = claim('a', 'native', 600);
      expect(retry.fence, BigInt.two);
      expect(
        () => repo.finishHarnessTask(
          session,
          first,
          {'hash': 'old'},
          coordinatorBoot: 'boot',
          nowMs: 700,
        ),
        code('LEASE_FENCED'),
      );
      final result = {'hash': 'actual-compute-result'},
          hash = repo.finishHarnessTask(
            session,
            retry,
            {'hash': 'actual-compute-result'},
            coordinatorBoot: 'boot',
            nowMs: 700,
          );
      expect(
        repo.finishHarnessTask(
          session,
          retry,
          result,
          coordinatorBoot: 'boot',
          nowMs: 701,
        ),
        hash,
      );
      expect(
        () => repo.finishHarnessTask(
          session,
          retry,
          {'different': true},
          coordinatorBoot: 'boot',
          nowMs: 701,
        ),
        code('IDEMPOTENCY_CONFLICT'),
      );
      final second = claim('b', 'native', 710);
      repo.finishHarnessTask(
        session,
        second,
        {'rms': 0.5},
        coordinatorBoot: 'boot',
        nowMs: 750,
      );
      final reduce = claim('c', 'browser', 800);
      repo.cancelHarnessTask(session, plan.hash, 'c');
      expect(
        () => repo.finishHarnessTask(
          session,
          reduce,
          {'late': true},
          coordinatorBoot: 'boot',
          nowMs: 900,
        ),
        code('LEASE_FENCED'),
      );
      expect(repo.read('p')!.revision, BigInt.zero);
      final events = repo.harnessOutbox(session);
      expect(events.where((e) => e['kind'] == 'candidate.ready'), hasLength(2));
      expect(jsonDecode(events.first['payload_json'] as String), isA<Map>());
      repo.close();
      repo = DocumentRepository.open('${dir.path}/db', ns);
      expect(repo.harnessStep(session, plan.hash, 'a')!.resultHash, hash);
      expect(repo.harnessStep(session, plan.hash, 'c')!.status, 'cancelled');
      expect(
        () => repo.claimHarnessTask(
          session,
          plan.hash,
          'b',
          deviceFixture('native', {'compute.audio'}),
          PlacementRequirement(),
          coordinatorBoot: 'new-boot',
          nowMs: 0,
          leaseMs: 500,
        ),
        code('COORDINATOR_FENCED'),
      );
    } finally {
      repo.close();
      dir.deleteSync(recursive: true);
    }
  });
  test('real SQLite candidate outbox insertion failure rolls back terminal receipt; retry and repeated cancellation are idempotent', () {
    final dir = Directory.systemTemp.createTempSync('harness-rollback-'),
        ns = Namespace('studio', 'local', 'devices'),
        session = SessionRef(
          namespace: Namespace('studio', 'local', 'devices'),
          id: 'session',
        ),
        plan = HarnessPlan(
          planFixture(Namespace('studio', 'local', 'devices')),
        ),
        repo = DocumentRepository.open(
          '${dir.path}/db',
          Namespace('studio', 'local', 'devices'),
        );
    try {
      expect(ns, session.namespace);
      repo.create(
        ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'p'),
      );
      repo.registerHarnessPlan(
        session,
        'p',
        plan,
        coordinatorBoot: 'boot',
        nowMs: 0,
      );
      final token = repo.claimHarnessTask(
            session,
            plan.hash,
            'a',
            deviceFixture('worker', {'compute.digest'}),
            PlacementRequirement(),
            coordinatorBoot: 'boot',
            nowMs: 0,
            leaseMs: 500,
          ),
          injection = sqlite3.open('${dir.path}/db');
      try {
        injection.execute(
          "CREATE TRIGGER reject_candidate BEFORE INSERT ON harness_outbox WHEN NEW.kind='candidate.ready' BEGIN SELECT RAISE(ABORT,'real outbox failure'); END",
        );
        expect(
          () => repo.finishHarnessTask(
            session,
            token,
            {'ok': true},
            coordinatorBoot: 'boot',
            nowMs: 100,
          ),
          throwsA(isA<SqliteException>()),
        );
        expect(repo.harnessStep(session, plan.hash, 'a')!.status, 'running');
        expect(
          repo
              .harnessOutbox(session)
              .where((e) => e['kind'] == 'candidate.ready'),
          isEmpty,
        );
        injection.execute('DROP TRIGGER reject_candidate');
      } finally {
        injection.dispose();
      }
      repo.finishHarnessTask(
        session,
        token,
        {'ok': true},
        coordinatorBoot: 'boot',
        nowMs: 100,
      );
      expect(repo.harnessStep(session, plan.hash, 'a')!.status, 'committed');
      repo.claimHarnessTask(
        session,
        plan.hash,
        'b',
        deviceFixture('other', {'compute.audio'}),
        PlacementRequirement(),
        coordinatorBoot: 'boot',
        nowMs: 200,
        leaseMs: 500,
      );
      repo.cancelHarnessTask(session, plan.hash, 'b');
      final fence = repo.harnessStep(session, plan.hash, 'b')!.lease.fence,
          count = repo.harnessOutbox(session).length;
      repo.cancelHarnessTask(session, plan.hash, 'b');
      expect(repo.harnessStep(session, plan.hash, 'b')!.lease.fence, fence);
      expect(repo.harnessOutbox(session).length, count);
    } finally {
      repo.close();
      dir.deleteSync(recursive: true);
    }
  });
}
