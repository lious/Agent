import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_peer_ui/studio_peer_ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real native UI + encrypted OS keyring: pair, same-session local/remote CPU, separately approved blob, revoke; same host only',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('peer-ui-native-');
      var workspace = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'peer_ui_test',
          region: 'local',
          features: {'project.metadata'},
        ),
        databasePath: '${root.path}/db',
        tenantId: 'synthetic',
        workspaceId: 'isolated',
      );
      workspace.openDemo();
      final scope = 'integration-${DateTime.now().microsecondsSinceEpoch}',
          bytes = Uint8List.fromList(
            List.generate(131085, (i) => (i * 19) % 251),
          ),
          source = File('${root.path}/explicit-synthetic-input.bin');
      source.writeAsBytesSync(bytes);
      final hash = rawBytesHash(bytes).substring(7);
      final worker = await NativeIdentity.open(
        storageScope: '$scope-worker',
        lockPath: '${root.path}/worker.lock',
        bindAddress: '127.0.0.1',
      );
      final reopened = await NativeIdentity.open(
        storageScope: '$scope-worker',
        lockPath: '${root.path}/worker.lock',
        bindAddress: '127.0.0.1',
      );
      expect(worker.fingerprint, reopened.fingerprint);
      expect(jsonEncode(worker.publicOffer()).contains('PRIVATE KEY'), isFalse);
      Widget panel(String who) => Expanded(
        child: SingleChildScrollView(
          child: PeerPanel(
            key: ValueKey(who),
            storageScope: '$scope-$who',
            lockPath: '${root.path}/$who.lock',
            createSession: workspace.createMetadataComputeSession,
            listRecovery: workspace.recoverableMetadataSessions,
            recoverSession: workspace.recoverMetadataSession,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Row(children: [panel('host'), panel('worker')])),
        ),
      );
      Finder field(String who, String key) => find.descendant(
        of: find.byKey(ValueKey(who)),
        matching: find.byKey(Key(key)),
      );
      Future<void> click(String who, String key) async {
        final f = field(who, key);
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      Future<void> enter(String who, String key, String value) async {
        final f = field(who, key);
        await tester.ensureVisible(f);
        // The binding caches focusedEditable even after a native control takes
        // focus. Reset that test-driver cache so re-entering the SAME field
        // establishes a fresh input connection instead of dropping the edit.
        FocusManager.instance.primaryFocus?.unfocus();
        tester.binding.focusedEditable = null;
        await tester.pumpAndSettle();
        await tester.enterText(f, value);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(f).controller!.text, value);
      }

      String text(String who) =>
          tester.widget<TextField>(field(who, 'peer-public')).controller!.text;
      Future<void> waitReady(String who) async {
        for (var i = 0; i < 300 && text(who).isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(text(who), isNotEmpty);
      }

      for (final who in ['host', 'worker']) {
        await tester.tap(
          find.descendant(
            of: find.byKey(ValueKey(who)),
            matching: find.text('Trusted peer session · Linux preview'),
          ),
        );
        await tester.pumpAndSettle();
        await click(who, 'peer-identity');
        await waitReady(who);
      }
      final host = jsonDecode(text('host')) as Map<String, dynamic>;
      expect(host.containsKey('privateKeyPem'), isFalse);
      await enter('worker', 'peer-file', source.path);
      await click('worker', 'peer-blob-prepare');
      final offer = jsonDecode(text('worker')) as Map<String, dynamic>;
      expect(offer['blobOffer']['hash'], hash);
      expect(offer.toString().contains(source.path), isFalse);
      await enter('host', 'peer-paste', text('worker'));
      await enter('host', 'peer-confirm', worker.fingerprint);
      await click('host', 'peer-host');
      expect(find.text('PEER_EXPLICIT_CONSENT_REQUIRED'), findsOneWidget);
      await click('host', 'peer-consent');
      await enter('host', 'peer-confirm', '0' * 64);
      expect(
        tester
            .widget<TextField>(field('host', 'peer-confirm'))
            .controller!
            .text,
        '0' * 64,
      );
      await click('host', 'peer-host');
      expect(
        tester
            .widget<TextField>(field('host', 'peer-confirm'))
            .controller!
            .text,
        '0' * 64,
      );
      expect(
        tester.widget<Text>(field('host', 'peer-status')).data,
        'PAIRING_CONFIRMATION_MISMATCH',
      );
      await enter('host', 'peer-confirm', worker.fingerprint);
      await click('host', 'peer-blob-consent');
      await click('host', 'peer-host');
      for (
        var i = 0;
        i < 100 && !text('host').contains('granteeFingerprint');
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final invitation = jsonDecode(text('host')) as Map<String, dynamic>;
      expect(invitation['allowedBlobs'][hash], bytes.length);
      await enter('worker', 'peer-paste', text('host'));
      await enter('worker', 'peer-confirm', host['fingerprint'] as String);
      await click('worker', 'peer-consent');
      await click('worker', 'peer-work');
      for (
        var i = 0;
        i < 100 &&
            !tester
                .widget<Text>(field('worker', 'peer-status'))
                .data!
                .contains('Candidate persisted');
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester.widget<Text>(field('worker', 'peer-status')).data,
        contains('Candidate persisted'),
      );
      await click('worker', 'peer-blob-upload');
      for (
        var i = 0;
        i < 100 &&
            !tester
                .widget<Text>(field('worker', 'peer-status'))
                .data!
                .contains('inbox committed');
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester.widget<Text>(field('worker', 'peer-status')).data,
        contains('inbox committed'),
      );
      expect(workspace.receivedPeerBlob(hash), orderedEquals(bytes));
      await click('host', 'peer-local');
      for (
        var i = 0;
        i < 100 &&
            !tester
                .widget<Text>(field('host', 'peer-status'))
                .data!
                .contains('Local digest-1');
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester.widget<Text>(field('host', 'peer-status')).data,
        contains('digest-1: committed'),
      );
      expect(workspace.current.revision, BigInt.zero);
      await click('host', 'peer-revoke');
      expect(
        tester.widget<Text>(field('host', 'peer-status')).data,
        contains('Grant revoked'),
      );
      // Explicit re-pair creates a NEW authority scope, never resurrects old grant.
      await click('host', 'peer-host');
      for (var i = 0; i < 100 && text('host') == jsonEncode(invitation); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final replacement = jsonDecode(text('host')) as Map<String, dynamic>;
      expect(replacement['sessionId'], isNot(invitation['sessionId']));
      await click('host', 'peer-revoke');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      workspace.close();
      workspace = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'peer_ui_test',
          region: 'local',
          features: {'project.metadata'},
        ),
        databasePath: '${root.path}/db',
        tenantId: 'synthetic',
        workspaceId: 'isolated',
      );
      workspace.openDemo();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Row(children: [panel('host')])),
        ),
      );
      await tester.tap(find.text('Trusted peer session · Linux preview'));
      await tester.pumpAndSettle();
      await click('host', 'peer-identity');
      await waitReady('host');
      expect(
        (jsonDecode(text('host')) as Map)['fingerprint'],
        host['fingerprint'],
      );
      await click('host', 'peer-list-recovery');
      final chosen = jsonDecode(
        tester
            .widget<TextField>(field('host', 'peer-recovery-choice'))
            .controller!
            .text,
      ) as Map;
      expect(chosen['sessionId'], replacement['sessionId']);
      await click('host', 'peer-recover');
      expect(
        tester.widget<Text>(field('host', 'peer-status')).data,
        'RECOVERY_EXPLICIT_CONSENT_REQUIRED',
      );
      await click('host', 'peer-recovery-consent');
      await click('host', 'peer-recover');
      expect(
        tester.widget<Text>(field('host', 'peer-status')).data,
        contains('Recovered SAME session ${replacement['sessionId']}'),
      );
      expect(
        tester.widget<Text>(field('host', 'peer-status')).data,
        contains('No listener'),
      );
      await click('host', 'peer-local');
      for (
        var i = 0;
        i < 100 &&
            !tester
                .widget<Text>(field('host', 'peer-status'))
                .data!
                .contains('digest-1: committed');
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester.widget<Text>(field('host', 'peer-status')).data,
        contains('digest-1: committed'),
      );
      await click('host', 'peer-revoke');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      workspace.close();
      root.deleteSync(recursive: true);
    },
  );
}
