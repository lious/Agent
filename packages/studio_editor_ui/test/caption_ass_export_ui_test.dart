import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  testWidgets(
    'REAL path: add an emoji/RTL/newline cue, export ASS with a listed font substitute, keep policy-less export refused, no MP4 burn-in',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('caption-ass-export-ui-');
      final w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata'},
        ),
        databasePath: '${dir.path}/db',
        tenantId: 'local',
        workspaceId: 'ass-export',
      );
      addTearDown(() async {
        w.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1100, 2200));
      await tester.pumpWidget(FoundationApp(workspace: w));
      await tester.tap(find.byKey(const Key('caption-panel')));
      await tester.pumpAndSettle();
      Future<void> enter(String key, String value) async {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.enterText(find.byKey(Key(key)), value);
      }

      Future<void> tap(String key) async {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }

      await enter('caption-text', '你好🙂 שלום\nline');
      await enter('caption-start', '10');
      await enter('caption-duration', '1230');
      await tap('caption-add');
      expect(w.current.revision, BigInt.one);
      expect(w.current.toJson()['captions'][0]['text'], '你好🙂 שלום\nline');

      final output = File('${dir.path}/out.ass');
      await enter('caption-path', output.path);
      await tap('caption-export-ass');
      expect(find.byKey(const Key('error')), findsOneWidget);
      expect(find.text('ASS_EXPORT_FONT_POLICY_REQUIRED'), findsOneWidget);
      expect(output.existsSync(), false);

      await enter('caption-ass-font', 'MissingLicensedFont');
      await enter('caption-ass-fallback', 'StudioTestNoto');
      await enter('caption-ass-available', 'StudioTestNoto');
      await enter('caption-ass-play-res', '1920x1080');
      await tap('caption-export-ass');
      expect(find.byKey(const Key('error')), findsNothing);
      expect(output.existsSync(), isTrue);
      final text = output.readAsStringSync();
      expect(text, contains('StudioTestNoto'));
      expect(text, isNot(contains('Style: Default,MissingLicensedFont,')));
      expect(text, contains('requested MissingLicensedFont is unavailable'));
      await tester.ensureVisible(
        find.byKey(const Key('caption-export-status')),
      );
      final status = tester
          .widget<Text>(find.byKey(const Key('caption-export-status')))
          .data!;
      expect(
        status,
        contains('ASS_FONT_SUBSTITUTED:MissingLicensedFont->StudioTestNoto'),
      );
      expect(status, contains('ASS_LAYOUT_MAY_CHANGE'));
      final decoded = CaptionFormats.decode(text, CaptionFormat.ass);
      expect(decoded.captions.cues.single.text, '你好🙂 שלום\nline');
      expect(decoded.captions.cues.single.range.start, Q.of(1, 100));
      expect(decoded.captions.cues.single.range.end, Q.of(124, 100));
    },
  );
}
