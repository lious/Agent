import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);

Q cueStart(ProjectDocument p) =>
    Q.fromJson(p.toJson()['captions'][0]['timelineRange']['start']);

void main() {
  testWidgets(
    'REAL add cue on a covering clip defaults to clipLocal: one history, SQL/reopen/fork/sidecar',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync(
        'caption-default-cliplocal-ui-',
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
      await tap('caption-panel');
      await tester.pumpAndSettle();
      await enter('caption-text', 'follows host');
      await enter('caption-start', '1500');
      await enter('caption-duration', '500');
      await tap('caption-add');
      expect(workspace.current.toJson()['captions'], hasLength(1));
      expect(
        workspace.current.toJson()['captions'][0]['anchor']['kind'],
        'clipLocal',
      );
      expect(
        workspace.current.toJson()['captions'][0]['anchor']['clipId'],
        lastVideo,
      );
      expect(cueStart(workspace.current), Q.of(3, 2));
      await tap('multi-select-$lastVideo');
      await enter('edit-frames', '15');
      final original = workspace.current;
      await tap('preview-multi-right');
      await settleIO('multi-preview-busy');
      await tap('commit-multi-move');
      expect(workspace.current.revision, original.revision + BigInt.one);
      expect(startOf(moveVideos(workspace.current).last), Q.of(2));
      expect(cueStart(workspace.current), Q.of(2));
      final moved = workspace.current;
      await tap('undo');
      expect(cueStart(workspace.current), Q.of(3, 2));
      expect(
        workspace.current.toJson()['sequences'],
        original.toJson()['sequences'],
      );
      await tap('redo');
      expect(cueStart(workspace.current), Q.of(2));
      expect(
        workspace.current.toJson()['captions'],
        moved.toJson()['captions'],
      );
      final frozen = workspace.current.hash;
      await tap('clear-multi-selection');
      await tap('multi-select-$lastVideo');
      final db = sqlite3.open('${dir.path}/db');
      db.execute(
        "CREATE TRIGGER cap_default_ui_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      try {
        await enter('edit-frames', '15');
        await tap('preview-multi-right');
        await settleIO('multi-preview-busy');
        await tap('commit-multi-move');
        expect(workspace.current.hash, frozen);
        expect(find.text('Multi-move: LOCAL_COMMIT_FAILED'), findsOneWidget);
      } finally {
        db.execute('DROP TRIGGER cap_default_ui_fail');
        db.dispose();
      }
      await tap('cancel-multi-move');
      final archive = File('${dir.path}/caption-default.studio-project');
      await enter('archive-path', archive.path);
      await tap('save-archive');
      await settleIO('media-busy');
      final oldId = workspace.projectId;
      await tap('restore-archive');
      await settleIO('media-busy');
      expect(workspace.projectId, isNot(oldId));
      expect(cueStart(workspace.current), Q.of(2));
      expect(
        workspace.current.toJson()['captions'][0]['anchor']['kind'],
        'clipLocal',
      );
      final sidecar = File('${dir.path}/default.vtt');
      await enter('caption-path', sidecar.path);
      await tap('caption-export-vtt');
      expect(sidecar.existsSync(), isTrue);
      expect(
        CaptionFormats.decode(
          sidecar.readAsStringSync(),
          CaptionFormat.vtt,
        ).captions.cues.single.range.start,
        Q.of(2),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => workspace.closeAsync().timeout(const Duration(seconds: 5)),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
