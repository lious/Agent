import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  testWidgets(
    'REAL path: workbench import refuses overlapping SRT as CAPTION_OVERLAP and lists unsupported ASS style losses',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync(
        'caption-official-sidecar-ui-',
      );
      final w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata'},
        ),
        databasePath: '${dir.path}/db',
        tenantId: 'local',
        workspaceId: 'official-sidecar',
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      Future<void> settleImport() async {
        for (var i = 0; i < 40; i++) {
          if (find.byKey(const Key('error')).evaluate().isNotEmpty) {
            return;
          }
          final statusFinder = find.byKey(const Key('caption-export-status'));
          if (statusFinder.evaluate().isNotEmpty) {
            final data = tester.widget<Text>(statusFinder).data ?? '';
            if (data.startsWith('Imported')) {
              return;
            }
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump();
        }
      }

      await enter('caption-text', 'existing');
      await enter('caption-start', '0');
      await enter('caption-duration', '2000');
      await tap('caption-add');
      expect(w.current.revision, BigInt.one);
      expect(
        (w.current.toJson()['captions'] as List).single['text'],
        'existing',
      );

      final overlap = File('${dir.path}/overlap.srt')
        ..writeAsStringSync('1\n00:00:01,000 --> 00:00:03,000\nnew\n');
      await enter('caption-path', overlap.path);
      await tap('caption-import-srt');
      await settleImport();
      expect(find.byKey(const Key('error')), findsOneWidget);
      expect(find.text('CAPTION_OVERLAP'), findsOneWidget);
      expect(w.current.revision, BigInt.one);
      expect(
        (w.current.toJson()['captions'] as List).single['text'],
        'existing',
      );

      final styled = File('${dir.path}/styled.ass')
        ..writeAsStringSync(
          '[V4+ Styles]\n'
          'Format: Name, Fontname, Fontsize, PrimaryColour, Bold, Alignment\n'
          'Style: Title,StudioTestNoto,72,&H000000FF,1,8\n\n'
          '[Events]\n'
          'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n'
          'Dialogue: 0,0:00:02.00,0:00:03.00,Title,,0,0,0,,你好🙂\\Nשלום\n',
        );
      await enter('caption-ass-font', 'StudioTestNoto');
      await enter('caption-ass-available', 'StudioTestNoto');
      await enter('caption-path', styled.path);
      await tap('caption-import-ass');
      await settleImport();
      expect(find.byKey(const Key('error')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('caption-export-status')),
      );
      final status = tester
          .widget<Text>(find.byKey(const Key('caption-export-status')))
          .data!;
      expect(status, contains('ASS_STYLE_FIELDS_DROPPED'));
      expect(status, contains('ASS_STYLE_FONT_NOT_RENDERED'));
      expect(
        (w.current.toJson()['captions'] as List).map((c) => c['text']),
        containsAll(['existing', '你好🙂\nשלום']),
      );
    },
  );
}
