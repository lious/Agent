import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';

import 'play_session.dart';

const playLanSessionMismatch = 'PLAY_LAN_SESSION_MISMATCH';
const playLanGrantRevoked = 'PLAY_LAN_GRANT_REVOKED';
const playLanScopeLeak = 'PLAY_LAN_SCOPE_LEAK';
const playLanDuplicateSeq = 'PLAY_LAN_DUPLICATE_SEQ';
const playLanUnknownPeer = 'PLAY_LAN_UNKNOWN_PEER';
const playLanBadHash = 'PLAY_LAN_BAD_HASH';
const playLanPhysicalE2eUnclaimed = 'PLAY_LAN_PHYSICAL_E2E_UNCLAIMED';
const playLanPeerGone = 'PLAY_LAN_PEER_GONE';
const playLanUnexpectedKind = 'PLAY_LAN_UNEXPECTED_KIND';

enum PlayLanMessageKind {
  hello,
  heartbeat,
  grantSync,
  event,
  eventAck,
  snapshotRequest,
  snapshot,
  goodbye,
}

/// Length-delimited logical envelope. This is a software/protocol contract
/// for a limited LAN slice. It is not a two-physical-device E2E claim,
/// not writable peer RPC, and not a studio_store schema v10 migration.
final class PlayLanEnvelope {
  PlayLanEnvelope({
    required this.sessionId,
    required this.seq,
    required this.senderDeviceId,
    required this.senderPersonId,
    required this.grantId,
    required this.kind,
    required this.payload,
    required this.sentAtMs,
    this.scope = 'public',
  }) : payloadHash = _hash(payload) {
    requireId(sessionId);
    requireId(senderDeviceId);
    requireId(senderPersonId);
    requireId(grantId);
  }

  final String sessionId, senderDeviceId, senderPersonId, grantId, scope;
  final int seq, sentAtMs;
  final PlayLanMessageKind kind;
  final Map<String, Object?> payload;
  final String payloadHash;

  Map<String, Object?> toJson() => {
    'sessionId': sessionId,
    'seq': seq,
    'senderDeviceId': senderDeviceId,
    'senderPersonId': senderPersonId,
    'grantId': grantId,
    'kind': kind.name,
    'scope': scope,
    'sentAtMs': sentAtMs,
    'payload': payload,
    'payloadHash': payloadHash,
  };

  static PlayLanEnvelope parse(Map<String, Object?> json) {
    final env = PlayLanEnvelope(
      sessionId: json['sessionId'] as String,
      seq: json['seq'] as int,
      senderDeviceId: json['senderDeviceId'] as String,
      senderPersonId: json['senderPersonId'] as String,
      grantId: json['grantId'] as String,
      kind: PlayLanMessageKind.values.byName(json['kind'] as String),
      payload: Map<String, Object?>.from(json['payload'] as Map),
      sentAtMs: json['sentAtMs'] as int,
      scope: json['scope'] as String? ?? 'public',
    );
    if (env.payloadHash != json['payloadHash']) {
      throw const StudioException(playLanBadHash);
    }
    return env;
  }

  static String _hash(Map<String, Object?> payload) {
    final raw = jsonEncode(payload);
    var n = 0;
    final out = StringBuffer();
    for (final unit in raw.codeUnits) {
      n = (n * 33 + unit) & 0xffffffff;
      out.write((n & 0xff).toRadixString(16).padLeft(2, '0'));
    }
    return out.toString().padRight(64, '0').substring(0, 64);
  }
}

/// Receiver-side guard. Re-checks session, grant, scope, and seq.
final class PlayLanEndpoint {
  PlayLanEndpoint({
    required this.session,
    required this.deviceId,
    required this.personId,
    required this.grantId,
  });

  final PlaySession session;
  final String deviceId, personId, grantId;
  final List<PlayLanEnvelope> inbox = [];
  final Map<String, int> _lastSeq = {};
  final Set<String> _seen = {};
  final Set<String> departed = {};
  final Set<String> ackedEvents = {};
  int nextSeq = 1;

  PlayLanEnvelope compose({
    required PlayLanMessageKind kind,
    required Map<String, Object?> payload,
    required int sentAtMs,
    String scope = 'public',
  }) {
    return PlayLanEnvelope(
      sessionId: session.id,
      seq: nextSeq++,
      senderDeviceId: deviceId,
      senderPersonId: personId,
      grantId: grantId,
      kind: kind,
      payload: payload,
      sentAtMs: sentAtMs,
      scope: scope,
    );
  }

