import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';

void main() {
  testWidgets(
    'REAL ripple trim lengthen: one history, leave-gap still leaves duration, SQL/reopen/fork/AAC MP4',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync(
        'ripple-trim-lengthen-ui-',
      );
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
              break;
            }
            position.jumpTo(offset.clamp(0, position.maxScrollExtent));
            await tester.pump();
          }
        }
        if (f.evaluate().isNotEmpty) {
          await Scrollable.ensureVisible(
            tester.element(f),
            alignment: .5,
            duration: Duration.zero,
          );
          await tester.pump();
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

      Q durationOf(ProjectDocument p) =>
          Q.fromJson(p.toJson()['sequences'][0]['duration']);

      final ids = moveVideos(workspace.current)
          .map((c) => c['id'] as String)
          .toList();
      await enter('edit-frames', '15');
      await tap('clip-${ids.last}');
      final original = workspace.current;
      final oldDur = durationOf(original);
      await tap('trim');
      expect(workspace.current.revision, original.revision + BigInt.one);
      expect(durationOf(workspace.current), oldDur);
      await tap('undo');
      expect(
        workspace.current.toJson()['sequences'],
        original.toJson()['sequences'],
      );
      await tap('clip-${ids.first}');
      await tap('ripple-trim-out-lengthen');
      expect(workspace.current.revision, greaterThan(original.revision));
      expect(durationOf(workspace.current), oldDur + Q.of(1, 2));
      final trimmed = workspace.current;
      await tap('undo');
      expect(
        workspace.current.toJson()['sequences'],
        original.toJson()['sequences'],
      );
      await tap('redo');
      expect(
        workspace.current.toJson()['sequences'],
        trimmed.toJson()['sequences'],
      );
      final frozen = workspace.current.hash;
      final db = sqlite3.open('${dir.path}/db');
      db.execute(
        "CREATE TRIGGER rtl_ui_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      try {
        await tap('clip-${ids.first}');
        await tap('ripple-trim-out-lengthen');
        expect(workspace.current.hash, frozen);
        await locate('error');
        expect(find.text('LOCAL_COMMIT_FAILED'), findsOneWidget);
      } finally {
        db.execute('DROP TRIGGER rtl_ui_fail');
        db.dispose();
      }
      final archive = File('${dir.path}/ripple-trim-lengthen.studio-project');
      await enter('archive-path', archive.path);
      await tap('save-archive');
      await settleIO('media-busy');
      final old = workspace.projectId;
      await tap('restore-archive');
      await settleIO('media-busy');
      expect(workspace.projectId, isNot(old));
      final output = File('${dir.path}/ripple-trim-lengthen.mp4');
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
