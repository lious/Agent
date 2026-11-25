import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';

List<Map> audios(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    if (t['kind'] == 'audio')
      for (final c in t['items'])
        if (c['source'] != null) c as Map,
];

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);

void main() {
  testWidgets(
    'REAL ignore-links move: one history, partner stays, SQL/reopen/fork/AAC MP4',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('ignore-links-ui-');
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

      final firstVideo = moveVideos(workspace.current).first['id'] as String;
      final lastVideo = moveVideos(workspace.current).last['id'] as String;
      final lastAudio = audios(workspace.current).last['id'] as String;
      await tap('clear-multi-selection');
      await tap('multi-select-$lastVideo');
      await tap('move-ignore-links');
      await enter('edit-frames', '15');
      final original = workspace.current;
      await tap('preview-multi-right');
      await settleIO('multi-preview-busy');
      expect(find.byKey(const Key('multi-ghost-preview')), findsOneWidget);
      expect(workspace.current.hash, original.hash);
      await tap('commit-multi-move');
      expect(workspace.current.revision, greaterThan(original.revision));
      expect(
        startOf(
          moveVideos(workspace.current)
              .singleWhere((c) => c['id'] == lastVideo),
        ),
        Q.of(2),
      );
      expect(
        startOf(
          audios(workspace.current).singleWhere((c) => c['id'] == lastAudio),
        ),
        Q.of(3, 2),
      );
      expect(
        startOf(
          moveVideos(workspace.current)
              .singleWhere((c) => c['id'] == firstVideo),
        ),
        Q.of(0),
      );
      expect(
        (workspace.current.toJson()['linkGroups'] as List).singleWhere(
          (g) => (g['members'] as List).any((m) => m['clipId'] == lastVideo),
        )['syncPolicy'],
        'allowOutOfSync',
      );
      final moved = workspace.current;
      await tap('undo');
      expect(
        workspace.current.toJson()['sequences'],
        original.toJson()['sequences'],
      );
      expect(
        (workspace.current.toJson()['linkGroups'] as List).singleWhere(
          (g) => (g['members'] as List).any((m) => m['clipId'] == lastVideo),
        )['syncPolicy'],
        'preserve',
      );
      await tap('redo');
      expect(
        workspace.current.toJson()['sequences'],
        moved.toJson()['sequences'],
      );
      expect(
        (workspace.current.toJson()['linkGroups'] as List).singleWhere(
          (g) => (g['members'] as List).any((m) => m['clipId'] == lastVideo),
        )['syncPolicy'],
        'allowOutOfSync',
      );
      final frozen = workspace.current.hash;
      final db = sqlite3.open('${dir.path}/db');
      db.execute(
        "CREATE TRIGGER il_ui_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      try {
        await tap('clear-multi-selection');
        await tap('multi-select-$lastVideo');
        await tap('preview-multi-right');
        await settleIO('multi-preview-busy');
        await tap('commit-multi-move');
        expect(workspace.current.hash, frozen);
        expect(find.text('Multi-move: LOCAL_COMMIT_FAILED'), findsOneWidget);
      } finally {
        db.execute('DROP TRIGGER il_ui_fail');
        db.dispose();
      }
      await tap('cancel-multi-move');
      final archive = File('${dir.path}/ignore-links.studio-project');
      await enter('archive-path', archive.path);
      await tap('save-archive');
      await settleIO('media-busy');
      final old = workspace.projectId;
      await tap('restore-archive');
      await settleIO('media-busy');
      expect(workspace.projectId, isNot(old));
      final restoredLast = moveVideos(workspace.current).last['id'] as String;
      expect(
        (workspace.current.toJson()['linkGroups'] as List).singleWhere(
          (g) => (g['members'] as List).any((m) => m['clipId'] == restoredLast),
        )['syncPolicy'],
        'allowOutOfSync',
      );
      final output = File('${dir.path}/ignore-links.mp4');
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