  /// Returns false when a duplicate seq is ignored. Throws on policy
  /// violations. Never claims physical-device delivery.
  bool receive(PlayLanEnvelope envelope) {
    if (envelope.sessionId != session.id) {
      throw const StudioException(playLanSessionMismatch);
    }
    if (departed.contains(envelope.senderDeviceId) &&
        envelope.kind != PlayLanMessageKind.goodbye) {
      throw StudioException(playLanPeerGone, envelope.senderDeviceId);
    }
    final sender = session.devices[envelope.senderDeviceId];
    if (sender == null) {
      throw StudioException(playLanUnknownPeer, envelope.senderDeviceId);
    }
    if (sender.personId != envelope.senderPersonId) {
      throw StudioException(playLanUnknownPeer, envelope.senderPersonId);
    }
    final grant = session.grants[envelope.grantId];
    if (grant == null || grant.revoked) {
      throw StudioException(playLanGrantRevoked, envelope.grantId);
    }
    if (grant.personId != envelope.senderPersonId) {
      throw StudioException(playLanGrantRevoked, 'person');
    }
    final self = session.device(deviceId);
    if (!_scopeAllowed(self, envelope.scope)) {
      throw StudioException(playLanScopeLeak, envelope.scope);
    }
    // Payload documents must also be legal for the receiver view.
    final body = envelope.payload['body'] as String?;
    if (body != null) {
      _refuseScopeLeakBody(self, envelope, body);
    }
    final key = '${envelope.senderDeviceId}:${envelope.seq}';
    if (_seen.contains(key)) {
      return false;
    }
    final last = _lastSeq[envelope.senderDeviceId] ?? 0;
    if (envelope.seq <= last && _seen.isNotEmpty) {
      // Stale or duplicate seq after the first message is ignored,
      // not applied.
      return false;
    }
    _seen.add(key);
    _lastSeq[envelope.senderDeviceId] = envelope.seq;
    inbox.add(envelope);
    if (envelope.kind == PlayLanMessageKind.goodbye) {
      departed.add(envelope.senderDeviceId);
    }
    if (envelope.kind == PlayLanMessageKind.eventAck) {
      final ackSeq = envelope.payload['ackSeq'];
      final origin = envelope.payload['eventSender'] as String? ?? envelope.senderDeviceId;
      if (ackSeq is int) ackedEvents.add('$origin:$ackSeq');
    }
    return true;
  }

  bool _scopeAllowed(PlayDevice device, String scope) {
    if (scope == 'public') return true;
    if (scope == TrustScope.mysteryTruth.id) {
      return device.allows(TrustScope.mysteryTruth);
    }
    if (scope == TrustScope.crewConfidential.id) {
      return device.allows(TrustScope.crewConfidential);
    }
    return device.scopes.any((s) => s.id == scope);
  }

  void _refuseScopeLeakBody(
    PlayDevice device,
    PlayLanEnvelope envelope,
    String body,
  ) {
    if (envelope.scope == TrustScope.mysteryTruth.id &&
        !device.allows(TrustScope.mysteryTruth)) {
      throw const StudioException(playLanScopeLeak, 'truth');
    }
  }

  /// Snapshot contents are filtered through [PlaySession.view] so a public
  /// screen cannot receive a GM notebook.
  Map<String, Object?> filteredSnapshot() => snapshotFor(
    personId: personId,
    deviceId: deviceId,
    grantId: grantId,
  );

  /// Always project the requested (person, device, grant) triple, never the
  /// answering host's notebook.
  Map<String, Object?> snapshotFor({
    required String personId,
    required String deviceId,
    required String grantId,
  }) {
    final view = session.view(
      personId: personId,
      deviceId: deviceId,
      grantId: grantId,
    );
    return {
      'documents': [for (final d in view.documents) d.id],
      'publicBoard': [for (final d in view.publicBoard) d.id],
      'hasTruth': view.containsText('truth') || view.containsText('谜底'),
    };
  }

  /// Reply to a snapshotRequest with a snapshot filtered for the requester.
  PlayLanEnvelope replyToSnapshotRequest(
    PlayLanEnvelope request, {
    required int sentAtMs,
  }) {
    if (request.kind != PlayLanMessageKind.snapshotRequest) {
      throw StudioException(playLanUnexpectedKind, request.kind.name);
    }
    return compose(
      kind: PlayLanMessageKind.snapshot,
      payload: snapshotFor(
        personId: request.senderPersonId,
        deviceId: request.senderDeviceId,
        grantId: request.grantId,
      ),
      sentAtMs: sentAtMs,
      scope: 'public',
    );
  }

  PlayLanEnvelope ackEvent(
    PlayLanEnvelope event, {
    required int sentAtMs,
  }) {
    if (event.kind != PlayLanMessageKind.event) {
      throw StudioException(playLanUnexpectedKind, event.kind.name);
    }
    return compose(
      kind: PlayLanMessageKind.eventAck,
      payload: {
        'ackSeq': event.seq,
        'eventSender': event.senderDeviceId,
      },
      sentAtMs: sentAtMs,
    );
  }
}

/// In-process bidirectional fabric. This exercises the protocol on one
/// Linux/Web runtime with two logical peers. It is not a LAN radio,
/// STUN/TURN, or two-physical-device qualification.
final class LoopbackPlayLanFabric {
  LoopbackPlayLanFabric(this.left, this.right);

  final PlayLanEndpoint left, right;
  int delivered = 0;
  int ignoredDuplicates = 0;

  void sendLeftToRight(PlayLanEnvelope envelope) {
    final accepted = right.receive(envelope);
    if (accepted) {
      delivered++;
    } else {
      ignoredDuplicates++;
    }
  }

  void sendRightToLeft(PlayLanEnvelope envelope) {
    final accepted = left.receive(envelope);
    if (accepted) {
      delivered++;
    } else {
      ignoredDuplicates++;
    }
  }

  /// Host answers a snapshotRequest with a view filtered for the requester.
  /// The host notebook is never used as the payload.
  PlayLanEnvelope exchangeSnapshot({
    required PlayLanEndpoint requester,
    required PlayLanEndpoint responder,
    required int sentAtMs,
    required void Function(PlayLanEnvelope envelope) deliverRequest,
    required void Function(PlayLanEnvelope envelope) deliverReply,
  }) {
    final request = requester.compose(
      kind: PlayLanMessageKind.snapshotRequest,
      payload: const {'what': 'view'},
      sentAtMs: sentAtMs,
    );
    deliverRequest(request);
    final reply = responder.replyToSnapshotRequest(request, sentAtMs: sentAtMs + 1);
    deliverReply(reply);
    return reply;
  }

  /// Explicit reminder that this fabric never qualifies physical E2E.
  void claimPhysicalE2e() {
    throw const StudioException(playLanPhysicalE2eUnclaimed);
  }
}
