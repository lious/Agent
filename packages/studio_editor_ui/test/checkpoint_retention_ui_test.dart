import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  testWidgets(
    'REAL UI explicit retention configuration/dry-run/confirmation removes only reviewed recovery indexes',
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
      w.openDemo();
      for (var i = 0; i < 4; i++) {
        w.rename('Edit$i', expectedRevision: w.current.revision);
        w.flushCheckpoint();
      }
      final before = w.current;
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

      Future<void> realTap(String key) async {
        await locate(key);
        await tester.runAsync(() async {
          await tester.tap(find.byKey(Key(key)));
        });
        await tester.pump();
        for (
          var i = 0;
          i < 500 && find.byKey(const Key('media-busy')).evaluate().isNotEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(find.byKey(const Key('media-busy')), findsNothing);
        await tester.pumpAndSettle();
      }

      await tap('history-retention-panel');
      await locate('history-keep');
      await tester.enterText(find.byKey(const Key('history-keep')), '1');
      await tester.pump();
      await realTap('configure-history-retention');
      await realTap('review-history-retention');
      expect(find.textContaining('checkpoint INDEX rows;'), findsOneWidget);
      await locate('apply-history-retention');
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('apply-history-retention')),
            )
            .onPressed,
        isNull,
      );
      await tap('confirm-history-retention');
      await realTap('apply-history-retention');
      await locate('history-retention-review');
      expect(
        find.textContaining('Audited checkpoint index removal:'),
        findsWidgets,
      );
      expect(w.current.hash, before.hash);
      await tester.runAsync(() async {
        expect((await w.reviewCheckpointRetention())['candidates'], isEmpty);
      });
      await locate('apply-history-retention');
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('apply-history-retention')),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
