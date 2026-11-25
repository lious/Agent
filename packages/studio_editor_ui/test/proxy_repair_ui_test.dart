import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  testWidgets(
    'REAL UI selected source-qualified repair restores corrupt CAS without changing project revision',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('discard-ui-');
      final w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${dir.path}/db',
        tenantId: 'local',
        workspaceId: 'discard-ui',
        mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
        mediaRootPath: '${dir.path}/media',
      );
      addTearDown(() async {
        w.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      await tester.runAsync(() async {
        w.openDemo();
        await w.importVideo(
          LocalFileGrant.fromUserSelection(
            File(Platform.environment['STUDIO_TEST_VIDEO']!),
          ),
          expectedRevision: w.current.revision,
        );
        await w.buildTimelinePreviewProxies();
      });
      final before = w.current;
      final ref = before.toJson()['assets'][0]['proxyRefs'][0];
      final raw = dir
          .listSync(recursive: true)
          .whereType<File>()
          .singleWhere(
            (f) =>
                f.uri.pathSegments.last ==
                (ref['blobHash'] as String).substring(7),
          );
      raw.writeAsBytesSync([1, 2, 3], flush: true);
      final clipId = before
          .toJson()['sequences'][0]['tracks'][0]['items'][0]['id'];
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
            300,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 50,
          );
        }
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }

      Future<void> tap(String key) async {
        await locate(key);
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }

      await tap('clip-$clipId');
      await locate('repair-selected-proxy');
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('repair-selected-proxy')),
            )
            .onPressed,
        isNull,
      );
      await tap('confirm-repair-proxy');
      await locate('repair-selected-proxy');
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('repair-selected-proxy')));
        final until = DateTime.now().add(const Duration(seconds: 20));
        while (rawBytesHash(raw.readAsBytesSync()) != ref['blobHash'] &&
            DateTime.now().isBefore(until)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (find.byKey(const Key('media-busy')).evaluate().isEmpty) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      expect(find.byKey(const Key('media-busy')), findsNothing);
      expect(find.byKey(const Key('error')), findsNothing);
      expect(rawBytesHash(raw.readAsBytesSync()), ref['blobHash']);
      expect(w.current.hash, before.hash);
      await locate('confirm-repair-proxy');
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('confirm-repair-proxy')),
            )
            .value,
        false,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
