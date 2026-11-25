@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_web/browser_store.dart';
import 'package:studio_web/browser_compute.dart';
import 'package:studio_web/rtc_peer.dart';
import 'package:studio_web/peer_panel.dart';

void main() {
  testWidgets(
    'REAL Chrome clickable persistent identity, consent, direct-only preflight, local Harness receipt, revoke/reopen read-only (NOT positive transport)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 1800));
      late BrowserProjectStore store;
      late RtcIdentity remote;
      final identityName = newPeerId();
      await tester.runAsync(() async {
        store = await BrowserProjectStore.open(
          newPeerId(),
          Namespace('studio', 'local', 'panel'),
        );
        await store.openProject(
          ProjectDocument.empty(
            namespace: store.namespace,
            projectId: 'p',
            title: 'clickable',
          ),
        );
        remote = await RtcIdentity.loadOrCreate(newPeerId());
      });
      Widget app() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WebPeerPanel(
              store: store,
              projectId: 'p',
              identityDatabase: identityName,
            ),
          ),
        ),
      );
      String status() => tester
          .widget<SelectableText>(find.byKey(const Key('rtc-status')))
          .data!;
      Future<void> tap(String key, bool Function() done) async {
        final f = find.byKey(Key(key));
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pump();
        for (var i = 0; i < 600 && !done(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(done(), isTrue, reason: status());
      }

      try {
        await tester.pumpWidget(app());
        await tester.tap(find.byKey(const Key('web-peer-panel')));
        await tester.pumpAndSettle();
        await tap(
          'rtc-offer',
          () => status().contains('PEER_EXPLICIT_CONSENT_REQUIRED'),
        );
        await tap(
          'rtc-identity',
          () => status().contains('Browser identity loaded'),
        );
        final fp = tester
            .widget<SelectableText>(find.byKey(const Key('rtc-fingerprint')))
            .data;
        expect(fp, hasLength(64));
        await tester.enterText(
          find.byKey(const Key('rtc-confirmed-fingerprint')),
          remote.fingerprint,
        );
        await tester.tap(find.byKey(const Key('rtc-consent')));
        await tester.pump();
        await tap(
          'rtc-offer',
          () =>
              status().contains('RTC_DIRECT_CANDIDATES_UNAVAILABLE') ||
              status().contains('Owner offer ready'),
        );
        expect(status().contains('channel open'), isFalse);
        await tap(
          'rtc-run-local',
          () => status().contains('Local node committed SAME session'),
        );
        await tap('rtc-receipts', () => status().contains('candidates=1'));
        await tap(
          'rtc-revoke',
          () => status().contains('Grant durably revoked'),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app());
        await tester.tap(find.byKey(const Key('web-peer-panel')));
        await tester.pumpAndSettle();
        await tap(
          'rtc-identity',
          () => status().contains('Browser identity loaded'),
        );
        expect(
          tester
              .widget<SelectableText>(find.byKey(const Key('rtc-fingerprint')))
              .data,
          fp,
        );
        await tap(
          'rtc-history',
          () => status().contains('NO coordinator/permission resumed'),
        );
        expect(status(), contains('"revoked":true'));
        expect(status(), contains('"candidates":1'));
        await tap(
          'rtc-run-local',
          () => status().contains('RTC_SIGNALING_STATE'),
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        store.close();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );
}
