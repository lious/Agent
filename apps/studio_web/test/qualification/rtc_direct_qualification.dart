@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_web/rtc_peer.dart';
import 'package:studio_web/browser_store.dart';
import 'package:studio_web/browser_compute.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));
Future<void> connect(RtcPeerLink owner, RtcPeerLink worker) async {
  final offer = await owner.createOffer();
  final answer = await worker.answer(
    offer,
    independentlyConfirmedFingerprint: owner.identity.fingerprint,
  );
  await owner.acceptAnswer(
    answer,
    independentlyConfirmedFingerprint: worker.identity.fingerprint,
  );
  await Future.wait([owner.waitReady(), worker.waitReady()]);
}

void main() {
  test('REAL Chrome nonexported RTC certificate survives IDB reopen and racing creators', () async {
    final name = newPeerId();
    final ids = await Future.wait([
      RtcIdentity.loadOrCreate(name),
      RtcIdentity.loadOrCreate(name),
    ]);
    expect(ids[0].fingerprint, ids[1].fingerprint);
    expect(
      (await RtcIdentity.loadOrCreate(name)).fingerprint,
      ids[0].fingerprint,
    );
  });
  test('REAL Chrome DTLS/SCTP wrong independent identity/tampered fingerprint/relay refusal and bounded RPC', () async {
    final a = RtcPeerLink(await RtcIdentity.loadOrCreate(newPeerId())),
        b = RtcPeerLink(await RtcIdentity.loadOrCreate(newPeerId()));
    try {
      a.onRequest = (fp, body) async => {'from': fp, 'value': body['value']};
      final offer = await a.createOffer();
      await expectLater(
        b.answer(offer, independentlyConfirmedFingerprint: '0' * 64),
        code('RTC_FINGERPRINT_MISMATCH'),
      );
      expect(b.remoteFingerprint, isNull);
      expect(
        () => RtcPeerLink.verifyDescription(
          {
            ...offer,
            'sdp': (offer['sdp'] as String).replaceFirst(
              'a=fingerprint:sha-256',
              'a=fingerprint:sha-1',
            ),
          },
          a.identity.fingerprint,
          'offer',
        ),
        code('RTC_FINGERPRINT_MISMATCH'),
      );
      expect(
        () => RtcPeerLink.verifyDescription(
          {
            ...offer,
            'sdp':
                '${offer['sdp']}a=candidate:1 1 UDP 123 127.0.0.1 9 typ relay\r\n',
          },
          a.identity.fingerprint,
          'offer',
        ),
        code('RTC_DIRECT_ONLY_REQUIRED'),
      );
      final answer = await b.answer(
        offer,
        independentlyConfirmedFingerprint: a.identity.fingerprint,
      );
      await a.acceptAnswer(
        answer,
        independentlyConfirmedFingerprint: b.identity.fingerprint,
      );
      try {
        await Future.wait([a.waitReady(), b.waitReady()]);
      } catch (e) {
        print(jsonEncode({'owner': a.diagnostics, 'worker': b.diagnostics}));
        rethrow;
      }
      expect(a.usesNoIceServers && b.usesNoIceServers, isTrue);
      expect(
        await b.request({'id': 'echo', 'value': 'actual encrypted data'}),
        {'from': b.identity.fingerprint, 'value': 'actual encrypted data'},
      );
      await expectLater(
        b.request({'id': 'too-large', 'value': 'x' * 65536}),
        code('RTC_BACKPRESSURE'),
      );
    } finally {
      a.close();
      b.close();
    }
  });
  test('REAL Chrome WebRTC SAME original PlanGraph remote/local tasks, persisted receipts/outbox, rollback/reopen/revoked replay', () async {
    final ns = Namespace('studio', 'local', 'web'), name = newPeerId();
    var store = await BrowserProjectStore.open(name, ns);
    await store.openProject(
      ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'owner'),
    );
    final a = RtcPeerLink(await RtcIdentity.loadOrCreate(newPeerId())),
        b = RtcPeerLink(await RtcIdentity.loadOrCreate(newPeerId()));
    final coordinator = await BrowserComputeCoordinator.create(
      store,
      'p',
      a.identity.fingerprint,
    );
    Map<String, dynamic>? finish;
    try {
      await expectLater(
        coordinator.approve(b.identity.fingerprint, metadataConsent: false),
        code('PEER_EXPLICIT_CONSENT_REQUIRED'),
      );
      await coordinator.approve(b.identity.fingerprint, metadataConsent: true);
      a.onRequest = (fp, body) {
        if (body['operation'] == 'finish') finish = body;
        return coordinator.executePeerRequest(fp, body);
      };
      await connect(a, b);
      await expectLater(
        runBrowserPeerDigest(
          b,
          coordinator.invitation(),
          operationId: 'denied',
          metadataConsent: false,
        ),
        code('PEER_EXPLICIT_CONSENT_REQUIRED'),
      );
      final result = await runBrowserPeerDigest(
        b,
        coordinator.invitation(),
        operationId: 'actual',
        metadataConsent: true,
      );
      expect(result['resultHash'], isA<String>());
      expect(await b.request(finish!), result);
      await coordinator.runLocal();
      final state = await coordinator.status();
      expect(
        (state['steps'] as Map).values.every(
          (v) => v['state']['status'] == 'committed',
        ),
        isTrue,
      );
      expect(state['outbox'], hasLength(2));
      expect((await store.read('p')).revision, BigInt.zero);
      await expectLater(
        store.peerTransaction('p', (_, r) {
          (r['sessions'] as Map).clear();
          throw const StudioException('INJECTED_TRANSACTION_ABORT');
        }),
        code('INJECTED_TRANSACTION_ABORT'),
      );
      expect((await coordinator.status())['outbox'], state['outbox']);
      await expectLater(
        b.request({
          ...finish!,
          'id': 'foreign-session',
          'sessionId': 'other-session',
        }),
        code('PEER_PROTOCOL_VERSION'),
      );
      await coordinator.revoke();
      await expectLater(b.request(finish!), code('PEER_NOT_AUTHORIZED'));
      final stored = jsonEncode(await coordinator.status());
      store.close();
      store = await BrowserProjectStore.open(name, ns);
      final reopened = await store.peerTransaction(
        'p',
        (_, r) => Map<String, dynamic>.from(
          (r['sessions'] as Map)[coordinator.id] as Map,
        ),
      );
      expect(jsonEncode(reopened), stored);
      expect(reopened['grant']['revoked'], isTrue);
    } finally {
      a.close();
      b.close();
      store.close();
    }
  });
}
