import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  testWidgets(
    'REAL path: export ASS with declared script coverage lists a CJK/emoji/RTL substitute and does not write the Latin-only requested font',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync(
        'caption-font-coverage-ui-',
      );
      final w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata'},
        ),
        databasePath: '${dir.path}/db',
        tenantId: 'local',
        workspaceId: 'font-coverage',
      );
      addTearDown(() async {
        w.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1100, 2400));
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

      await enter('caption-text', '你好🙂 שלום');
      await enter('caption-start', '10');
      await enter('caption-duration', '1000');
      await tap('caption-add');
      expect(w.current.revision, BigInt.one);

      final output = File('${dir.path}/out.ass');
      await enter('caption-path', output.path);
      await enter('caption-ass-font', 'StudioTestSans');
      await enter('caption-ass-fallback', 'StudioTestNoto');
      await enter('caption-ass-available', 'StudioTestSans,StudioTestNoto');
      await enter('caption-ass-play-res', '1920x1080');
      await enter(
        'caption-ass-coverage',
        'StudioTestSans:Latn;StudioTestNoto:Latn,Han,Hebr,Arab,Zsye',
      );
      await tap('caption-export-ass');
      expect(find.byKey(const Key('error')), findsNothing);
      expect(output.existsSync(), isTrue);
      final text = output.readAsStringSync();
      expect(text, contains('Style: Default,StudioTestNoto,'));
      expect(text, isNot(contains('Style: Default,StudioTestSans,')));
      expect(text, contains('does not declare coverage of the sidecar text'));
      await tester.ensureVisible(
        find.byKey(const Key('caption-export-status')),
      );
      final status = tester
          .widget<Text>(find.byKey(const Key('caption-export-status')))
          .data!;
      expect(
        status,
        contains(
          'ASS_FONT_COVERAGE_SUBSTITUTED:StudioTestSans->StudioTestNoto:Han,Hebr,Zsye',
        ),
      );
      expect(status, contains('ASS_LAYOUT_MAY_CHANGE'));
      expect(
        CaptionFormats.decode(
          text,
          CaptionFormat.ass,
        ).captions.cues.single.text,
        '你好🙂 שלום',
      );
    },
  );
}
