import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/dissolve_fixture.dart';

void main() {
  testWidgets(
    'REAL lumaWipe UI edit/preview/undo/archive/fork/export does not fall back to dissolve',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('luma-wipe-ui-');
      final w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${dir.path}/db.sqlite',
        tenantId: 'local',
        workspaceId: 'widget',
        mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
        mediaRootPath: '${dir.path}/media',
      );
      addTearDown(() async {
        w.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1100, 1700));
      await tester.runAsync(() => installDissolveFixture(w, dir));
      await tester.pumpWidget(FoundationApp(workspace: w));
      Future<void> locate(String key) async {
        if (find.byKey(Key(key)).evaluate().isEmpty) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pump();
          await tester.scrollUntilVisible(
            find.byKey(Key(key)),
            250,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 50,
          );
        }
        await Scrollable.ensureVisible(
          tester.element(find.byKey(Key(key))),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
      }

      Future<void> tap(String key) async {
        await locate(key);
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await tester.pump();
      }

      Future<void> enter(String key, String text) async {
        await locate(key);
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.enterText(find.byKey(Key(key)), text);
      }

      Future<void> asyncTap(String key, bool Function() done) async {
        await locate(key);
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.runAsync(() async {
          await tester.tap(find.byKey(Key(key)));
          final until = DateTime.now().add(const Duration(seconds: 20));
          while (!done() && DateTime.now().isBefore(until)) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        for (var n = 0; n < 200; n++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (find.byKey(const Key('media-busy')).evaluate().isEmpty) break;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        expect(find.byKey(const Key('media-busy')), findsNothing);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('error')), findsNothing);
        expect(done(), true, reason: '$key timed out');
      }

      final clips =
          w.current.toJson()['sequences'][0]['tracks'][0]['items'] as List;
      await tap('clip-${clips.first['id']}');
      await enter('luma-before', '6');
      await enter('luma-after', '6');
      await enter('luma-softness', '0.1');
      await asyncTap(
        'set-luma-wipe',
        () => lumaWipeEffects(w.current.toJson()).length == 1,
      );
      expect(w.current.toJson()['transitions'], isEmpty);
      await tap('clip-${clips[1]['id']}');
      await enter('opacity-keyframe-frame', '0');
      await asyncTap(
        'preview-clip-opacity',
        () => w.sourcePreviewCache.entries > 0,
      );
      await locate('source-preview');
      expect(
        tester
            .widget<RawImage>(find.byKey(const Key('source-preview')))
            .image!
            .width,
        128,
      );
      await tap('undo');
      expect(lumaWipeEffects(w.current.toJson()), isEmpty);
      await tap('clip-${clips.first['id']}');
      await asyncTap(
        'set-luma-wipe',
        () => lumaWipeEffects(w.current.toJson()).length == 1,
      );
      final archive = File('${dir.path}/ui.studio-project');
      await enter('archive-path', archive.path);
      await asyncTap(
        'save-archive',
        () =>
            w.persistence(target: archive).targetSavedRevision ==
            w.current.revision,
      );
      final old = w.projectId;
      await asyncTap('restore-archive', () => w.projectId != old);
      expect(lumaWipeEffects(w.current.toJson()), hasLength(1));
      expect(w.current.toJson()['transitions'], isEmpty);
      final output = File('${dir.path}/ui.mp4');
      await enter('export-path', output.path);
      await asyncTap('export-video', output.existsSync);
      expect(find.textContaining('60 frames'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip:
        Platform.environment['STUDIO_MEDIA_LIBRARY'] == null ||
        Platform.environment['STUDIO_TEST_VIDEO'] == null,
  );
}
