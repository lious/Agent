@TestOn('browser')
library;

import 'dart:convert';
import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:flutter_test/flutter_test.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:studio_harness/builtin_compute.dart';
import 'package:studio_web/rtc_peer.dart';
import 'package:studio_web/browser_store.dart';
import 'package:studio_web/browser_compute.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));
void main() {
  test('REAL Chrome RTCCertificate structured-clone IDB identity persists across racing creators/reopen', () async {
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
  test('REAL Chrome direct-only preflight NEVER falls back when host candidates are policy-suppressed; pure pin/relay admission', () async {
    final link = RtcPeerLink(await RtcIdentity.loadOrCreate(newPeerId()));
    try {
      try {
        final offer = await link.createOffer();
        expect(offer['fingerprint'], link.identity.fingerprint);
        expect(link.diagnostics['localHostCandidates'], greaterThan(0));
      } on StudioException catch (e) {
        expect(e.code, 'RTC_DIRECT_CANDIDATES_UNAVAILABLE');
        expect(link.diagnostics['localHostCandidates'], 0);
        expect(link.diagnostics['closed'], isTrue);
      }
      expect(link.usesNoIceServers, isTrue);
      final fp = link.identity.fingerprint;
      final synthetic = {
        'protocolVersion': 'studio-rtc-1',
        'type': 'offer',
        'fingerprint': fp,
        'sdp':
            'm=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\na=fingerprint:sha-256 $fp\r\n',
      };
      expect(
        () => RtcPeerLink.verifyDescription(
          {...synthetic, 'fingerprint': null},
          fp,
          'offer',
        ),
        code('RTC_PROTOCOL'),
      );
      expect(
        () => RtcPeerLink.verifyDescription(synthetic, '0' * 64, 'offer'),
        code('RTC_FINGERPRINT_MISMATCH'),
      );
      expect(
        () => RtcPeerLink.verifyDescription(
          {
            ...synthetic,
            'sdp':
                '${synthetic['sdp']}a=candidate:1 1 UDP 123 127.0.0.1 9 typ relay\r\n',
          },
          fp,
          'offer',
        ),
        code('RTC_DIRECT_ONLY_REQUIRED'),
      );
    } finally {
      link.close();
    }
  });
  test('REAL Chrome IDB ORIGINAL Harness adapter (NOT transport qualification): lease/receipt/result/outbox/revision/revoke/rollback/reopen', () async {
    final ns = Namespace('studio', 'local', 'web'), name = newPeerId();
    var store = await BrowserProjectStore.open(name, ns);
    await store.openProject(
      ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'owner'),
    );
    final owner = await RtcIdentity.loadOrCreate(newPeerId()),
        worker = await RtcIdentity.loadOrCreate(newPeerId());
    final c = await BrowserComputeCoordinator.create(
      store,
      'p',
      owner.fingerprint,
    );
    await expectLater(
      c.approve(worker.fingerprint, metadataConsent: false),
      code('PEER_EXPLICIT_CONSENT_REQUIRED'),
    );
    await c.approve(worker.fingerprint, metadataConsent: true);
    Map<String, dynamic> req(
      String id,
      String operation,
      Map<String, dynamic> payload,
    ) => {
      'schemaVersion': '1.0.0',
      'id': id,
      'sessionId': c.id,
      'planHash': c.plan.hash,
      'epoch': '1',
      'nodeId': 'digest-0',
      'operation': operation,
      'payload': payload,
    };
    await expectLater(
      c.executePeerRequest('0' * 64, req('bad', 'claim', {'leaseMs': 1000})),
      code('PEER_NOT_AUTHORIZED'),
    );
    final claimRequest = req('claim', 'claim', {'leaseMs': 1000}),
        claim = await c.executePeerRequest(worker.fingerprint, claimRequest);
    final lease = taskLeaseFromJson(
      Map<String, dynamic>.from(claim['lease'] as Map),
    );
    expect(lease.planHash, c.plan.hash);
    await expectLater(
      c.executePeerRequest(
        worker.fingerprint,
        req('claim-conflict', 'claim', {'leaseMs': 1000}),
      ),
      code('LEASE_BUSY'),
    );
    expect(
      (await c.executePeerRequest(
        worker.fingerprint,
        claimRequest,
      ))['contentHash'],
      claim['contentHash'],
    );
    final result = BuiltinCompute.execute(
      Map<String, dynamic>.from(claim['handlerPin'] as Map),
      claim['input'],
    );
    final finish = req('finish', 'finish', {
      'lease': claim['lease'],
      'result': result,
      'resultHash': harnessHash(result),
    });
    final receipt = await c.executePeerRequest(worker.fingerprint, finish);
    expect(await c.executePeerRequest(worker.fingerprint, finish), receipt);
    await c.runLocal();
    final state = await c.status();
    expect(state['outbox'], hasLength(2));
    expect((await store.read('p')).revision, BigInt.zero);
    await expectLater(
      store.peerTransaction('p', (_, r) {
        (r['sessions'] as Map).clear();
        throw const StudioException('INJECTED_TRANSACTION_ABORT');
      }),
      code('INJECTED_TRANSACTION_ABORT'),
    );
    expect((await c.status())['outbox'], state['outbox']);
    await c.revoke();
    await expectLater(c.runLocal(), code('PEER_NOT_AUTHORIZED'));
    await expectLater(
      c.executePeerRequest(worker.fingerprint, finish),
      code('PEER_NOT_AUTHORIZED'),
    );
    final saved = jsonEncode(await c.status());
    store.close();
    store = await BrowserProjectStore.open(name, ns);
    final reopened = await store.peerTransaction(
      'p',
      (_, r) => Map<String, dynamic>.from((r['sessions'] as Map)[c.id] as Map),
    );
    expect(jsonEncode(reopened), saved);
    store.close();
  });
  test('REAL Chrome IDB lease expiry/retry fence, cross-session resource reservation, heartbeat regression and result rollback (NOT transport)', () async {
    final ns = Namespace('studio', 'local', 'leases');
    final store = await BrowserProjectStore.open(newPeerId(), ns);
    try {
      await store.openProject(
        ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'fences'),
      );
      final owner = (await RtcIdentity.loadOrCreate(newPeerId())).fingerprint,
          peer = (await RtcIdentity.loadOrCreate(newPeerId())).fingerprint;
      final a = await BrowserComputeCoordinator.create(store, 'p', owner),
          b = await BrowserComputeCoordinator.create(store, 'p', owner);
      await a.approve(peer, metadataConsent: true);
      await b.approve(peer, metadataConsent: true);
      Map<String, dynamic> req(
        BrowserComputeCoordinator c,
        String op,
        Map<String, dynamic> payload,
      ) => {
        'schemaVersion': '1.0.0',
        'id': newPeerId(),
        'sessionId': c.id,
        'planHash': c.plan.hash,
        'epoch': '1',
        'nodeId': 'digest-0',
        'operation': op,
        'payload': payload,
      };
      final first = await a.executePeerRequest(
        peer,
        req(a, 'claim', {'leaseMs': 1000}),
      );
      await expectLater(
        b.executePeerRequest(peer, req(b, 'claim', {'leaseMs': 1000})),
        code('DEVICE_RESOURCE_QUARANTINED'),
      );
      final result = BuiltinCompute.execute(
        Map<String, dynamic>.from(first['handlerPin'] as Map),
        first['input'],
      );
      Map<String, dynamic> finish(Object lease, String hash) => {
        'lease': lease,
        'result': result,
        'resultHash': hash,
      };
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await expectLater(
        a.executePeerRequest(
          peer,
          req(a, 'finish', finish(first['lease'], harnessHash(result))),
        ),
        code('LEASE_FENCED'),
      );
      final next = await a.executePeerRequest(
        peer,
        req(a, 'claim', {'leaseMs': 1000}),
      );
      expect(
        BigInt.parse(next['lease']['fence']),
        greaterThan(BigInt.parse(first['lease']['fence'])),
      );
      await expectLater(
        a.executePeerRequest(
          peer,
          req(a, 'finish', finish(first['lease'], harnessHash(result))),
        ),
        code('LEASE_FENCED'),
      );
      final beat = await a.executePeerRequest(
        peer,
        req(a, 'heartbeat', {
          'lease': next['lease'],
          'progress': 0.5,
          'extendMs': 1000,
        }),
      );
      await expectLater(
        a.executePeerRequest(
          peer,
          req(a, 'heartbeat', {
            'lease': beat['lease'],
            'progress': 0.4,
            'extendMs': 1000,
          }),
        ),
        code('LEASE_PROGRESS_INVALID'),
      );
      await expectLater(
        a.executePeerRequest(
          peer,
          req(a, 'finish', finish(beat['lease'], '0' * 64)),
        ),
        code('COMPUTE_RESULT_HASH'),
      );
      expect((await a.status())['outbox'], isEmpty);
      await a.executePeerRequest(
        peer,
        req(a, 'finish', finish(beat['lease'], harnessHash(result))),
      );
      expect((await a.status())['outbox'], hasLength(1));
      final second = await b.executePeerRequest(
        peer,
        req(b, 'claim', {'leaseMs': 1000}),
      );
      expect(second['lease']['sessionId'], b.id);
      await b.revoke();
      await expectLater(
        b.executePeerRequest(
          peer,
          req(b, 'finish', finish(second['lease'], harnessHash(result))),
        ),
        code('PEER_NOT_AUTHORIZED'),
      );
    } finally {
      store.close();
    }
  });
  test('REAL Chrome additive IndexedDB v1 project fixture migrates to v2 without losing head and can commit peer runtime', () async {
    final name = newPeerId(), ns = Namespace('studio', 'local', 'idb-migrate');
    final project = ProjectDocument.empty(
      namespace: ns,
      projectId: 'p',
      title: 'legacy v1',
    );
    final opened = Completer<web.IDBDatabase>(),
        request = web.window.indexedDB.open(name, 1);
    request.onupgradeneeded = ((web.Event _) {
      (request.result as web.IDBDatabase).createObjectStore('projects');
    }).toJS;
    request.onsuccess = ((web.Event _) {
      opened.complete(request.result as web.IDBDatabase);
    }).toJS;
    request.onerror = ((web.Event _) {
      opened.completeError(StateError('legacy fixture open'));
    }).toJS;
    final db = await opened.future,
        done = Completer<void>(),
        tx = db.transaction('projects'.toJS, 'readwrite');
    tx
        .objectStore('projects')
        .put(
          jsonEncode({
            'format': 'browser-project-1',
            'head': project.toJson(),
            'headHash': project.hash,
            'versions': {},
            'receipts': {},
            'idCounter': '0',
          }).toJS,
          jsonEncode([ns.toJson(), 'p']).toJS,
        );
    tx.oncomplete = ((web.Event _) {
      done.complete();
    }).toJS;
    tx.onabort = ((web.Event _) {
      done.completeError(StateError('legacy fixture abort'));
    }).toJS;
    await done.future;
    db.close();
    final store = await BrowserProjectStore.open(name, ns);
    try {
      expect((await store.read('p')).hash, project.hash);
      final coordinator = await BrowserComputeCoordinator.create(
        store,
        'p',
        (await RtcIdentity.loadOrCreate(newPeerId())).fingerprint,
      );
      await coordinator.runLocal();
      expect((await coordinator.status())['outbox'], hasLength(1));
      expect((await store.read('p')).hash, project.hash);
    } finally {
      store.close();
    }
  });
}
