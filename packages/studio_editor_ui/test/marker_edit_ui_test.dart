import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);

Map markerOf(ProjectDocument p, [int index = 0]) =>
    (p.toJson()['markers'] as List).cast<Map>()[index];

void main() {
  testWidgets(
    'REAL add and follow a clipLocal marker: one history, SQL/reopen/fork/export',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('marker-edit-ui-');
      final workspace = openMoveWorkspace(dir);
      addTearDown(() async {
        workspace.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1100, 1900));
      await tester.runAsync(() => installLinkedMoveFixture(workspace, dir));
      await tester.pumpWidget(FoundationApp(workspace: workspace));
      await tester.pumpAndSettle();

      Future<void> locate(String key) async {
        final f = find.byKey(Key(key));
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byKey(const Key('foundation-scroll')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position;
        if (f.evaluate().isEmpty || f.hitTestable().evaluate().isEmpty) {
          var offset = 0.0;
          position.jumpTo(0);
          await tester.pump();
          while (f.evaluate().isEmpty || f.hitTestable().evaluate().isEmpty) {
            offset += 250;
            if (offset > position.maxScrollExtent + 1) {
              position.jumpTo(position.maxScrollExtent);
              await tester.pump();
              break;
            }
            position.jumpTo(offset.clamp(0, position.maxScrollExtent));
            await tester.pump();
          }
        }
        if (f.evaluate().isNotEmpty) {
          await tester.ensureVisible(f);
          await tester.pumpAndSettle();
        }
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

      final lastVideo = moveVideos(workspace.current).last['id'] as String;
      await tap('marker-panel');
      await tester.pumpAndSettle();
      await enter('marker-label', 'follows host');
      await enter('marker-time', '2000');
      await enter('marker-duration', '0');
      await tap('marker-add-anchored');
      await tester.pumpAndSettle();
      expect(workspace.current.toJson()['markers'], hasLength(1));
      expect(Q.fromJson(markerOf(workspace.current)['time']), Q.of(2));
      expect(markerOf(workspace.current)['anchor']['kind'], 'clipLocal');
      expect(markerOf(workspace.current)['anchor']['clipId'], lastVideo);
      await tap('multi-select-$lastVideo');
      await enter('edit-frames', '15');
      final original = workspace.current;
      await tap('preview-multi-right');
      await settleIO('multi-preview-busy');
      await tap('commit-multi-move');
      expect(workspace.current.revision, original.revision + BigInt.one);
      expect(startOf(moveVideos(workspace.current).last), Q.of(2));
      expect(Q.fromJson(markerOf(workspace.current)['time']), Q.of(5, 2));
      final moved = workspace.current;
      await tap('undo');
      expect(Q.fromJson(markerOf(workspace.current)['time']), Q.of(2));
      await tap('redo');
      expect(Q.fromJson(markerOf(workspace.current)['time']), Q.of(5, 2));
      expect(workspace.current.toJson()['markers'], moved.toJson()['markers']);
      final frozen = workspace.current.hash;
      await tap('clear-multi-selection');
      await tap('multi-select-$lastVideo');
      final db = sqlite3.open('${dir.path}/db');
      db.execute(
        "CREATE TRIGGER marker_ui_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      try {
        await enter('edit-frames', '15');
        await tap('preview-multi-right');
        await settleIO('multi-preview-busy');
        await tap('commit-multi-move');
        expect(workspace.current.hash, frozen);
        expect(find.text('Multi-move: LOCAL_COMMIT_FAILED'), findsOneWidget);
      } finally {
        db.execute('DROP TRIGGER marker_ui_fail');
        db.dispose();
      }
      await tap('cancel-multi-move');
      final archive = File('${dir.path}/markers.studio-project');
      await enter('archive-path', archive.path);
      await tap('save-archive');
      await settleIO('media-busy');
      final oldId = workspace.projectId;
      await tap('restore-archive');
      await settleIO('media-busy');
      expect(workspace.projectId, isNot(oldId));
      expect(Q.fromJson(markerOf(workspace.current)['time']), Q.of(5, 2));
      expect(markerOf(workspace.current)['anchor']['kind'], 'clipLocal');
      final output = File('${dir.path}/markers.mp4');
      await enter('export-path', output.path);
      await tap('export-video');
      await settleIO('media-busy');
      expect(output.lengthSync(), greaterThan(1000));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => workspace.closeAsync().timeout(const Duration(seconds: 5)),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
