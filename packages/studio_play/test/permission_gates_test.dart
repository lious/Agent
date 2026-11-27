import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_play/studio_play.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

PlaySession newCrew() {
  final session = PlaySession.crew(
    id: 'crew-gates',
    namespace: Namespace('studio', 'local', 'play-gates'),
    hostPersonId: 'ada',
    hostDeviceId: 'host',
  );
  session.addPerson(id: 'ben', label: 'Ben');
  session.addPerson(id: 'cara', label: 'Cara');
  session.addPerson(id: 'ed', label: 'Ed');
  session.addPerson(id: 'pat', label: 'Pat');
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
    id: 'pat-phone',
    personId: 'pat',
    kind: DeviceKind.privateClient,
    scopes: {TrustScope.public},
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
    id: 'grant-lead',
    personId: 'pat',
    label: 'lead-performer',
    crewRole: CrewRole.performer,
    lead: true,
  );
  session.grantRole(
    by: director,
    id: 'grant-bot',
    personId: 'bot',
    label: 'assistant',
    crewRole: CrewRole.performer,
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
      PlayScene(
        id: 'scene-2',
        title: 'Office',
        body: 'A clause is read.',
        characterIds: ['rival'],
      ),
    ],
    characters: [
      PlayCharacter(id: 'hero', name: 'Hero'),
      PlayCharacter(id: 'rival', name: 'Rival'),
    ],
    shots: [
      PlayShot(id: 'shot-1', sceneId: 'scene-1', title: 'Wide'),
      PlayShot(id: 'shot-2', sceneId: 'scene-2', title: 'Insert'),
    ],
  );
  session.lockScript(director, 'r3');
  return session;
}

void issueAndClaim(PlaySession s) {
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
  s.issueTask(
    director,
    id: 'task-1',
    craft: 'actor',
    sceneId: 'scene-1',
    scriptVersionId: 'r3',
  );
  s.claimTask(actor, 'task-1');
}

PlaySession newMystery() {
  final session = PlaySession.mystery(
    id: 'mystery-gates',
    namespace: Namespace('studio', 'local', 'play-gates-m'),
    hostPersonId: 'gm',
    hostDeviceId: 'notebook',
  );
  session.addPerson(id: 'lin', label: 'Lin');
  session.addDevice(id: 'tv', personId: 'gm', kind: DeviceKind.publicScreen);
  session.addDevice(
    id: 'lin-phone',
    personId: 'lin',
    kind: DeviceKind.privateClient,
    scopes: {TrustScope.public},
  );
  session.addDevice(
    id: 'truth-spare',
    personId: 'gm',
    kind: DeviceKind.compute,
    scopes: {TrustScope.public, TrustScope.mysteryTruth},
    canCompute: true,
  );
  final gm = session.acting(
    personId: 'gm',
    deviceId: 'notebook',
    grantId: 'grant-gm',
  );
  session.grantRole(
    by: gm,
    id: 'grant-lin',
    personId: 'lin',
    label: 'player',
    mysteryRole: MysteryRole.player,
    characterId: 'linlan',
  );
  session.addCharacterSheet(
    gm,
    PlayCharacter(
      id: 'linlan',
      name: 'Lin Lan',
      bible: {'secret': 'Searching for a missing invoice'},
    ),
  );
  session.addClue(
    gm,
    MysteryClue(
      id: 'ledger',
      title: 'Hotel ledger',
      body: 'Ledger dated April 3',
      thumbnail: 'thumb:Ledger dated April 3',
      characterId: 'linlan',
    ),
  );
  session.setTruth(gm, 'The innkeeper hid the ledger.');
  session.publishScenario(gm);
  return session;
}

