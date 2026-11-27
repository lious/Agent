import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_play/studio_play.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

const truth = 'The innkeeper hid the ledger in the west drawer.';

PlaySession newMystery() {
  final session = PlaySession.mystery(
    id: 'mystery-session',
    namespace: Namespace('studio', 'local', 'play-mystery'),
    hostPersonId: 'gm',
    hostDeviceId: 'notebook',
  );
  session.addPerson(id: 'lin', label: 'Lin');
  session.addPerson(id: 'zhou', label: 'Zhou');
  session.addDevice(id: 'tv', personId: 'gm', kind: DeviceKind.publicScreen);
  session.addDevice(
    id: 'lin-phone',
    personId: 'lin',
    kind: DeviceKind.privateClient,
    scopes: {TrustScope.public},
  );
  session.addDevice(
    id: 'zhou-phone',
    personId: 'zhou',
    kind: DeviceKind.privateClient,
    scopes: {TrustScope.public},
  );
  session.addDevice(
    id: 'spare',
    personId: 'gm',
    kind: DeviceKind.compute,
    scopes: {TrustScope.public},
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
  session.grantRole(
    by: gm,
    id: 'grant-zhou',
    personId: 'zhou',
    label: 'player',
    mysteryRole: MysteryRole.player,
    characterId: 'zhouke',
  );
  session.grantRole(
    by: gm,
    id: 'grant-tv',
    personId: 'gm',
    label: 'publicScreen',
    mysteryRole: MysteryRole.publicScreen,
  );
  session.addCharacterSheet(
    gm,
    PlayCharacter(
      id: 'linlan',
      name: 'Lin Lan',
      bible: {'secret': 'Searching for a missing invoice'},
    ),
  );
  session.addCharacterSheet(
    gm,
    PlayCharacter(
      id: 'zhouke',
      name: 'Zhou Ke',
      bible: {'secret': 'Guarding the east corridor'},
    ),
  );
  session.addSpace(
    gm,
    SpaceCard(id: 'study', title: 'Study', body: 'A dark study'),
  );
  session.addProp(
    gm,
    PropTag(id: 'box', spaceId: 'study', label: 'Locked box'),
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
  session.setTruth(gm, truth);
  session.setAtmosphere(gm, 'Rain on the tin roof');
  session.publishScenario(gm);
  return session;
}

void expectNoSecret(PlayView view, {required List<String> needles}) {
  for (final needle in needles) {
    expect(
      view.containsText(needle),
      isFalse,
      reason: '${view.deviceId} leaked $needle',
    );
  }
}

void main() {
  test(
    'GM notebook sees the solution; the same account public screen does not',
    () {
      final s = newMystery();
      final gmView = s.view(
        personId: 'gm',
        deviceId: 'notebook',
        grantId: 'grant-gm',
      );
      expect(gmView.containsText(truth), isTrue);
      final tv = s.view(personId: 'gm', deviceId: 'tv', grantId: 'grant-gm');
      expectNoSecret(
        tv,
        needles: [truth, 'Ledger dated April 3', 'missing invoice'],
      );
      final tvRole = s.view(
        personId: 'gm',
        deviceId: 'tv',
        grantId: 'grant-tv',
      );
      expectNoSecret(tvRole, needles: [truth, 'Ledger dated April 3']);
      expect(tv.containsText('Rain on the tin roof'), isTrue);
    },
  );

  test('private clues stay off other players and the public screen, including thumbnails, notices and logs', () {
    final s = newMystery();
    final gm = s.acting(
      personId: 'gm',
      deviceId: 'notebook',
      grantId: 'grant-gm',
    );
    s.transitionAct(gm, 'search');
    s.deliverPrivateClue(gm, 'ledger', 'linlan');
    final lin = s.view(
      personId: 'lin',
      deviceId: 'lin-phone',
      grantId: 'grant-lin',
    );
    expect(lin.containsText('Ledger dated April 3'), isTrue);
    expect(lin.notifications, isNotEmpty);
    final zhou = s.view(
      personId: 'zhou',
      deviceId: 'zhou-phone',
      grantId: 'grant-zhou',
    );
    final tv = s.view(personId: 'gm', deviceId: 'tv', grantId: 'grant-tv');
    for (final view in [zhou, tv]) {
      expectNoSecret(
        view,
        needles: [
          'Ledger dated April 3',
          'thumb:Ledger dated April 3',
          'private:Ledger',
        ],
      );
      expect(view.hasDocument('clue-ledger'), isFalse);
      expect(view.publicBoard, isEmpty);
    }
    expect(
      s
          .view(
            personId: 'zhou',
            deviceId: 'zhou-phone',
            grantId: 'grant-zhou',
            query: 'Ledger dated April 3',
          )
          .searchHits,
      isEmpty,
    );
    expect(zhou.containsText('Guarding the east corridor'), isTrue);
    expect(zhou.containsText('missing invoice'), isFalse);
    expect(lin.containsText('Guarding the east corridor'), isFalse);
  });

  test('public board stays empty until an explicit public reveal; only GM transitions acts', () {
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
    s.deliverPrivateClue(gm, 'ledger', 'linlan');
    expect(
      s.view(personId: 'gm', deviceId: 'tv', grantId: 'grant-tv').publicBoard,
      isEmpty,
    );
    expect(
      () => s.publishClueToPublicBoard(gm, 'ledger'),
      code('PLAY_PERMISSION_DENIED'),
    );
    s.requestPublicReveal(lin, 'ledger');
    s.publishClueToPublicBoard(gm, 'ledger');
    final tv = s.view(personId: 'gm', deviceId: 'tv', grantId: 'grant-tv');
    expect(tv.publicBoard.single.body, contains('Ledger dated April 3'));
    expect(
      () => s.transitionAct(lin, 'reveal'),
      code('PLAY_PERMISSION_DENIED'),
    );
    s.transitionAct(gm, 'reveal');
    expect(s.currentAct, 'reveal');
    expect(s.storyLog.any((e) => e.kind == 'actTransition'), isTrue);
    expect(s.storyLog.every((e) => e.kind != 'SetMarkers'), isTrue);
    expect(
      () => rejectPlayActionAsEditProposal('transitionAct'),
      code('PLAY_UNSUPPORTED_PROPOSAL'),
    );
  });

  test('compute rejects private inputs; results cannot advance the story or reveal the truth', () {
    final s = newMystery();
    final intent = PlayComputeIntent(
      id: 'volume-1',
      inputs: [
        PlayInput(
          id: 'ledger-in',
          scope: TrustScope.character('linlan'),
          label: 'ledger',
          payload: 'Ledger dated April 3',
        ),
      ],
    );
    // No spare compute device may hold the private clue; the authorized host may.
    expect(s.compute.eligibleDevices(intent), isEmpty);
    expect(s.compute.chooseDevice(intent)?.id, 'notebook');
    expect(
      () => s.compute.claimLease(intent, deviceId: 'spare', nowMs: 0),
      code('PLAY_PRIVATE_INPUT'),
    );
    final publicIntent = PlayComputeIntent(
      id: 'rain-1',
      inputs: [
        PlayInput(
          id: 'rain',
          scope: TrustScope.public,
          label: 'rain-stem',
          payload: 'Rain on the tin roof',
        ),
      ],
    );
    expect(s.compute.chooseDevice(publicIntent)?.id, 'spare');
    final lease = s.compute.claimLease(
      publicIntent,
      deviceId: 'spare',
      nowMs: 10,
    );
    s.compute.submitCandidate(
      intent: publicIntent,
      lease: lease,
      body: 'peak=-12',
    );
    expect(
      () => s.compute.applyComputeResult(publicIntent, advanceStory: true),
      code('PLAY_COMPUTE_CANNOT_ADVANCE'),
    );
    expect(
      () => s.compute.applyComputeResult(publicIntent, revealTruth: true),
      code('PLAY_COMPUTE_CANNOT_ADVANCE'),
    );
    s.compute.applyComputeResult(publicIntent);
    expect(s.currentAct, 'entry');
    expect(
      s
          .view(personId: 'gm', deviceId: 'tv', grantId: 'grant-tv')
          .containsText(truth),
      isFalse,
    );
  });

  test('host offline pauses transitions; last page does not broadcast the truth; video needs consent', () {
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
    final zhou = s.acting(
      personId: 'zhou',
      deviceId: 'zhou-phone',
      grantId: 'grant-zhou',
    );
    s.setOnline('notebook', false);
    expect(() => s.transitionAct(gm, 'search'), code('PLAY_HOST_OFFLINE'));
    s.setOnline('notebook', true);
    s.transitionAct(gm, 'search');
    s.playerAdvancePage(lin, 99);
    final tv = s.view(personId: 'gm', deviceId: 'tv', grantId: 'grant-tv');
    final zhouView = s.view(
      personId: 'zhou',
      deviceId: 'zhou-phone',
      grantId: 'grant-zhou',
    );
    expectNoSecret(tv, needles: [truth]);
    expectNoSecret(zhouView, needles: [truth]);
    final recap = s.recap(by: gm, wantVideo: false);
    expect(recap['kind'], 'text-recap');
    expect(recap['video'], isNull);
    expect(
      () => s.recap(by: gm, wantVideo: true),
      code('PLAY_CONSENT_REQUIRED'),
    );
    s.recordMemorialConsent(lin, consented: true);
    s.recordMemorialConsent(zhou, consented: true);
    s.recordMemorialConsent(gm, consented: true);
    expect(s.recap(by: gm, wantVideo: true)['kind'], 'memorial-permit');
    expect(s.recap(by: gm, wantVideo: true)['video'], 'not-produced-in-mvp-a');
  });
}
