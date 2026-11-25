import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  testWidgets(
    'actual native Flutter caption add, manual edit, split, trim, SRT sidecar and durable reopen',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('caption-widget-');
      var w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata'},
        ),
        databasePath: '${dir.path}/db',
        tenantId: 'local',
        workspaceId: 'caps',
      );
      addTearDown(() async {
        w.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1100, 1800));
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
      await enter('caption-start', '101');
      await enter('caption-duration', '799');
      await tap('caption-add');
      expect(w.current.revision, BigInt.one);
      final cue = w.current.toJson()['captions'][0]['id'];
      await tap('cue-$cue');
      await enter('caption-text', 'manual\nline');
      await tap('caption-edit');
      await enter('caption-start', '500');
      await tap('caption-split');
      expect(w.current.toJson()['captions'], hasLength(2));
      await enter('caption-start', '200');
      await enter('caption-duration', '200');
      await tap('caption-trim');
      expect(
        w.current.toJson()['captions'][0]['timelineRange']['start'],
        Q.of(1, 5).toJson(),
      );
      final output = File('${dir.path}/out.srt');
      await enter('caption-path', output.path);
      await tap('caption-export-srt');
      expect(output.readAsStringSync(), contains('manual\nline'));
      expect(find.byKey(const Key('error')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      w.close();
      w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata'},
        ),
        databasePath: '${dir.path}/db',
        tenantId: 'local',
        workspaceId: 'caps',
      );
      w.openDemo();
      expect(w.current.toJson()['captions'], hasLength(2));
    },
  );
}
