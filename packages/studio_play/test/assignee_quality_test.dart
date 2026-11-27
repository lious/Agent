import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_play/studio_play.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

PlaySession newCrew() {
  final session = PlaySession.crew(
    id: 'crew-assignee',
    namespace: Namespace('studio', 'local', 'play-assignee'),
    hostPersonId: 'ada',
    hostDeviceId: 'host',
  );
  session.addPerson(id: 'ben', label: 'Ben');
  session.addPerson(id: 'cara', label: 'Cara');
  session.addPerson(id: 'pat', label: 'Pat');
  session.addPerson(id: 'wren', label: 'Wren');
  for (final entry in [
    ('ben-phone', 'ben'),
    ('cara-phone', 'cara'),
    ('pat-phone', 'pat'),
    ('wren-desk', 'wren'),
  ]) {
    session.addDevice(
      id: entry.$1,
      personId: entry.$2,
      kind: DeviceKind.privateClient,
      scopes: {TrustScope.public},
    );
  }
  final director = session.acting(
    personId: 'ada',
    deviceId: 'host',
    grantId: 'grant-director',
  );
  session.grantRole(
    by: director,
    id: 'grant-ad',
    personId: 'cara',
    label: 'assistantDirector',
    crewRole: CrewRole.assistantDirector,
  );
  session.grantRole(
    by: director,
    id: 'grant-actor',
    personId: 'ben',
    label: 'performer',
    crewRole: CrewRole.performer,
    characterId: 'hero',
  );
  session.grantRole(
    by: director,
    id: 'grant-other-actor',
    personId: 'pat',
    label: 'performer',
    crewRole: CrewRole.performer,
    characterId: 'rival',
  );
  session.grantRole(
    by: director,
    id: 'grant-empty-writer',
    personId: 'wren',
    label: 'screenwriter',
    crewRole: CrewRole.screenwriter,
  );
  session.commitScriptVersion(
    director,
    id: 'r3',
    scenes: [
      PlayScene(
        id: 'scene-1',
        title: 'Platform',
        body: 'Hero waits.',
        characterIds: ['hero'],
      ),
    ],
    characters: [PlayCharacter(id: 'hero', name: 'Hero')],
    shots: [PlayShot(id: 'shot-1', sceneId: 'scene-1', title: 'Wide')],
  );
  session.lockScript(director, 'r3');
  return session;
}

void main() {
  test('markTechnicalQuality rejects a non-assignee performer; director, AD and the assignee may mark without adopting', () {
    final s = newCrew();
    final director = s.acting(
      personId: 'ada',
      deviceId: 'host',
      grantId: 'grant-director',
    );
    final actor = s.acting(
      personId: 'ben',
      deviceId: 'ben-phone',
      grantId: 'grant-actor',
    );
    final other = s.acting(
      personId: 'pat',
      deviceId: 'pat-phone',
      grantId: 'grant-other-actor',
    );
    final ad = s.acting(
      personId: 'cara',
      deviceId: 'cara-phone',
      grantId: 'grant-ad',
    );
    s.issueTask(
      director,
      id: 'task-1',
      craft: 'actor',
      sceneId: 'scene-1',
      scriptVersionId: 'r3',
    );
    s.claimTask(actor, 'task-1');
    s.submitDelivery(
      actor,
      id: 'take-1',
      taskId: 'task-1',
      kind: DeliveryKind.take,
      body: 'take one',
      source: 'phone',
      authorizationNote: 'performance grant',
    );
    expect(
      () => s.markTechnicalQuality(other, 'take-1', 'pass'),
      code('PLAY_PERMISSION_DENIED'),
    );
    expect(s.deliveries['take-1']!.technicalMark, isNull);
    s.markTechnicalQuality(actor, 'take-1', 'pass');
    expect(s.deliveries['take-1']!.technicalMark, 'pass');
    expect(s.adoptions, isEmpty);
    expect(s.tasks['task-1']!.phase, TaskPhase.submitted);
    s.markTechnicalQuality(ad, 'take-1', 'continuity-ok');
    s.markTechnicalQuality(director, 'take-1', 'reviewed');
    expect(s.deliveries['take-1']!.technicalMark, 'reviewed');
    expect(s.adoptions, isEmpty);
    expect(s.tasks['task-1']!.phase, TaskPhase.submitted);
  });

  test('screenwriter with empty sceneIds cannot issue official tasks for unassigned scenes', () {
    final s = newCrew();
    final writer = s.acting(
      personId: 'wren',
      deviceId: 'wren-desk',
      grantId: 'grant-empty-writer',
    );
    expect(s.grant('grant-empty-writer').sceneIds, isEmpty);
    expect(
      () => s.issueTask(
        writer,
        id: 'task-empty',
        craft: 'actor',
        sceneId: 'scene-1',
        scriptVersionId: 'r3',
      ),
      code('PLAY_PERMISSION_DENIED'),
    );
    expect(s.tasks.containsKey('task-empty'), isFalse);
  });
}
