import 'dart:io';
import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));
void main() {
  test('explicit same-session recovery preserves pins/results and fences old coordinator, no permission restore', () async {
    final root = Directory.systemTemp.createTempSync('metadata-recover-');
    StudioWorkspace open() => StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata'},
      ),
      databasePath: '${root.path}/db',
      tenantId: 't',
      workspaceId: 'w',
    );
    var w = open();
    w.openDemo();
    final original = w.createMetadataComputeSession('durable-session');
    original.enableRecovery('a' * 64);
    final hash = original.plan.hash;
    expect(
      () => w.createMetadataComputeSession(original.id),
      code('COORDINATOR_FENCED'),
    );
    await original.runLocalNode('digest-0');
    expect(w.recoverableMetadataSessions('b' * 64), isEmpty);
    expect(
      () => w.recoverMetadataSession(original.id, hash, 'b' * 64),
      code('RECOVERY_OWNER_MISMATCH'),
    );
    final recovered = w.recoverMetadataSession(original.id, hash, 'a' * 64);
    expect(recovered.id, original.id);
    expect(recovered.plan.hash, hash);
    expect(recovered.peerFingerprint, isNull);
    expect(recovered.isListening, isFalse);
    await expectLater(
      original.runLocalNode('digest-1'),
      code('COORDINATOR_FENCED'),
    );
    expect(
      () => original.grant(
        fingerprint: 'b' * 64,
        deviceId: 'stale',
        nodes: {'digest-0'},
      ),
      code('COORDINATOR_FENCED'),
    );
    await recovered.runLocalNode('digest-1');
    expect(recovered.statuses.values, everyElement('committed'));
    await original.close();
    await recovered.close();
    w.close();
    w = open();
    w.openDemo();
    final afterReopen = w.recoverMetadataSession(
      'durable-session',
      hash,
      'a' * 64,
    );
    expect(afterReopen.statuses.values, everyElement('committed'));
    expect(w.current.revision, BigInt.zero);
    await afterReopen.close();
    w.close();
    root.deleteSync(recursive: true);
  });
  test('stale coordinator cannot renew authority or revoke a recovered owner new grant on close', () async {
    final root = Directory.systemTemp.createTempSync('recovery-admin-fence-');
    final w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata'},
      ),
      databasePath: '${root.path}/db',
      tenantId: 't',
      workspaceId: 'w',
    );
    w.openDemo();
    final old = w.createMetadataComputeSession('admin-scope');
    old.enableRecovery('a' * 64);
    old.grant(fingerprint: 'b' * 64, deviceId: 'worker', nodes: {'digest-0'});
    final next = w.recoverMetadataSession(old.id, old.plan.hash, 'a' * 64);
    final epoch = next.grant(
      fingerprint: 'b' * 64,
      deviceId: 'worker',
      nodes: {'digest-0'},
    );
    expect(
      () => old.invitation(
        endpoint: 'https://127.0.0.1:1',
        certificatePem: 'not used',
        nodes: {'digest-0'},
      ),
      code('COORDINATOR_FENCED'),
    );
    expect(() => old.revoke(), code('COORDINATOR_FENCED'));
    await old.close();
    final db = sqlite3.open('${root.path}/db');
    expect(db.select('SELECT epoch,revoked FROM peer_grants').single, {
      'epoch': epoch,
      'revoked': 0,
    });
    db.dispose();
    await next.close();
    w.close();
    root.deleteSync(recursive: true);
  });
  test(
    'recovery rejects project revision drift rather than applying old work',
    () async {
      final w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata'},
        ),
        databasePath: ':memory:',
        tenantId: 't',
        workspaceId: 'w',
      );
      w.openDemo();
      final c = w.createMetadataComputeSession('pinned');
      c.enableRecovery('a' * 64);
      w.rename('changed', expectedRevision: BigInt.zero);
      expect(
        () => w.recoverMetadataSession(c.id, c.plan.hash, 'a' * 64),
        code('REVISION_CONFLICT'),
      );
      await c.close();
      w.close();
    },
  );
  test('SQL failure rolls back takeover and unknown OS boot exhausts rather than resets wall budget', () async {
    final root = Directory.systemTemp.createTempSync('recovery-fault-');
    final w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata'},
      ),
      databasePath: '${root.path}/db',
      tenantId: 't',
      workspaceId: 'w',
    );
    w.openDemo();
    final c = w.createMetadataComputeSession('fault');
    c.enableRecovery('a' * 64);
    final db = sqlite3.open('${root.path}/db');
    db.execute(
      "CREATE TRIGGER fail_recovery BEFORE UPDATE ON peer_session_recovery BEGIN SELECT RAISE(ABORT,'injected'); END",
    );
    expect(
      () => w.recoverMetadataSession(c.id, c.plan.hash, 'a' * 64),
      throwsA(anything),
    );
    await c.runLocalNode('digest-0'); // old boot was not partially fenced
    db.execute('DROP TRIGGER fail_recovery');
    final row = db.select('SELECT manifest FROM peer_session_recovery').single;
    final manifest =
        jsonDecode(row['manifest'] as String) as Map<String, dynamic>;
    manifest['anchor']['bootId'] = '00000000-0000-0000-0000-000000000000';
    db.execute('UPDATE peer_session_recovery SET manifest=?,hash=?', [
      jsonEncode(manifest),
      contentHash(manifest),
    ]);
    final restored = w.recoverMetadataSession(c.id, c.plan.hash, 'a' * 64);
    await expectLater(
      restored.runLocalNode('digest-1'),
      code('PLAN_WALL_BUDGET_EXHAUSTED'),
    );
    await c.close();
    await restored.close();
    db.dispose();
    w.close();
    root.deleteSync(recursive: true);
  });
  test('fresh session cannot bypass a recovered-device quarantine with another boot', () async {
    final w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata'},
      ),
      databasePath: ':memory:',
      tenantId: 't',
      workspaceId: 'w',
    );
    w.openDemo();
    final old = w.createMetadataComputeSession('old-session');
    old.enableRecovery('a' * 64);
    final oldResult = old
        .runLocalNode('digest-0')
        .then<Object>((v) => v, onError: (Object e) => e);
    final recovered = w.recoverMetadataSession(old.id, old.plan.hash, 'a' * 64);
    final fresh = w.createMetadataComputeSession('fresh-session');
    await expectLater(
      fresh.runLocalNode('digest-0'),
      code('DEVICE_RESOURCE_QUARANTINED'),
    );
    expect(await oldResult, isA<StudioException>());
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await recovered.runLocalNode(
      'digest-1',
    ); // real owner-clock observation releases expired quarantine
    await fresh.runLocalNode('digest-0');
    await old.close();
    await recovered.close();
    await fresh.close();
    w.close();
  });
}
