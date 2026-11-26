import 'dart:io';

import 'package:studio_document/studio_document.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:studio_harness/testing_fixtures.dart';
import 'package:studio_store/studio_store.dart';
import 'package:test/test.dart';

/// Increment 1.98 official I-027 remainingAcceptance wording
/// 「同一项目两个会话作用域隔离」 on the already-admitted
/// DocumentRepository.createSession and registerHarnessPlan paths.
/// Two sessions bound to the same project keep independent titles,
/// harness plans, step records, and coordinator boots. This file does
/// not rewrite transactions_test.dart, harness_transactions_test.dart,
/// or workspace_test.dart, and does not invent SessionStore, branch
/// mapping, tool-call/result pairing, or HTTP-replay fork/resume.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  late Directory dir;
  final ns = Namespace('studio', 'local', 'i027-session-scope');
  final sessionA = SessionRef(namespace: ns, id: 'session-a');
  final sessionB = SessionRef(namespace: ns, id: 'session-b');

  setUp(() {
    dir = Directory.systemTemp.createTempSync('i027-session-scope-');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  DocumentRepository open() =>
      DocumentRepository.open('${dir.path}/db.sqlite', ns);

  HarnessPlan plan() => HarnessPlan(planFixture(ns));

  VerifiedDevice deviceFor(SessionRef session) => VerifiedDevice(
    id: 'device-${session.id}',
    platform: 'linux',
    runtimeHash: 'a' * 64,
    capabilities: {'compute.digest', 'compute.audio', 'compute.reduce'},
    modelHashes: const {},
    sessionIds: {session.id},
    freeMemoryBytes: 1024 * 1024 * 1024,
    load: 0.1,
    permissionEpoch: 1,
  );

  TaskLease claim(
    DocumentRepository repo,
    SessionRef session,
    String planHash,
    String boot, {
    required String node,
    required int nowMs,
  }) => repo.claimHarnessTask(
    session,
    planHash,
    node,
    deviceFor(session),
    PlacementRequirement(),
    coordinatorBoot: boot,
    nowMs: nowMs,
    leaseMs: 500,
  );

  test('two sessions on the same project keep independent titles, plans, and steps', () {
    final repo = open();
    try {
      repo.create(
        ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'p'),
      );
      repo.createSession(sessionA.id, 'Alpha title');
      repo.createSession(sessionB.id, 'Beta title');
      expect(repo.sessionTitle(sessionA.id), 'Alpha title');
      expect(repo.sessionTitle(sessionB.id), 'Beta title');

      final graph = plan();
      repo.registerHarnessPlan(
        sessionA,
        'p',
        graph,
        coordinatorBoot: 'boot-a',
        nowMs: 0,
      );
      repo.registerHarnessPlan(
        sessionB,
        'p',
        graph,
        coordinatorBoot: 'boot-b',
        nowMs: 0,
      );

      expect(
        () => repo.requireHarnessCoordinator(sessionB, graph.hash, 'boot-a'),
        code('COORDINATOR_FENCED'),
      );
      repo.requireHarnessCoordinator(sessionB, graph.hash, 'boot-b');

      final first = claim(
        repo,
        sessionA,
        graph.hash,
        'boot-a',
        node: 'a',
        nowMs: 0,
      );
      repo.finishHarnessTask(
        sessionA,
        first,
        {'hash': 'session-a-result'},
        coordinatorBoot: 'boot-a',
        nowMs: 100,
      );
      expect(repo.harnessStep(sessionA, graph.hash, 'a')?.status, 'committed');
      expect(repo.harnessStep(sessionB, graph.hash, 'a'), isNull);

      final second = claim(
        repo,
        sessionB,
        graph.hash,
        'boot-b',
        node: 'a',
        nowMs: 200,
      );
      expect(
        repo.harnessStep(sessionB, graph.hash, 'a')?.status,
        isNot('committed'),
      );
      repo.finishHarnessTask(
        sessionB,
        second,
        {'hash': 'session-b-result'},
        coordinatorBoot: 'boot-b',
        nowMs: 300,
      );
      expect(repo.harnessStep(sessionA, graph.hash, 'a')?.status, 'committed');
      expect(repo.harnessStep(sessionB, graph.hash, 'a')?.status, 'committed');
      expect(repo.sessionTitle(sessionA.id), 'Alpha title');
      expect(repo.sessionTitle(sessionB.id), 'Beta title');
      expect(repo.read('p')!.revision, BigInt.zero);
      expect(repo.read('p')!.title, 'p');
    } finally {
      repo.close();
    }
  });

  test('reopening the store keeps the two same-project sessions isolated', () {
    var repo = open();
    final graph = plan();
    try {
      repo.create(
        ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'p'),
      );
      repo.createSession(sessionA.id, 'Alpha title');
      repo.createSession(sessionB.id, 'Beta title');
      repo.registerHarnessPlan(
        sessionA,
        'p',
        graph,
        coordinatorBoot: 'boot-a',
        nowMs: 0,
      );
      repo.registerHarnessPlan(
        sessionB,
        'p',
        graph,
        coordinatorBoot: 'boot-b',
        nowMs: 0,
      );
      final first = claim(
        repo,
        sessionA,
        graph.hash,
        'boot-a',
        node: 'a',
        nowMs: 0,
      );
      repo.finishHarnessTask(
        sessionA,
        first,
        {'hash': 'session-a-result'},
        coordinatorBoot: 'boot-a',
        nowMs: 100,
      );
      repo.close();
      repo = open();
      expect(repo.sessionTitle(sessionA.id), 'Alpha title');
      expect(repo.sessionTitle(sessionB.id), 'Beta title');
      expect(repo.harnessStep(sessionA, graph.hash, 'a')?.status, 'committed');
      expect(repo.harnessStep(sessionB, graph.hash, 'a'), isNull);
      expect(
        () => repo.requireHarnessCoordinator(sessionB, graph.hash, 'boot-a'),
        code('COORDINATOR_FENCED'),
      );
      final second = claim(
        repo,
        sessionB,
        graph.hash,
        'boot-b',
        node: 'a',
        nowMs: 200,
      );
      repo.finishHarnessTask(
        sessionB,
        second,
        {'hash': 'session-b-result'},
        coordinatorBoot: 'boot-b',
        nowMs: 300,
      );
      expect(repo.harnessStep(sessionA, graph.hash, 'a')?.status, 'committed');
      expect(repo.harnessStep(sessionB, graph.hash, 'a')?.status, 'committed');
      expect(repo.read('p')!.revision, BigInt.zero);
    } finally {
      repo.close();
    }
  });
}
