import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_play/studio_play.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

PlaySession newCrew() {
  final session = PlaySession.crew(
    id: 'crew-session',
    namespace: Namespace('studio', 'local', 'play-crew'),
    hostPersonId: 'ada',
    hostDeviceId: 'host',
  );
  session.addPerson(id: 'ben', label: 'Ben');
  session.addPerson(id: 'cara', label: 'Cara');
  session.addPerson(id: 'ed', label: 'Ed');
  session.addPerson(id: 'bot', label: 'Assistant', kind: PersonKind.assistant);
  session.addDevice(
    id: 'ben-phone',
    personId: 'ben',
    kind: DeviceKind.privateClient,
    scopes: {TrustScope.public},
  );
  session.addDevice(
    id: 'cara-phone',
    personId: 'cara',
    kind: DeviceKind.privateClient,
    scopes: {TrustScope.public},
  );
  session.addDevice(
    id: 'ed-desk',
    personId: 'ed',
    kind: DeviceKind.privateClient,
    scopes: {TrustScope.public, TrustScope.crewConfidential},
  );
  session.addDevice(
    id: 'bot-box',
    personId: 'bot',
    kind: DeviceKind.privateClient,
    scopes: {TrustScope.public},
  );
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
    id: 'grant-writer',
    personId: 'cara',
    label: 'screenwriter',
    crewRole: CrewRole.screenwriter,
    sceneIds: {'scene-1'},
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
    id: 'grant-editor',
    personId: 'ed',
    label: 'editor',
    crewRole: CrewRole.editor,
    departments: {'editorial'},
    lead: true,
  );
  session.grantRole(
    by: director,
    id: 'grant-bot',
    personId: 'bot',
    label: 'assistant',
    crewRole: CrewRole.performer,
  );
  return session;
}

List<PlayScene> scenes() => [
  PlayScene(
    id: 'scene-1',
    title: 'Platform',
    body: 'Hero waits for the last train. Hidden motive stays off sides of extras.',
    characterIds: ['hero'],
  ),
  PlayScene(
    id: 'scene-2',
    title: 'Office',
    body: 'A secret clause is read in the office. Extra is not here.',
    characterIds: ['rival'],
  ),
];

List<PlayCharacter> characters() => [
  PlayCharacter(id: 'hero', name: 'Hero', bible: {'motive': 'cite:scene-1'}),
  PlayCharacter(id: 'rival', name: 'Rival', bible: {'motive': 'cite:scene-2'}),
];

List<PlayShot> shots() => [
  PlayShot(id: 'shot-1', sceneId: 'scene-1', title: 'Wide'),
  PlayShot(id: 'shot-2', sceneId: 'scene-2', title: 'Insert'),
];

