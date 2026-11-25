import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);

String contents(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

void main() {
  testWidgets(
    'REAL opened-NLE undo: caption+marker+move, one history, archive/fork/sidecar, no MP4',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('nle-random-ui-');
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
      final origin = contents(workspace.current);
      await tap('caption-panel');
      await tester.pumpAndSettle();
      await enter('caption-text', 'random-undo');
      await enter('caption-start', '1500');
      await enter('caption-duration', '500');
      await tap('caption-add');
      expect(workspace.current.toJson()['captions'], hasLength(1));
      await tap('marker-panel');
      await tester.pumpAndSettle();
      await enter('marker-label', 'stay');
      await enter('marker-time', '250');
      await tap('marker-add');
      expect(workspace.current.toJson()['markers'], hasLength(1));
      expect(
        (workspace.current.toJson()['markers'] as List).first['anchor']['kind'],
        'absolute',
      );
      await tap('multi-select-$lastVideo');
      await enter('edit-frames', '15');
      final beforeMove = workspace.current.toJson();
      await tap('preview-multi-right');
      await settleIO('multi-preview-busy');
      await tap('commit-multi-move');
      expect(
        workspace.current.toJson()['sequences'],
        isNot(beforeMove['sequences']),
      );
      expect(startOf(moveVideos(workspace.current).last), Q.of(2));
      expect(
        Q.fromJson(
          workspace.current.toJson()['captions'][0]['timelineRange']['start'],
        ),
        Q.of(2),
      );
      // Absolute marker at 250ms stays put.
      expect(
        Q.fromJson(workspace.current.toJson()['markers'][0]['time']),
        Q.of(1, 4),
      );
      final moved = workspace.current.toJson();
      await tap('undo');
      await tester.pumpAndSettle();
      expect(workspace.current.toJson()['sequences'], beforeMove['sequences']);
      expect(workspace.current.toJson()['captions'], beforeMove['captions']);
      expect(workspace.current.toJson()['markers'], beforeMove['markers']);
      expect(
        Q.fromJson(
          workspace.current.toJson()['captions'][0]['timelineRange']['start'],
        ),
        Q.of(3, 2),
      );
      await tap('redo');
      await tester.pumpAndSettle();
      expect(workspace.current.toJson()['sequences'], moved['sequences']);
      expect(workspace.current.toJson()['captions'], moved['captions']);
      expect(workspace.current.toJson()['markers'], moved['markers']);
      final archive = File('${dir.path}/nle-random.studio-project');
      await enter('archive-path', archive.path);
      await tap('save-archive');
      await settleIO('media-busy');
      final oldId = workspace.projectId;
      await tap('restore-archive');
      await settleIO('media-busy');
      expect(workspace.projectId, isNot(oldId));
      expect(workspace.current.toJson()['captions'][0]['text'], 'random-undo');
      expect(
        workspace.current.toJson()['captions'][0]['anchor']['kind'],
        'clipLocal',
      );
      expect(
        Q.fromJson(
          workspace.current.toJson()['captions'][0]['timelineRange']['start'],
        ),
        Q.of(2),
      );
      expect(workspace.current.toJson()['markers'][0]['label'], 'stay');
      expect(
        Q.fromJson(workspace.current.toJson()['markers'][0]['time']),
        Q.of(1, 4),
      );
      expect(startOf(moveVideos(workspace.current).last), Q.of(2));
      final sidecar = File('${dir.path}/nle.vtt');
      await enter('caption-path', sidecar.path);
      await tap('caption-export-vtt');
      expect(sidecar.existsSync(), isTrue);
      expect(tester.takeException(), isNull);
      expect(origin, isNot(contents(workspace.current)));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => workspace.closeAsync().timeout(const Duration(seconds: 5)),
      );
    },
  );
}
