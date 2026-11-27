import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:studio_harness/testing_fixtures.dart';
import 'package:studio_play/studio_play.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

void main() {
  test('human creative claims and device leases are separate layers', () {
    final s = PlaySession.crew(
      id: 'sched-session',
      namespace: Namespace('studio', 'local', 'play-sched'),
      hostPersonId: 'ada',
      hostDeviceId: 'host',
    );
    s.addPerson(id: 'ben', label: 'Ben');
    s.addDevice(
      id: 'ben-phone',
      personId: 'ben',
      kind: DeviceKind.privateClient,
      scopes: {TrustScope.public},
    );
    s.addDevice(
      id: 'spare',
      personId: 'ada',
      kind: DeviceKind.compute,
      scopes: {TrustScope.public},
      canCompute: true,
    );
    final director = s.acting(
      personId: 'ada',
      deviceId: 'host',
      grantId: 'grant-director',
    );
    s.grantRole(
      by: director,
      id: 'grant-actor',
      personId: 'ben',
      label: 'performer',
      crewRole: CrewRole.performer,
      characterId: 'hero',
    );
    s.commitScriptVersion(
      director,
      id: 'r1',
      scenes: [
        PlayScene(
          id: 'scene-1',
          title: 'One',
          body: 'Hello',
          characterIds: ['hero'],
        ),
      ],
      characters: [PlayCharacter(id: 'hero', name: 'Hero')],
      shots: [PlayShot(id: 'shot-1', sceneId: 'scene-1', title: 'Wide')],
    );
    s.lockScript(director, 'r1');
    s.issueTask(
      director,
      id: 'task-1',
      craft: 'actor',
      sceneId: 'scene-1',
      scriptVersionId: 'r1',
    );
    final actor = s.acting(
      personId: 'ben',
      deviceId: 'ben-phone',
      grantId: 'grant-actor',
    );
    s.claimTask(actor, 'task-1');
    expect(s.compute.leases, isEmpty);
    expect(s.tasks['task-1']!.phase, TaskPhase.claimed);

    final intent = PlayComputeIntent(
      id: 'hash-1',
      inputs: [
        PlayInput(
          id: 'stem',
          scope: TrustScope.public,
          label: 'stem',
          payload: 'wave',
        ),
      ],
    );
    final lease = s.compute.claimLease(intent, deviceId: 'spare', nowMs: 0);
    expect(lease.deviceId, 'spare');
    expect(lease.sessionId, 'sched-session');
    expect(s.tasks['task-1']!.phase, TaskPhase.claimed);
    expect(s.compute.leases['hash-1'], isNotNull);
    final candidate = s.compute.submitCandidate(
      intent: intent,
      lease: lease,
      body: 'hash-ok',
    );
    expect(candidate.acceptedIntoProject, isFalse);
    expect(s.projectRevision, 0);
  });

  test('devices may only claim authorized compute; online is not enough; no device waits', () {
    final s = PlaySession.mystery(
      id: 'sched-mystery',
      namespace: Namespace('studio', 'local', 'play-sched-m'),
      hostPersonId: 'gm',
      hostDeviceId: 'notebook',
    );
    s.addDevice(id: 'tv', personId: 'gm', kind: DeviceKind.publicScreen);
    s.addDevice(
      id: 'spare',
      personId: 'gm',
      kind: DeviceKind.compute,
      scopes: {TrustScope.public},
      canCompute: true,
    );
    final publicIntent = PlayComputeIntent(
      id: 'pub-1',
      inputs: [PlayInput(id: 'rain', scope: TrustScope.public, label: 'rain')],
    );
    expect(
      () => s.compute.claimLease(publicIntent, deviceId: 'tv', nowMs: 0),
      code('PLAY_DEVICE_TRUST'),
    );
    s.setOnline('spare', false);
    expect(
      () => s.compute.claimLease(publicIntent, deviceId: 'spare', nowMs: 0),
      code('PLAY_DEVICE_TRUST'),
    );
    s.setOnline('spare', true);
    s.compute.claimLease(publicIntent, deviceId: 'spare', nowMs: 0);

    final secret = PlayComputeIntent(
      id: 'secret-1',
      inputs: [
        PlayInput(
          id: 'truth',
          scope: TrustScope.mysteryTruth,
          label: 'truth',
          payload: 'hidden',
        ),
      ],
    );
    expect(s.compute.eligibleDevices(secret), isEmpty);
    expect(s.compute.chooseDevice(secret)?.id, 'notebook');
    expect(
      () => s.compute.claimLease(secret, deviceId: 'spare', nowMs: 1),
      code('PLAY_PRIVATE_INPUT'),
    );
    s.setOnline('notebook', false);
    expect(s.compute.chooseDevice(secret), isNull);

    final ns = Namespace('studio', 'local', 'play-sched-m');
    final placed = placeTask(
      SessionRef(namespace: ns, id: 'session'),
      HarnessPlan(planFixture(ns)),
      'a',
      [
        deviceFixture('spare', {'compute.digest'}),
      ],
      PlacementRequirement(),
    );
    expect(placed?.id, 'spare');
  });

  test('joining a session or receiving a candidate is not library access or writer accept', () {
    final s = PlaySession.crew(
      id: 'join-session',
      namespace: Namespace('studio', 'local', 'play-join'),
      hostPersonId: 'ada',
      hostDeviceId: 'host',
    );
    s.addPerson(id: 'guest', label: 'Guest');
    s.addDevice(
      id: 'guest-phone',
      personId: 'guest',
      kind: DeviceKind.privateClient,
      scopes: {TrustScope.public},
    );
    final director = s.acting(
      personId: 'ada',
      deviceId: 'host',
      grantId: 'grant-director',
    );
    s.commitScriptVersion(
      director,
      id: 'r1',
      scenes: [
        PlayScene(
          id: 'scene-1',
          title: 'One',
          body: 'Confidential draft',
          characterIds: ['hero'],
        ),
      ],
      characters: [PlayCharacter(id: 'hero', name: 'Hero')],
      shots: [PlayShot(id: 'shot-1', sceneId: 'scene-1', title: 'Wide')],
    );
    s.lockScript(director, 'r1');
    expect(
      () => s.view(
        personId: 'guest',
        deviceId: 'guest-phone',
        grantId: 'grant-director',
      ),
      code('PLAY_PERMISSION_DENIED'),
    );
    expect(s.persons.containsKey('guest'), isTrue);
    expect(s.projectRevision, 0);
  });
}
