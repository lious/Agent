import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';

void main() {
  testWidgets(
    'REAL four-member checkbox move -> native ghost -> one undo/redo -> Escape/SQL/collision refusal -> archive fork MP4',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('multi-move-ui-');
      // Use an isolated namespace/root for every mutation and cleanup.
      final workspace = openMoveWorkspace(dir);
      addTearDown(() async {
        workspace.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1100, 1700));
      await tester.runAsync(() => installLinkedMoveFixture(workspace, dir));
      await tester.pumpWidget(FoundationApp(workspace: workspace));
      Future<void> locate(String key) async {
        final f = find.byKey(Key(key));
        if (f.evaluate().isEmpty) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pump();
          await tester.scrollUntilVisible(
            f,
            250,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 100,
          );
        }
        await Scrollable.ensureVisible(tester.element(f), alignment: .5);
        await tester.pumpAndSettle();
        expect(f.hitTestable(), findsOneWidget);
      }

      Future<void> tap(String key) async {
        await locate(key);
        await tester.tap(find.byKey(Key(key)));
        await tester.pump();
      }

      Future<void> enter(String key, String value) async {
        await locate(key);
        await tester.enterText(find.byKey(Key(key)), value);
      }

      Future<void> settleIO(String busy) async {
        for (var n = 0; n < 400; n++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 16));
          if (find.byKey(Key(busy)).evaluate().isEmpty) break;
        }
        expect(find.byKey(Key(busy)), findsNothing);
        await tester.pumpAndSettle();
      }

      Future<void> ghost() async {
        await tap('preview-multi-right');
        await settleIO('multi-preview-busy');
        expect(find.byKey(const Key('multi-ghost-preview')), findsOneWidget);
      }

      final selected = moveVideos(workspace.current)
          .map((c) => c['id'] as String)
          .toList();
      for (final id in selected) {
        await tap('multi-select-$id');
      }
      debugPrint('multi-move-ui: selection ready');
      final before = workspace.current;
      await ghost();
      expect(workspace.current.hash, before.hash);
      await tap('commit-multi-move');
      expect(workspace.current.revision, before.revision + BigInt.one);
      final moved = workspace.current;
      await tap('undo');
      for (final c in moveVideos(workspace.current)) {
        expect(
          c['timelineRange']['start'],
          moveVideos(before)
              .singleWhere((x) => x['id'] == c['id'])['timelineRange']['start'],
        );
      }
      await tap('redo');
      expect(
        workspace.current.toJson()['sequences'],
        moved.toJson()['sequences'],
      );
      final frozen = workspace.current.hash;
      await ghost();
      await enter('edit-frames', '60');
      await tap('preview-multi-left');
      await tester.pumpAndSettle();
      expect(find.text('Multi-move: NEGATIVE_TIMELINE_START'), findsOneWidget);
      expect(find.byKey(const Key('multi-ghost-preview')), findsNothing);
      await tap('commit-multi-move');
      expect(workspace.current.hash, frozen);
      expect(find.byKey(const Key('multi-gesture-active')), findsOneWidget);
      await tap('cancel-multi-move');
      await enter('edit-frames', '30');
      await ghost();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(workspace.current.hash, frozen);
      expect(find.byKey(const Key('multi-gesture-active')), findsNothing);
      await ghost();
      final db = sqlite3.open('${dir.path}/db');
      db.execute(
        "CREATE TRIGGER multi_ui_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'multi UI fixture'); END",
      );
      try {
        await tap('commit-multi-move');
        expect(workspace.current.hash, frozen);
        expect(find.text('Multi-move: LOCAL_COMMIT_FAILED'), findsOneWidget);
      } finally {
        db.execute('DROP TRIGGER multi_ui_fail');
        db.dispose();
      }
      await tap('cancel-multi-move');
      await tap('clear-multi-selection');
      await tap('multi-select-${selected.last}');
      await tap('preview-multi-left');
      await tester.pumpAndSettle();
      expect(workspace.current.hash, frozen);
      expect(find.text('Multi-move: COLLISION'), findsOneWidget);
      expect(find.byKey(const Key('multi-gesture-active')), findsNothing);
      await tap('clear-multi-selection');
      debugPrint('multi-move-ui: atomic/error matrix done');
      final archive = File('${dir.path}/moved.studio-project');
      await enter('archive-path', archive.path);
      await tap('save-archive');
      await settleIO('media-busy');
      expect(
        workspace.persistence(target: archive).targetSavedRevision,
        workspace.current.revision,
      );
      final old = workspace.projectId;
      await tap('restore-archive');
      await settleIO('media-busy');
      expect(workspace.projectId, isNot(old));
      expect(workspace.canUndo, false);
      expect(workspace.canRedo, false);
      debugPrint('multi-move-ui: archive fork done');
      final output = File('${dir.path}/moved.mp4');
      await enter('export-path', output.path);
      await tap('export-video');
      await settleIO('media-busy');
      expect(output.existsSync(), true);
      expect(output.lengthSync(), greaterThan(1000));
      expect(find.byKey(const Key('error')), findsNothing);
      expect(tester.takeException(), isNull);
      debugPrint('multi-move-ui: MP4 done');
      // pumpWidget must run inside the live test binding, not test_api teardown.
      await tester.pumpWidget(const SizedBox());
      debugPrint('multi-move-ui: unmounted inside live binding');
      await tester.runAsync(
        () => workspace.closeAsync().timeout(const Duration(seconds: 5)),
      );
      debugPrint('multi-move-ui: archive queue drained and workspace closed');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
