import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_play/studio_play.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

void main() {
  test('loopback fabric delivers hello and heartbeat between two logical peers', () {
    final session = PlaySession.crew(
      id: 'crew-lan',
      namespace: Namespace('studio', 'local', 'play-lan'),
      hostPersonId: 'ada',
      hostDeviceId: 'host',
    );
    session.addPerson(id: 'ben', label: 'Ben');
    session.addDevice(
      id: 'ben-phone',
      personId: 'ben',
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
      id: 'grant-editor',
      personId: 'ben',
      label: 'editor',
      crewRole: CrewRole.editor,
    );
    final left = PlayLanEndpoint(
      session: session,
      deviceId: 'host',
      personId: 'ada',
      grantId: 'grant-director',
    );
    final right = PlayLanEndpoint(
      session: session,
      deviceId: 'ben-phone',
      personId: 'ben',
      grantId: 'grant-editor',
    );
    final fabric = LoopbackPlayLanFabric(left, right);
    fabric.sendLeftToRight(
      left.compose(
        kind: PlayLanMessageKind.hello,
        payload: {'protocol': 'play.lan.v1'},
        sentAtMs: 1,
      ),
    );
    fabric.sendRightToLeft(
      right.compose(
        kind: PlayLanMessageKind.heartbeat,
        payload: {'clock': 1},
        sentAtMs: 2,
      ),
    );
    expect(fabric.delivered, 2);
    expect(right.inbox.single.kind, PlayLanMessageKind.hello);
    expect(left.inbox.single.kind, PlayLanMessageKind.heartbeat);
    expect(fabric.claimPhysicalE2e, code(playLanPhysicalE2eUnclaimed));
  });

  test('duplicate seq is ignored and a revoked grant is refused', () {
    final session = PlaySession.crew(
      id: 'crew-lan-2',
      namespace: Namespace('studio', 'local', 'play-lan-2'),
      hostPersonId: 'ada',
      hostDeviceId: 'host',
    );
    session.addPerson(id: 'ben', label: 'Ben');
    session.addDevice(
      id: 'ben-phone',
      personId: 'ben',
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
      id: 'grant-editor',
      personId: 'ben',
      label: 'editor',
      crewRole: CrewRole.editor,
    );
    final left = PlayLanEndpoint(
      session: session,
      deviceId: 'host',
      personId: 'ada',
      grantId: 'grant-director',
    );
    final right = PlayLanEndpoint(
      session: session,
      deviceId: 'ben-phone',
      personId: 'ben',
      grantId: 'grant-editor',
    );
    final fabric = LoopbackPlayLanFabric(left, right);
    final hello = left.compose(
      kind: PlayLanMessageKind.hello,
      payload: {'protocol': 'play.lan.v1'},
      sentAtMs: 1,
    );
    fabric.sendLeftToRight(hello);
    fabric.sendLeftToRight(hello);
    expect(fabric.delivered, 1);
    expect(fabric.ignoredDuplicates, 1);
    session.revoke(director, 'grant-editor');
    final later = right.compose(
      kind: PlayLanMessageKind.heartbeat,
      payload: {'clock': 2},
      sentAtMs: 3,
    );
    expect(() => fabric.sendRightToLeft(later), code(playLanGrantRevoked));
  });

  test('mystery truth is not delivered to a public screen and snapshots stay filtered', () {
    final session = PlaySession.mystery(
      id: 'mystery-lan',
      namespace: Namespace('studio', 'local', 'play-lan-m'),
      hostPersonId: 'gm',
      hostDeviceId: 'host',
    );
    session.truth = 'the butler did it';
    session.addDevice(
      id: 'lobby-screen',
      personId: 'gm',
      kind: DeviceKind.publicScreen,
    );
    final gm = session.acting(
      personId: 'gm',
      deviceId: 'host',
      grantId: 'grant-gm',
    );
    session.grantRole(
      by: gm,
      id: 'grant-screen',
      personId: 'gm',
      label: 'publicScreen',
      mysteryRole: MysteryRole.publicScreen,
    );
    final host = PlayLanEndpoint(
      session: session,
      deviceId: 'host',
      personId: 'gm',
      grantId: 'grant-gm',
    );
    final screen = PlayLanEndpoint(
      session: session,
      deviceId: 'lobby-screen',
      personId: 'gm',
      grantId: 'grant-screen',
    );
    final fabric = LoopbackPlayLanFabric(host, screen);
    expect(
      () => fabric.sendLeftToRight(
        host.compose(
          kind: PlayLanMessageKind.event,
          payload: {'body': 'the butler did it'},
          sentAtMs: 1,
          scope: TrustScope.mysteryTruth.id,
        ),
      ),
      code(playLanScopeLeak),
    );
    expect(screen.inbox, isEmpty);
    final snap = screen.filteredSnapshot();
    expect(snap['hasTruth'], isFalse);
    final hostSnap = host.filteredSnapshot();
    // Host notebook may include truth in logs or docs depending on view.
    expect(hostSnap, isA<Map<String, Object?>>());
  });

  test('tampered payload hash is refused and session mismatch is refused', () {
    final session = PlaySession.crew(
      id: 'crew-lan-3',
      namespace: Namespace('studio', 'local', 'play-lan-3'),
      hostPersonId: 'ada',
      hostDeviceId: 'host',
    );
    final host = PlayLanEndpoint(
      session: session,
      deviceId: 'host',
      personId: 'ada',
      grantId: 'grant-director',
    );
    final env = host.compose(
      kind: PlayLanMessageKind.hello,
      payload: {'protocol': 'play.lan.v1'},
      sentAtMs: 1,
    );
    final json = Map<String, Object?>.from(env.toJson());
    json['payloadHash'] = '0' * 64;
    expect(() => PlayLanEnvelope.parse(json), code(playLanBadHash));
    final other = PlayLanEnvelope(
      sessionId: 'other-session',
      seq: 1,
      senderDeviceId: 'host',
      senderPersonId: 'ada',
      grantId: 'grant-director',
      kind: PlayLanMessageKind.hello,
      payload: const {'x': 1},
      sentAtMs: 1,
    );
    expect(() => host.receive(other), code(playLanSessionMismatch));
  });
}
