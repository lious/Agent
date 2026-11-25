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
      Future<void> tap(String key) async {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await tester.pump();
      }

      Future<void> enter(String key, String text) async {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.enterText(find.byKey(Key(key)), text);
      }

      Future<void> asyncTap(String key, bool Function() done) async {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.runAsync(() async {
          await tester.tap(find.byKey(Key(key)));
          final until = DateTime.now().add(const Duration(seconds: 20));
          while (!done() && DateTime.now().isBefore(until)) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('error')), findsNothing);
        expect(done(), true, reason: '$key timed out');
      }

      await enter('import-path', Platform.environment['STUDIO_TEST_VIDEO']!);
      await asyncTap('import-video', () => w.current.revision == BigInt.one);
      final clips =
          w.current.toJson()['sequences'][0]['tracks'][0]['items'] as List;
      await tap('clip-${clips.first['id']}');
      await tap('split');
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
      expect(find.textContaining('explicit save 4'), findsOneWidget);
      final old = w.projectId;
      await asyncTap('restore-archive', () => w.projectId != old);
      final output = File('${dir.path}/ui.mp4');
      await enter('export-path', output.path);
      await asyncTap('export-video', output.existsSync);
      expect(find.textContaining('90 frames'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip:
        Platform.environment['STUDIO_MEDIA_LIBRARY'] == null ||
        Platform.environment['STUDIO_TEST_VIDEO'] == null,
  );
}
