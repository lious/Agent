import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_play/studio_play.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

(PlaySession, PlayLanEndpoint, PlayLanEndpoint, LoopbackPlayLanFabric)
    crewPeers() {
  final session = PlaySession.crew(
    id: 'crew-lan-x',
    namespace: Namespace('studio', 'local', 'play-lan-x'),
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
  return (session, left, right, LoopbackPlayLanFabric(left, right));
}

void main() {
  test('a snapshot reply is filtered for the requester, not the host notebook', () {
    final session = PlaySession.mystery(
      id: 'mystery-lan-x',
      namespace: Namespace('studio', 'local', 'play-lan-mx'),
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
    expect(host.filteredSnapshot()['hasTruth'], isTrue);
    expect(screen.filteredSnapshot()['hasTruth'], isFalse);
    final reply = fabric.exchangeSnapshot(
      requester: screen,
      responder: host,
      sentAtMs: 10,
      deliverRequest: fabric.sendRightToLeft,
      deliverReply: fabric.sendLeftToRight,
    );
    expect(reply.kind, PlayLanMessageKind.snapshot);
    expect(reply.payload['hasTruth'], isFalse);
    expect(screen.inbox.last.payload['hasTruth'], isFalse);
    expect(
      () => host.replyToSnapshotRequest(
        host.compose(
          kind: PlayLanMessageKind.hello,
          payload: const {'protocol': 'play.lan.v1'},
          sentAtMs: 11,
        ),
        sentAtMs: 12,
      ),
      code(playLanUnexpectedKind),
    );
  });

  test('crew.confidential is not delivered to a public-only client; sides stay character-bound', () {
    final (session, left, right, fabric) = crewPeers();
    expect(
      () => fabric.sendLeftToRight(
        left.compose(
          kind: PlayLanMessageKind.event,
          payload: const {'body': 'internal cut list'},
          sentAtMs: 1,
          scope: TrustScope.crewConfidential.id,
        ),
      ),
      code(playLanScopeLeak),
    );
    expect(right.inbox, isEmpty);

    session.addPerson(id: 'ann', label: 'Ann');
    final director = session.acting(
      personId: 'ada',
      deviceId: 'host',
      grantId: 'grant-director',
    );
    session.grantRole(
      by: director,
      id: 'grant-ben-actor',
      personId: 'ben',
      label: 'ben-performer',
      crewRole: CrewRole.performer,
      characterId: 'char-ben',
    );
    session.grantRole(
      by: director,
      id: 'grant-ann-actor',
      personId: 'ann',
      label: 'ann-performer',
      crewRole: CrewRole.performer,
      characterId: 'char-ann',
    );
    session.addDevice(
      id: 'ann-phone',
      personId: 'ann',
      kind: DeviceKind.privateClient,
      scopes: {TrustScope.public},
    );
    final benActor = PlayLanEndpoint(
      session: session,
      deviceId: 'ben-phone',
      personId: 'ben',
      grantId: 'grant-ben-actor',
    );
    final annActor = PlayLanEndpoint(
      session: session,
      deviceId: 'ann-phone',
      personId: 'ann',
      grantId: 'grant-ann-actor',
    );
    // Host may send character sides; only the bound performer may receive them.
    final toBen = LoopbackPlayLanFabric(left, benActor);
    toBen.sendLeftToRight(
      left.compose(
        kind: PlayLanMessageKind.event,
        payload: const {'body': 'ben cue'},
        sentAtMs: 2,
        scope: TrustScope.sides('char-ben').id,
      ),
    );
    expect(benActor.inbox.single.payload['body'], 'ben cue');
    expect(
      () => LoopbackPlayLanFabric(left, annActor).sendLeftToRight(
        left.compose(
          kind: PlayLanMessageKind.event,
          payload: const {'body': 'ben cue'},
          sentAtMs: 3,
          scope: TrustScope.sides('char-ben').id,
        ),
      ),
      code(playLanScopeLeak),
    );
    expect(annActor.inbox, isEmpty);
  });

  test('an accepted event can be acked; stale seq is ignored; unknown and departed peers are refused', () {
    final (session, left, right, fabric) = crewPeers();
    final event = left.compose(
      kind: PlayLanMessageKind.event,
      payload: const {'body': 'slate marked'},
      sentAtMs: 1,
    );
    fabric.sendLeftToRight(event);
    expect(right.inbox, hasLength(1));
    fabric.sendRightToLeft(right.ackEvent(event, sentAtMs: 2));
    expect(left.ackedEvents, contains('host:1'));

    final stale = PlayLanEnvelope(
      sessionId: session.id,
      seq: event.seq,
      senderDeviceId: 'host',
      senderPersonId: 'ada',
      grantId: 'grant-director',
      kind: PlayLanMessageKind.heartbeat,
      payload: const {'clock': 0},
      sentAtMs: 3,
    );
    fabric.sendLeftToRight(stale);
    expect(fabric.ignoredDuplicates, 1);
    expect(right.inbox, hasLength(1));

    final ghost = PlayLanEnvelope(
      sessionId: session.id,
      seq: 1,
      senderDeviceId: 'ghost',
      senderPersonId: 'ada',
      grantId: 'grant-director',
      kind: PlayLanMessageKind.hello,
      payload: const {'protocol': 'play.lan.v1'},
      sentAtMs: 4,
    );
    expect(() => fabric.sendLeftToRight(ghost), code(playLanUnknownPeer));

    fabric.sendLeftToRight(
      left.compose(
        kind: PlayLanMessageKind.goodbye,
        payload: const {'reason': 'leave'},
        sentAtMs: 5,
      ),
    );
    expect(right.departed, contains('host'));
    expect(
      () => fabric.sendLeftToRight(
        left.compose(
          kind: PlayLanMessageKind.heartbeat,
          payload: const {'clock': 9},
          sentAtMs: 6,
        ),
      ),
      code(playLanPeerGone),
    );
    expect(fabric.claimPhysicalE2e, code(playLanPhysicalE2eUnclaimed));
  });
}
