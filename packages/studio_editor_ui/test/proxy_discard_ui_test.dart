import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  testWidgets(
    'REAL UI explicit selected proxy consent detaches references, resets consent and undo restores metadata',
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
      await locate('discard-selected-proxy');
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('discard-selected-proxy')),
            )
            .onPressed,
        isNull,
      );
      await tap('confirm-discard-proxy');
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('discard-selected-proxy')),
            )
            .onPressed,
        isNotNull,
      );
      await tap('discard-selected-proxy');
      expect(w.current.revision, before.revision + BigInt.one);
      expect(w.current.toJson()['assets'][0]['proxyRefs'], isEmpty);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('confirm-discard-proxy')),
            )
            .value,
        false,
      );
      await tap('undo');
      expect(w.current.toJson()['assets'][0]['proxyRefs'], hasLength(1));
      expect(
        w.current.toJson()['assets'][0]['originalBlobHash'],
        before.toJson()['assets'][0]['originalBlobHash'],
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
