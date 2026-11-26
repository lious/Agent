import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);

void main() {
  testWidgets(
    'REAL path: extract, split, overwrite-move a left cue onto a dest remnant, undo/archive/sidecar, no MP4',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('caption-overwrite-ui-');
      final workspace = openMoveWorkspace(dir);
      addTearDown(() async {
        workspace.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1100, 1900));
      await tester.runAsync(() async {
        workspace.openDemo();
        final av = File('${dir.path}/av.mp4');
        final made = await Process.run('ffmpeg', [
          '-v',
          'error',
          '-i',
          Platform.environment['STUDIO_TEST_VIDEO']!,
          '-f',
          'lavfi',
          '-i',
          'sine=frequency=997:sample_rate=44100:duration=3',
          '-map',
          '0:v:0',
          '-map',
          '1:a:0',
          '-c:v',
          'copy',
          '-c:a',
          'aac',
          av.path,
        ]);
        if (made.exitCode != 0) throw StateError('${made.stderr}');
        await workspace.importVideo(
          LocalFileGrant.fromUserSelection(av),
          expectedRevision: workspace.current.revision,
          acknowledgeVideoOnly: true,
        );
      });
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

      final video = moveVideos(workspace.current).first['id'] as String;
      await tap('clip-$video');
      await tester.pumpAndSettle();
      await tap('extract-persistent-audio');
      await tester.pumpAndSettle();
      expect(workspace.current.toJson()['linkGroups'], isNotEmpty);
      await tap('clip-$video');
      await tester.pumpAndSettle();
      await enter('edit-frames', '30');
      await tester.pumpAndSettle();
      await tap('split');
      await tester.pumpAndSettle();
      expect(moveVideos(workspace.current), hasLength(2));

      await tap('clip-$video');
      await tester.pumpAndSettle();
      await tap('caption-panel');
      await tester.pumpAndSettle();
      await enter('caption-text', 'hello');
      await enter('caption-start', '0');
      await enter('caption-duration', '500');
      await tap('caption-add');
      await enter('caption-text', 'carved');
      await enter('caption-start', '1500');
      await enter('caption-duration', '200');
      await tap('caption-add');
      await enter('caption-text', 'stay');
      await enter('caption-start', '2000');
      await enter('caption-duration', '200');
      await tap('caption-add');
      expect(workspace.current.toJson()['captions'], hasLength(3));

      await tap('collision-mode-overwrite');
      await tester.pumpAndSettle();
      await tap('multi-select-$video');
      await tester.pumpAndSettle();
      await enter('edit-frames', '30');
      await tester.pumpAndSettle();
      await tap('preview-multi-right');
      await settleIO('multi-preview-busy');
      await tap('commit-multi-move');
      await tester.pumpAndSettle();
      expect(
        startOf(
          moveVideos(workspace.current).firstWhere((c) => c['id'] == video),
        ),
        Q.of(1),
      );
      expect(
        moveVideos(workspace.current).map((c) => startOf(c)),
        contains(Q.of(2)),
      );
      expect(
        (workspace.current.toJson()['captions'] as List)
            .map((c) => c['text'])
            .toSet(),
        {'hello', 'carved', 'stay'},
      );
      final captions = (workspace.current.toJson()['captions'] as List)
          .cast<Map>();
      expect(
        captions.singleWhere((c) => c['text'] == 'hello')['anchor']['kind'],
        'clipLocal',
      );
      expect(
        captions.singleWhere((c) => c['text'] == 'carved')['anchor']['kind'],
        'absolute',
      );
      expect(
        Q.fromJson(
          captions.singleWhere(
            (c) => c['text'] == 'stay',
          )['timelineRange']['start'],
        ),
        Q.of(2),
      );

      await tap('undo');
      await tester.pumpAndSettle();
      expect(workspace.current.toJson()['captions'], hasLength(3));
      expect(
        startOf(
          moveVideos(workspace.current).firstWhere((c) => c['id'] == video),
        ),
        Q.of(0),
      );
      await tap('redo');
      await tester.pumpAndSettle();
      expect(
        startOf(
          moveVideos(workspace.current).firstWhere((c) => c['id'] == video),
        ),
        Q.of(1),
      );

      final archive = File('${dir.path}/caption-overwrite.studio-project');
      await enter('archive-path', archive.path);
      await tap('save-archive');
      await settleIO('media-busy');
      final oldId = workspace.projectId;
      await tap('restore-archive');
      await settleIO('media-busy');
      expect(workspace.projectId, isNot(oldId));
      expect(
        (workspace.current.toJson()['captions'] as List)
            .map((c) => c['text'])
            .toSet(),
        {'hello', 'carved', 'stay'},
      );
      expect(
        moveVideos(workspace.current).map((c) => startOf(c)),
        containsAll([Q.of(1), Q.of(2)]),
      );

      final sidecar = File('${dir.path}/overwrite.vtt');
      await enter('caption-path', sidecar.path);
      await tap('caption-export-vtt');
      expect(sidecar.existsSync(), isTrue);
      expect(sidecar.readAsStringSync(), contains('hello'));
      expect(sidecar.readAsStringSync(), contains('stay'));
      await tester.runAsync(() async {
        await expectLater(
          workspace.previewTimelineAt(Q.of(0)),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'CAPTION_RENDER_POLICY_NOT_IMPLEMENTED',
            ),
          ),
        );
        await expectLater(
          workspace.exportVideo(File('${dir.path}/must-not.mp4')),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'CAPTION_RENDER_POLICY_NOT_IMPLEMENTED',
            ),
          ),
        );
      });
      expect(File('${dir.path}/must-not.mp4').existsSync(), isFalse);
    },
  );
}
