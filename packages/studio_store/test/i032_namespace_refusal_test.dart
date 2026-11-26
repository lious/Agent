import 'dart:io';

import 'package:studio_document/studio_document.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:studio_harness/testing_fixtures.dart';
import 'package:studio_store/studio_store.dart';
import 'package:test/test.dart';

/// Increment 2.00 official I-032 remainingAcceptance wording
/// 「越namespace拒绝」 on the already-admitted registerHarnessPlan
/// bound. A plan whose namespace is not the repository harness
/// namespace is refused as NAMESPACE_MISMATCH even when the session
/// itself is in scope. This file does not rewrite
/// harness_transactions_test.dart, transactions_test.dart,
/// workspace_test.dart, peer_recovery_test.dart, the Increment 1.98
/// I-027 files, or Increment 1.99 i032_fanout_iteration_limits_test.dart,
/// and does not invent a new planner surface.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  late Directory dir;
  final ns = Namespace('studio', 'local', 'i032-namespace-refusal');
  final other = Namespace('studio', 'local', 'i032-namespace-other');
  final session = SessionRef(namespace: ns, id: 'session');

  setUp(() {
    dir = Directory.systemTemp.createTempSync('i032-namespace-refusal-');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test(
    'registerHarnessPlan refuses a plan outside the repository namespace',
    () {
      final repo = DocumentRepository.open('${dir.path}/db.sqlite', ns);
      try {
        repo.create(
          ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'p'),
        );
        expect(
          () => repo.registerHarnessPlan(
            session,
            'p',
            HarnessPlan(planFixture(other)),
            coordinatorBoot: 'boot',
            nowMs: 0,
          ),
          code('NAMESPACE_MISMATCH'),
        );
        final accepted = HarnessPlan(planFixture(ns));
        repo.registerHarnessPlan(
          session,
          'p',
          accepted,
          coordinatorBoot: 'boot',
          nowMs: 0,
        );
        repo.requireHarnessCoordinator(session, accepted.hash, 'boot');
      } finally {
        repo.close();
      }
    },
  );
}
