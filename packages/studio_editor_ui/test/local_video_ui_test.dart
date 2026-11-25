import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  testWidgets(
    'real native UI import split trim undo archive fork export',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('video-ui-');
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
        await tester.ensureVisible(find.byKey(Key(key)));
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
        // Codec completion can arrive after the SDK cache entry. Advance real
        // engine IO and widget frames instead of spinning fake time while the
        // indeterminate busy animation is still correctly active.
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

      await enter('import-path', Platform.environment['STUDIO_TEST_VIDEO']!);
      await asyncTap('import-video', () => w.current.revision == BigInt.one);
      final clips =
          w.current.toJson()['sequences'][0]['tracks'][0]['items'] as List;
      await tap('clip-${clips.first['id']}');
      await enter('preview-time-ms', '1500');
      await asyncTap(
        'seek-source-frame',
        () => w.sourcePreviewCache.entries == 1,
      );
      expect(find.byKey(const Key('source-preview')), findsOneWidget);
      // Status is below this lazily built ListView viewport. Verify the actual
      // decoded image rather than asserting text that has not been built.
      final shown = tester.widget<RawImage>(
        find.byKey(const Key('source-preview')),
      );
      expect(shown.image!.width, 128);
      expect(shown.image!.height, 72);
      await tap('split');
      expect(find.byKey(const Key('source-preview')), findsNothing);
      expect(w.current.revision, BigInt.two);
      await enter('edit-frames', '15');
      await tap('trim');
      expect(w.current.revision, BigInt.from(3));
      await tap('undo');
      expect(w.current.revision, BigInt.from(4));
      final archive = File('${dir.path}/ui.studio-project');
      await enter('archive-path', archive.path);
      await asyncTap(
        'save-archive',
        () =>
            w.persistence(target: archive).targetSavedRevision ==
            w.current.revision,
      );
      await locate('persistence-status');
      expect(find.textContaining('explicit save 4'), findsOneWidget);
      final old = w.projectId;
      await asyncTap('restore-archive', () => w.projectId != old);
      final output = File('${dir.path}/ui.mp4');
      await enter('export-path', output.path);
      await asyncTap('export-video', output.existsSync);
      await locate('operation-status');
      expect(find.textContaining('90 frames'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip:
        Platform.environment['STUDIO_MEDIA_LIBRARY'] == null ||
        Platform.environment['STUDIO_TEST_VIDEO'] == null,
  );
}