void main() {
  test('cancelTask and reassignTask require director or assistant director and keep history', () {
    final s = newCrew();
    issueAndClaim(s);
    final actor = s.acting(
      personId: 'ben',
      deviceId: 'ben-phone',
      grantId: 'grant-actor',
    );
    final editor = s.acting(
      personId: 'ed',
      deviceId: 'ed-desk',
      grantId: 'grant-editor',
    );
    final bot = s.acting(
      personId: 'bot',
      deviceId: 'bot-box',
      grantId: 'grant-bot',
    );
    expect(() => s.cancelTask(actor, 'task-1'), code('PLAY_PERMISSION_DENIED'));
    expect(
      () => s.reassignTask(editor, 'task-1', 'pat'),
      code('PLAY_PERMISSION_DENIED'),
    );
    expect(() => s.cancelTask(bot, 'task-1'), code('PLAY_AI_FORBIDDEN'));
    expect(s.tasks['task-1']!.phase, TaskPhase.claimed);
    expect(s.tasks['task-1']!.history, contains(contains('claimed')));
    final ad = s.acting(
      personId: 'cara',
      deviceId: 'cara-phone',
      grantId: 'grant-ad',
    );
    s.reassignTask(ad, 'task-1', 'pat');
    expect(s.tasks['task-1']!.phase, TaskPhase.reassigned);
    expect(s.tasks['task-1']!.history, contains(contains('reassigned')));
    expect(s.tasks['task-1']!.history, contains(contains('claimed')));
    final director = s.acting(
      personId: 'ada',
      deviceId: 'host',
      grantId: 'grant-director',
    );
    s.cancelTask(director, 'task-1');
    expect(s.tasks['task-1']!.phase, TaskPhase.cancelled);
    expect(s.tasks['task-1']!.history, contains(contains('cancelled')));
    expect(s.tasks['task-1']!.history, contains(contains('claimed')));
  });

  test('markTechnicalQuality is limited to director, assistant director or performer and is not creative adoption', () {
    final s = newCrew();
    issueAndClaim(s);
    final actor = s.acting(
      personId: 'ben',
      deviceId: 'ben-phone',
      grantId: 'grant-actor',
    );
    s.submitDelivery(
      actor,
      id: 'take-1',
      taskId: 'task-1',
      kind: DeliveryKind.take,
      body: 'take one',
      source: 'phone',
      authorizationNote: 'performance grant',
    );
    final writer = s.acting(
      personId: 'cara',
      deviceId: 'cara-phone',
      grantId: 'grant-writer',
    );
    final editor = s.acting(
      personId: 'ed',
      deviceId: 'ed-desk',
      grantId: 'grant-editor',
    );
    final bot = s.acting(
      personId: 'bot',
      deviceId: 'bot-box',
      grantId: 'grant-bot',
    );
    expect(
      () => s.markTechnicalQuality(writer, 'take-1', 'pass'),
      code('PLAY_PERMISSION_DENIED'),
    );
    expect(
      () => s.markTechnicalQuality(editor, 'take-1', 'pass'),
      code('PLAY_PERMISSION_DENIED'),
    );
    expect(
      () => s.markTechnicalQuality(bot, 'take-1', 'pass'),
      code('PLAY_AI_FORBIDDEN'),
    );
    s.markTechnicalQuality(actor, 'take-1', 'pass');
    expect(s.deliveries['take-1']!.technicalMark, 'pass');
    expect(s.adoptions, isEmpty);
    expect(s.tasks['task-1']!.phase, TaskPhase.submitted);
    final ad = s.acting(
      personId: 'cara',
      deviceId: 'cara-phone',
      grantId: 'grant-ad',
    );
    s.markTechnicalQuality(ad, 'take-1', 'continuity-ok');
    expect(s.deliveries['take-1']!.technicalMark, 'continuity-ok');
    expect(s.adoptions, isEmpty);
  });

  test('official issue rejects unscoped editor and lead performer; screenwriter stays inside assigned scenes', () {
    final s = newCrew();
    final director = s.acting(
      personId: 'ada',
      deviceId: 'host',
      grantId: 'grant-director',
    );
    final writer = s.acting(
      personId: 'cara',
      deviceId: 'cara-phone',
      grantId: 'grant-writer',
    );
    final editor = s.acting(
      personId: 'ed',
      deviceId: 'ed-desk',
      grantId: 'grant-editor',
    );
    final lead = s.acting(
      personId: 'pat',
      deviceId: 'pat-phone',
      grantId: 'grant-lead',
    );
    final actor = s.acting(
      personId: 'ben',
      deviceId: 'ben-phone',
      grantId: 'grant-actor',
    );
    expect(
      () => s.issueTask(
        editor,
        id: 'task-editor',
        craft: 'edit',
        sceneId: 'scene-1',
        scriptVersionId: 'r3',
        department: 'editorial',
      ),
      code('PLAY_PERMISSION_DENIED'),
    );
    expect(
      () => s.issueTask(
        lead,
        id: 'task-lead',
        craft: 'actor',
        sceneId: 'scene-1',
        scriptVersionId: 'r3',
      ),
      code('PLAY_PERMISSION_DENIED'),
    );
    expect(
      () => s.issueTask(
        actor,
        id: 'task-actor',
        craft: 'actor',
        sceneId: 'scene-1',
        scriptVersionId: 'r3',
      ),
      code('PLAY_PERMISSION_DENIED'),
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
    s.issueTask(
      writer,
      id: 'task-in',
      craft: 'actor',
      sceneId: 'scene-1',
      scriptVersionId: 'r3',
    );
    expect(s.tasks['task-in']!.official, isTrue);
    s.issueTask(
      director,
      id: 'task-dir',
      craft: 'actor',
      sceneId: 'scene-2',
      scriptVersionId: 'r3',
    );
    expect(s.tasks['task-dir']!.official, isTrue);
  });

  test('PlayDevice.allows does not treat mysteryTruth as a wildcard for other scopes', () {
    final s = newMystery();
    final notebook = s.device('notebook');
    final tv = s.device('tv');
    final spare = s.device('truth-spare');
    expect(notebook.allows(TrustScope.mysteryTruth), isTrue);
    expect(notebook.allows(TrustScope.public), isTrue);
    expect(notebook.allows(TrustScope.character('linlan')), isFalse);
    expect(notebook.allows(TrustScope.crewConfidential), isFalse);
    expect(tv.allows(TrustScope.mysteryTruth), isFalse);
    expect(tv.allows(TrustScope.character('linlan')), isFalse);
    expect(spare.allows(TrustScope.mysteryTruth), isTrue);
    expect(spare.allows(TrustScope.character('linlan')), isFalse);
    expect(
      s.compute.eligibleDevices(
        PlayComputeIntent(
          id: 'secret-1',
          inputs: [
            PlayInput(
              id: 'ledger-in',
              scope: TrustScope.character('linlan'),
              label: 'ledger',
              payload: 'Ledger dated April 3',
            ),
          ],
        ),
      ),
      isEmpty,
    );
    final privateIntent = PlayComputeIntent(
      id: 'secret-2',
      inputs: [
        PlayInput(
          id: 'ledger-in2',
          scope: TrustScope.character('linlan'),
          label: 'ledger',
          payload: 'Ledger dated April 3',
        ),
      ],
    );
    expect(s.compute.chooseDevice(privateIntent)?.id, 'notebook');
    expect(
      () => s.compute.claimLease(
        privateIntent,
        deviceId: 'truth-spare',
        nowMs: 0,
      ),
      code('PLAY_PRIVATE_INPUT'),
    );
    final gmView = s.view(
      personId: 'gm',
      deviceId: 'notebook',
      grantId: 'grant-gm',
    );
    expect(gmView.containsText('The innkeeper hid the ledger.'), isTrue);
    final tvView = s.view(personId: 'gm', deviceId: 'tv', grantId: 'grant-gm');
    expect(tvView.containsText('The innkeeper hid the ledger.'), isFalse);
  });

  test('memorial video export requires the GM person consent as well as the players', () {
    final s = newMystery();
    final gm = s.acting(
      personId: 'gm',
      deviceId: 'notebook',
      grantId: 'grant-gm',
    );
    final lin = s.acting(
      personId: 'lin',
      deviceId: 'lin-phone',
      grantId: 'grant-lin',
    );
    s.recordMemorialConsent(lin, consented: true);
    expect(s.recap(by: gm, wantVideo: false)['kind'], 'text-recap');
    expect(
      () => s.recap(by: gm, wantVideo: true),
      code('PLAY_CONSENT_REQUIRED'),
    );
    s.recordMemorialConsent(gm, consented: true);
    expect(s.recap(by: gm, wantVideo: true)['kind'], 'memorial-permit');
  });
}
