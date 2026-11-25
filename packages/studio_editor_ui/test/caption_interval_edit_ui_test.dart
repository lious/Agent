import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';

void main() {
  testWidgets(
    'REAL ripple close crops a spanning cue: one history, SQL/reopen/fork/sidecar',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('caption-interval-ui-');
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

      await tap('caption-panel');
      await tester.pumpAndSettle();
      await enter('caption-text', 'Span hole');
      await enter('caption-start', '0');
      await enter('caption-duration', '2000');
      await tap('caption-add');
      expect(workspace.current.toJson()['captions'], hasLength(1));
      expect(
        workspace.current.toJson()['captions'][0]['anchor']['kind'],
        'absolute',
      );
      final before = workspace.current;
      await enter('ripple-close-start', '0');
      await enter('ripple-close-duration', '1.5');
      await tap('ripple-close-range');
      await tester.pumpAndSettle();
      expect(workspace.current.revision, before.revision + BigInt.one);
      final cues = (workspace.current.toJson()['captions'] as List).cast<Map>();
      expect(cues, hasLength(1));
      expect(cues.single['text'], 'Span hole');
      expect(Q.fromJson(cues.single['timelineRange']['start']), Q.of(0));
      expect(Q.fromJson(cues.single['timelineRange']['duration']), Q.of(1, 2));
      await tap('undo');
      expect(
        Q.fromJson(
          workspace.current
              .toJson()['captions'][0]['timelineRange']['duration'],
        ),
        Q.of(2),
      );
      await tap('redo');
      expect(
        Q.fromJson(
          workspace.current
              .toJson()['captions'][0]['timelineRange']['duration'],
        ),
        Q.of(1, 2),
      );
      final frozen = workspace.current.hash;
      final db = sqlite3.open('${dir.path}/db');
      db.execute(
        "CREATE TRIGGER cap_interval_ui_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      try {
        await enter('ripple-close-start', '0');
        await enter('ripple-close-duration', '0.5');
        await tap('ripple-close-range');
        expect(workspace.current.hash, frozen);
        await locate('error');
        expect(find.text('LOCAL_COMMIT_FAILED'), findsOneWidget);
      } finally {
        db.execute('DROP TRIGGER cap_interval_ui_fail');
        db.dispose();
      }
      final archive = File('${dir.path}/caption-interval.studio-project');
      await enter('archive-path', archive.path);
      await tap('save-archive');
      await settleIO('media-busy');
      final oldId = workspace.projectId;
      await tap('restore-archive');
      await settleIO('media-busy');
      expect(workspace.projectId, isNot(oldId));
      expect(
        Q.fromJson(
          workspace.current
              .toJson()['captions'][0]['timelineRange']['duration'],
        ),
        Q.of(1, 2),
      );
      final sidecar = File('${dir.path}/interval.vtt');
      await enter('caption-path', sidecar.path);
      await tap('caption-export-vtt');
      expect(sidecar.existsSync(), isTrue);
      expect(
        CaptionFormats.decode(
          sidecar.readAsStringSync(),
          CaptionFormat.vtt,
        ).captions.cues.single.range.duration,
        Q.of(1, 2),
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
