import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';

void main() {
  testWidgets(
    'REAL internal copy/cut/paste/group: one history, refuse collision/SQL, reopen/fork/AAC MP4',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('clipboard-ui-');
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
        // Jump the page scroller. Do not drag: a drag through the pointer
        // timeline surface would steal the checkbox selection.
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

      final ids = moveVideos(workspace.current)
          .map((c) => c['id'] as String)
          .toList();
      await tap('multi-select-${ids.first}');
      await tap('multi-select-${ids.last}');
      final original = workspace.current;
      await tap('clipboard-copy');
      expect(workspace.current.hash, original.hash);
      expect(find.byKey(const Key('clipboard-status')), findsOneWidget);
      expect(find.textContaining('Internal clipboard sha256:'), findsOneWidget);
      await enter('clipboard-paste-at', '3');
      await tap('clipboard-paste');
      expect(workspace.current.revision, original.revision + BigInt.one);
      final pasted = workspace.current;
      await tap('undo');
      expect(
        workspace.current.toJson()['sequences'],
        original.toJson()['sequences'],
      );
      await tap('redo');
      expect(
        workspace.current.toJson()['sequences'],
        pasted.toJson()['sequences'],
      );
      await tap('clipboard-group');
      expect(workspace.current.toJson()['selectionGroups'], hasLength(1));
      await tap('clipboard-ungroup');
      expect(workspace.current.toJson()['selectionGroups'], isEmpty);
      final frozen = workspace.current.hash;
      await enter('clipboard-paste-at', '0');
      await tap('clipboard-paste');
      expect(workspace.current.hash, frozen);
      expect(find.text('Clipboard: COLLISION'), findsOneWidget);
      await enter('clipboard-paste-at', '6');
      final db = sqlite3.open('${dir.path}/db');
      db.execute(
        "CREATE TRIGGER clip_ui_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      try {
        await tap('clipboard-paste');
        expect(workspace.current.hash, frozen);
        expect(find.text('Clipboard: LOCAL_COMMIT_FAILED'), findsOneWidget);
      } finally {
        db.execute('DROP TRIGGER clip_ui_fail');
        db.dispose();
      }
      // UI maps raw exceptions; StudioException from store may be LOCAL_COMMIT_FAILED
      // or a raw code. Accept either honest refusal without a write.
      expect(workspace.current.hash, frozen);
      await tap('clear-multi-selection');
      await tap('multi-select-${ids.first}');
      final beforeCut = workspace.current;
      await tap('clipboard-cut');
      expect(workspace.current.revision, beforeCut.revision + BigInt.one);
      expect(
        moveVideos(workspace.current).where((c) => c['id'] == ids.first),
        isEmpty,
      );
      await tap('undo');
      expect(
        moveVideos(workspace.current).map((c) => c['id']).toList(),
        moveVideos(beforeCut).map((c) => c['id']).toList(),
      );
      final archive = File('${dir.path}/clipboard.studio-project');
      await enter('archive-path', archive.path);
      await tap('save-archive');
      await settleIO('media-busy');
      final old = workspace.projectId;
      await tap('restore-archive');
      await settleIO('media-busy');
      expect(workspace.projectId, isNot(old));
      expect(workspace.clipboard, isNull);
      await locate('clipboard-status');
      expect(find.textContaining('Internal clipboard empty'), findsOneWidget);
      final output = File('${dir.path}/clipboard.mp4');
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
