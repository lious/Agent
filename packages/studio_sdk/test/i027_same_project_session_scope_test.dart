import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

/// Increment 1.98 official I-027 remainingAcceptance wording
/// 「同一项目两个会话作用域隔离」 on the already-admitted
/// StudioWorkspace.createMetadataComputeSession path. Two metadata
/// compute sessions on the same open project keep independent plan
/// identities and node statuses; running one does not commit the
/// other. This file does not rewrite workspace_test.dart,
/// peer_recovery_test.dart, or harness_transactions_test.dart, and
/// does not invent SessionStore, branch mapping, tool-call/result
/// pairing, or HTTP-replay fork/resume.
void main() {
  test(
    'two metadata compute sessions on the same project keep isolated statuses',
    () async {
      final dir = Directory.systemTemp.createTempSync('i027-session-scope-');
      final workspace = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata'},
        ),
        databasePath: '${dir.path}/db.sqlite',
        tenantId: 'local',
        workspaceId: 'i027-session-scope',
      );
      workspace.openDemo();
      final first = workspace.createMetadataComputeSession('session-a');
      final second = workspace.createMetadataComputeSession('session-b');
      try {
        expect(first.id, 'session-a');
        expect(second.id, 'session-b');
        expect(first.projectId, workspace.projectId);
        expect(second.projectId, workspace.projectId);
        expect(first.plan.hash, isNot(second.plan.hash));
        expect(first.statuses['digest-0'], 'pending');
        expect(second.statuses['digest-0'], 'pending');
        await first.runLocalNode('digest-0');
        expect(first.statuses['digest-0'], 'committed');
        expect(second.statuses['digest-0'], 'pending');
        expect(second.statuses['digest-1'], 'pending');
        await second.runLocalNode('digest-0');
        expect(second.statuses['digest-0'], 'committed');
        expect(first.statuses['digest-0'], 'committed');
        expect(first.statuses['digest-1'], 'pending');
        expect(second.statuses['digest-1'], 'pending');
        expect(workspace.current.revision, BigInt.zero);
      } finally {
        await first.close();
        await second.close();
        workspace.close();
        dir.deleteSync(recursive: true);
      }
    },
  );
}
