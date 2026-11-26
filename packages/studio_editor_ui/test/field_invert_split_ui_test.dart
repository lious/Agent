import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);

Q durationOf(Map c) => Q.fromJson(c['timelineRange']['duration']);

void main() {
  testWidgets(
    'REAL path: invert split after moving an uninvolved remnant, undo/archive/sidecar, no MP4',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('invert-split-ui-');
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
      await enter('edit-frames', '60');
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
      await enter('caption-start', '2500');
      await enter('caption-duration', '500');
      await tap('caption-add');
      expect(workspace.current.toJson()['captions'], hasLength(2));

      await tap('clip-$video');
      await tester.pumpAndSettle();
      await enter('edit-frames', '30');
      await tester.pumpAndSettle();
      await tap('split');
      await tester.pumpAndSettle();
      expect(moveVideos(workspace.current), hasLength(3));
      final splitId = workspace.commandLog
          .where((c) => c['kind'] == 'splitClip')
          .last['id']!;

      await tap('clip-$right');
      await tester.pumpAndSettle();
      await enter('edit-frames', '30');
      await tester.pumpAndSettle();
      await tap('move');
      await tester.pumpAndSettle();
      expect(
        startOf(
          moveVideos(workspace.current).firstWhere((c) => c['id'] == right),
        ),
        Q.of(3),
      );
      expect(moveVideos(workspace.current), hasLength(3));

      await enter('invert-command-id', splitId);
      await tap('invert-command');
      await tester.pumpAndSettle();
      expect(moveVideos(workspace.current), hasLength(2));
      expect(
        startOf(
          moveVideos(workspace.current).firstWhere((c) => c['id'] == video),
        ),
        Q.of(0),
      );
      expect(
        durationOf(
          moveVideos(workspace.current).firstWhere((c) => c['id'] == video),
        ),
        Q.of(2),
      );
      expect(
        startOf(
          moveVideos(workspace.current).firstWhere((c) => c['id'] == right),
        ),
        Q.of(3),
      );
      final captions = (workspace.current.toJson()['captions'] as List)
          .cast<Map>();
      expect(
        Q.fromJson(
          captions.singleWhere(
            (c) => c['text'] == 'hello',
          )['timelineRange']['start'],
        ),
        Q.of(0),
      );
      expect(
        Q.fromJson(
          captions.singleWhere(
            (c) => c['text'] == 'stay',
          )['timelineRange']['start'],
        ),
        Q.of(7, 2),
      );

      await tap('undo');
      await tester.pumpAndSettle();
      expect(moveVideos(workspace.current), hasLength(3));
      expect(
        startOf(
          moveVideos(workspace.current).firstWhere((c) => c['id'] == right),
        ),
        Q.of(3),
      );
      await tap('redo');
      await tester.pumpAndSettle();
      expect(moveVideos(workspace.current), hasLength(2));
      expect(
        startOf(
          moveVideos(workspace.current).firstWhere((c) => c['id'] == right),
        ),
        Q.of(3),
      );

      final archive = File('${dir.path}/invert-split.studio-project');
      await enter('archive-path', archive.path);
      await tap('save-archive');
      await settleIO('media-busy');
      final oldId = workspace.projectId;
      await tap('restore-archive');
      await settleIO('media-busy');
      expect(workspace.projectId, isNot(oldId));
      expect(moveVideos(workspace.current), hasLength(2));
      expect(
        (workspace.current.toJson()['captions'] as List)
            .map((c) => c['text'])
            .toSet(),
        {'hello', 'stay'},
      );
      expect(
        moveVideos(workspace.current).map((c) => startOf(c)),
        containsAll([Q.of(0), Q.of(3)]),
      );

      final sidecar = File('${dir.path}/invert-split.vtt');
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
