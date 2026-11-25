import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  testWidgets(
    'REAL UI explicit storage policy applies byte cap and rejects over-budget import without deleting data',
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

      await tap('storage-budget-panel');
      await locate('storage-byte-limit');
      await tester.enterText(
        find.byKey(const Key('storage-byte-limit')),
        '20000',
      );
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('apply-storage-policy')),
            )
            .onPressed,
        isNull,
      );
      await tap('confirm-storage-policy');
      await locate('apply-storage-policy');
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('apply-storage-policy')));
        final until = DateTime.now().add(const Duration(seconds: 10));
        while (w.namespaceStorageInventory()['policy']['casFileByteLimit'] !=
                '20000' &&
            DateTime.now().isBefore(until)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(
        w.namespaceStorageInventory()['policy']['casFileByteLimit'],
        '20000',
      );
      expect(
        w.namespaceStorageInventory()['policy']['retention'],
        'preserveAll',
      );
      expect(w.current.hash, before.hash);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('confirm-storage-policy')),
            )
            .value,
        false,
      );
      await tester.runAsync(() async {
        await expectLater(
          w.importVideo(
            LocalFileGrant.fromUserSelection(
              File(Platform.environment['STUDIO_TEST_VIDEO']!),
            ),
            expectedRevision: w.current.revision,
          ),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'NAMESPACE_DISK_BUDGET_EXCEEDED',
            ),
          ),
        );
      });
      expect(w.current.hash, before.hash);
      await tap('refresh-storage-inventory');
      expect(find.textContaining('namespace file bytes;'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