void main() {
  test('lock is immutable, non-directors and assistants cannot lock', () {
    final s = newCrew();
    final director = s.acting(
      personId: 'ada',
      deviceId: 'host',
      grantId: 'grant-director',
    );
    final ad = s.acting(
      personId: 'cara',
      deviceId: 'cara-phone',
      grantId: 'grant-ad',
    );
    final bot = s.acting(
      personId: 'bot',
      deviceId: 'bot-box',
      grantId: 'grant-bot',
    );
    s.commitScriptVersion(
      director,
      id: 'r3',
      scenes: scenes(),
      characters: characters(),
      shots: shots(),
    );
    expect(() => s.lockScript(ad, 'r3'), code('PLAY_PERMISSION_DENIED'));
    expect(() => s.lockScript(bot, 'r3'), code('PLAY_AI_FORBIDDEN'));
    s.lockScript(director, 'r3');
    expect(s.scripts.single.locked, isTrue);
    expect(() => s.mutateScript(director, 'r3'), code('PLAY_SCRIPT_LOCKED'));
    s.commitScriptVersion(
      director,
      id: 'r4',
      scenes: scenes(),
      characters: characters(),
      shots: shots(),
    );
    expect(s.scripts.firstWhere((v) => v.id == 'r3').locked, isTrue);
    expect(s.scripts.firstWhere((v) => v.id == 'r4').locked, isFalse);
  });

  test('issue, claim, take, review and writer-accept; self-approval and CAS fail closed', () {
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
    final writer = s.acting(
      personId: 'cara',
      deviceId: 'cara-phone',
      grantId: 'grant-writer',
    );
    s.commitScriptVersion(
      director,
      id: 'r3',
      scenes: scenes(),
      characters: characters(),
      shots: shots(),
    );
    s.lockScript(director, 'r3');
    s.issueTask(
      director,
      id: 'task-1',
      craft: 'actor',
      sceneId: 'scene-1',
      scriptVersionId: 'r3',
      assigneePersonId: 'ben',
    );
    expect(
      () => s.issueTask(
        writer,
        id: 'task-out',
        craft: 'actor',
        sceneId: 'scene-2',
        scriptVersionId: 'r3',
      ),
      code('PLAY_PERMISSION_DENIED'),
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
    s.submitDelivery(
      actor,
      id: 'take-2',
      taskId: 'task-1',
      kind: DeliveryKind.take,
      body: 'take two',
      source: 'phone',
      authorizationNote: 'performance grant',
      supersedesId: null,
    );
    expect(s.deliveries['take-1'], isNotNull);
    expect(s.deliveries['take-2']!.contentHash, isNotEmpty);
    final tech = s.acting(
      personId: 'cara',
      deviceId: 'cara-phone',
      grantId: 'grant-ad',
    );
    s.markTechnicalQuality(tech, 'take-2', 'pass');
    expect(
      () => s.writerAccept(director, 'take-2', expectedRevision: 0),
      code('PLAY_TASK_STATE'),
    );
    s.adoptDelivery(director, 'take-2');
    s.writerAccept(director, 'take-2', expectedRevision: 0);
    expect(s.projectRevision, 1);
    expect(s.tasks['task-1']!.phase, TaskPhase.accepted);
    s.issueTask(
      director,
      id: 'task-2',
      craft: 'actor',
      sceneId: 'scene-1',
      scriptVersionId: 'r3',
    );
    s.claimTask(actor, 'task-2');
    s.submitDelivery(
      actor,
      id: 'take-3',
      taskId: 'task-2',
      kind: DeliveryKind.take,
      body: 'later',
      source: 'phone',
      authorizationNote: 'performance grant',
    );
    s.adoptDelivery(director, 'take-3');
    expect(
      () => s.writerAccept(director, 'take-3', expectedRevision: 0),
      code('PLAY_STALE_REVISION'),
    );
    expect(s.tasks['task-1']!.phase, TaskPhase.accepted);
    expect(s.tasks['task-2']!.phase, TaskPhase.reviewed);
    s.writerAccept(director, 'take-3', expectedRevision: 1);
    expect(s.projectRevision, 2);
  });

  test('cannot self-approve, requests cannot bypass issue, revoke blocks later claims', () {
    final s = newCrew();
    s.addPerson(id: 'ada-actor', label: 'Ada acting');
    // Same person as director cannot be used; add a second grant on ada? Use ada as actor on host.
    // Director person also performing: grant a performer role to ada.
    final director = s.acting(
      personId: 'ada',
      deviceId: 'host',
      grantId: 'grant-director',
    );
    s.grantRole(
      by: director,
      id: 'grant-ada-actor',
      personId: 'ada',
      label: 'performer',
      crewRole: CrewRole.performer,
      characterId: 'hero',
    );
    s.commitScriptVersion(
      director,
      id: 'r3',
      scenes: scenes(),
      characters: characters(),
      shots: shots(),
    );
    s.lockScript(director, 'r3');
    s.issueTask(
      director,
      id: 'task-self',
      craft: 'actor',
      sceneId: 'scene-1',
      scriptVersionId: 'r3',
    );
    final asActor = s.acting(
      personId: 'ada',
      deviceId: 'host',
      grantId: 'grant-ada-actor',
    );
    s.claimTask(asActor, 'task-self');
    s.submitDelivery(
      asActor,
      id: 'take-self',
      taskId: 'task-self',
      kind: DeliveryKind.take,
      body: 'self',
      source: 'host',
      authorizationNote: 'self take',
    );
    expect(
      () => s.adoptDelivery(director, 'take-self'),
      code('PLAY_SELF_APPROVAL'),
    );

    final actor = s.acting(
      personId: 'ben',
      deviceId: 'ben-phone',
      grantId: 'grant-actor',
    );
    s.raiseRequest(
      actor,
      id: 'req-1',
      craft: 'actor',
      sceneId: 'scene-1',
      scriptVersionId: 'r3',
    );
    expect(() => s.claimTask(actor, 'req-1'), code('PLAY_PERMISSION_DENIED'));
    s.approveRequest(director, 'req-1');
    s.claimTask(actor, 'req-1');

    s.revoke(director, 'grant-actor');
    expect(() => s.claimTask(actor, 'req-1'), code('PLAY_ROLE_REVOKED'));
    expect(
      () => s.view(
        personId: 'ben',
        deviceId: 'ben-phone',
        grantId: 'grant-actor',
      ),
      code('PLAY_ROLE_REVOKED'),
    );
  });

  test(
    'actors see sides not the full script; bible cites the source version',
    () {
      final s = newCrew();
      final director = s.acting(
        personId: 'ada',
        deviceId: 'host',
        grantId: 'grant-director',
      );
      s.commitScriptVersion(
        director,
        id: 'r3',
        scenes: scenes(),
        characters: characters(),
        shots: shots(),
      );
      s.lockScript(director, 'r3');
      final pack = s.deriveWorkPackage('r3');
      expect(pack.bible['hero']!['sourceVersion'], 'r3');
      expect(pack.sides['hero']!, contains('scene-1'));
      expect(pack.sides['hero']!, isNot(contains('secret clause')));
      final actorView = s.view(
        personId: 'ben',
        deviceId: 'ben-phone',
        grantId: 'grant-actor',
      );
      expect(actorView.containsText('last train'), isTrue);
      expect(actorView.containsText('secret clause'), isFalse);
      expect(actorView.documents.any((d) => d.title == 'full-script'), isFalse);
      final directorView = s.view(
        personId: 'ada',
        deviceId: 'host',
        grantId: 'grant-director',
      );
      expect(directorView.containsText('secret clause'), isTrue);
    },
  );

  test('offline adoption is a draft opinion; stale script cannot auto-accept; history is kept', () {
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
    s.commitScriptVersion(
      director,
      id: 'r3',
      scenes: scenes(),
      characters: characters(),
      shots: shots(),
    );
    s.lockScript(director, 'r3');
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
      body: 'one',
      source: 'phone',
      authorizationNote: 'ok',
    );
    s.setOnline('host', false);
    final opinion = s.adoptDelivery(director, 'take-1');
    expect(opinion.draft, isTrue);
    expect(s.adoptions, isEmpty);
    expect(
      () => s.writerAccept(director, 'take-1', expectedRevision: 0),
      code('PLAY_TASK_STATE'),
    );
    s.setOnline('host', true);
    s.adoptDelivery(director, 'take-1');
    s.commitScriptVersion(
      director,
      id: 'r4',
      scenes: scenes(),
      characters: characters(),
      shots: shots(),
    );
    s.lockScript(director, 'r4');
    expect(s.tasks['task-1']!.needsReview, isTrue);
    expect(
      () => s.writerAccept(director, 'take-1', expectedRevision: 0),
      code('PLAY_STALE_REVISION'),
    );
    s.cancelTask(director, 'task-1');
    expect(s.tasks['task-1']!.history, contains(contains('claimed')));
    expect(s.tasks['task-1']!.history, contains(contains('cancelled')));
  });

  test('assistants cannot grant roles; play actions are unsupported as edit proposals', () {
    final s = newCrew();
    final bot = s.acting(
      personId: 'bot',
      deviceId: 'bot-box',
      grantId: 'grant-bot',
    );
    expect(
      () => s.grantRole(
        by: bot,
        id: 'grant-x',
        personId: 'ben',
        label: 'performer',
        crewRole: CrewRole.performer,
      ),
      code('PLAY_AI_FORBIDDEN'),
    );
    expect(
      () => rejectPlayActionAsEditProposal('lockScript'),
      code('PLAY_UNSUPPORTED_PROPOSAL'),
    );
    expect(
      () => rejectPlayActionAsEditProposal('acceptTake'),
      code('PLAY_UNSUPPORTED_PROPOSAL'),
    );
    expect(
      () => rejectPlayActionAsEditProposal('transitionAct'),
      code('PLAY_UNSUPPORTED_PROPOSAL'),
    );
    expect(
      () => rejectPlayActionAsEditProposal('setMarkers'),
      code('PLAY_UNSUPPORTED_PROPOSAL'),
    );
  });
}
