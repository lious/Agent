import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);

Q durationOf(Map c) => Q.fromJson(c['timelineRange']['duration']);

Q sourceStartOf(Map c) => Q.fromJson(c['sourceRange']['start']);

Map videoOf(ProjectDocument p, String id) =>
    moveVideos(p).singleWhere((c) => c['id'] == id);

Map cueOf(ProjectDocument p, String text) => (p.toJson()['captions'] as List)
    .cast<Map>()
    .singleWhere((c) => c['text'] == text);

void main() {
  testWidgets(
    'REAL path: slip the left remnant +15 source frames through the Slip button, undo/archive/sidecar, no MP4',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('caption-slip-clip-ui-');
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
      await enter('edit-frames', '30');
      await tester.pumpAndSettle();
      await tap('split');
      await tester.pumpAndSettle();
      expect(moveVideos(workspace.current), hasLength(2));
      final right =
          moveVideos(workspace.current)
                  .singleWhere((c) => c['id'] != video)['id']
              as String;

      await tap('caption-panel');
      await tester.pumpAndSettle();
      await enter('caption-text', 'hello');
      await enter('caption-start', '0');
      await enter('caption-duration', '500');
      await tap('caption-add');
      await enter('caption-text', 'stay');
      await enter('caption-start', '1500');
      await enter('caption-duration', '500');
      await tap('caption-add');
      expect(workspace.current.toJson()['captions'], hasLength(2));

      await tap('clip-$video');
      await tester.pumpAndSettle();
      await enter('edit-frames', '15');
      await tester.pumpAndSettle();
      await tap('slip');
      await tester.pumpAndSettle();

      expect(
        workspace.commandLog.where((c) => c['kind'] == 'slipClip'),
        isNotEmpty,
      );
      expect(
        workspace.commandLog.where((c) => c['kind'] == 'moveClip'),
        isEmpty,
      );
      expect(startOf(videoOf(workspace.current, video)), Q.of(0));
      expect(durationOf(videoOf(workspace.current, video)), Q.of(1));
      expect(sourceStartOf(videoOf(workspace.current, video)), Q.of(1, 2));
      expect(startOf(videoOf(workspace.current, right)), Q.of(1));
      expect(durationOf(videoOf(workspace.current, right)), Q.of(2));
      expect(sourceStartOf(videoOf(workspace.current, right)), Q.of(1));
      expect(
        Q.fromJson(workspace.current.toJson()['sequences'][0]['duration']),
        Q.of(3),
      );
      expect(
        Q.fromJson(cueOf(workspace.current, 'hello')['timelineRange']['start']),
        Q.of(0),
      );
      expect(cueOf(workspace.current, 'hello')['anchor']['kind'], 'clipLocal');
      expect(
        Q.fromJson(cueOf(workspace.current, 'stay')['timelineRange']['start']),
        Q.of(3, 2),
      );
      expect(cueOf(workspace.current, 'stay')['anchor']['kind'], 'clipLocal');

      final slipped = workspace.current.toJson();
      await tap('undo');
      await tester.pumpAndSettle();
      expect(sourceStartOf(videoOf(workspace.current, video)), Q.of(0));
      expect(startOf(videoOf(workspace.current, video)), Q.of(0));
      expect(
        Q.fromJson(cueOf(workspace.current, 'hello')['timelineRange']['start']),
        Q.of(0),
      );
      await tap('redo');
      await tester.pumpAndSettle();
      expect(workspace.current.toJson()['sequences'], slipped['sequences']);
      expect(sourceStartOf(videoOf(workspace.current, video)), Q.of(1, 2));

      final archive = File('${dir.path}/caption-slip-clip.studio-project');
      await enter('archive-path', archive.path);
      await tap('save-archive');
      await settleIO('media-busy');
      final oldId = workspace.projectId;
      await tap('restore-archive');
      await settleIO('media-busy');
      expect(workspace.projectId, isNot(oldId));
      final videos = moveVideos(workspace.current);
      expect(videos, hasLength(2));
      final left = videos.singleWhere((c) => startOf(c) == Q.of(0));
      final restoredRight = videos.singleWhere((c) => startOf(c) == Q.of(1));
      expect(durationOf(left), Q.of(1));
      expect(sourceStartOf(left), Q.of(1, 2));
      expect(durationOf(restoredRight), Q.of(2));
      expect(sourceStartOf(restoredRight), Q.of(1));
      expect(
        (workspace.current.toJson()['captions'] as List)
            .map((c) => c['text'])
            .toSet(),
        {'hello', 'stay'},
      );
      expect(
        Q.fromJson(cueOf(workspace.current, 'hello')['timelineRange']['start']),
        Q.of(0),
      );
      expect(
        Q.fromJson(cueOf(workspace.current, 'stay')['timelineRange']['start']),
        Q.of(3, 2),
      );

      final sidecar = File('${dir.path}/caption-slip-clip.vtt');
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
