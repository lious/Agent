import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);

void main() {
  testWidgets(
    'REAL path: lock video, undo/redo lock, refused move, unlock then follow, archive/sidecar, no MP4',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('track-lock-ui-');
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

      await tap('caption-panel');
      await tester.pumpAndSettle();
      await enter('caption-text', 'hello');
      await enter('caption-start', '0');
      await enter('caption-duration', '500');
      await tap('caption-add');
      expect(workspace.current.toJson()['captions'], hasLength(1));

      final videoTrack =
          (workspace.current.toJson()['sequences'][0]['tracks'] as List)
                  .cast<Map>()
                  .singleWhere((t) => t['kind'] == 'video')['id']
              as String;
      await tap('video-track-lock-$videoTrack');
      await tester.pumpAndSettle();
      expect(
        (workspace.current.toJson()['sequences'][0]['tracks'] as List)
            .cast<Map>()
            .singleWhere((t) => t['id'] == videoTrack)['locked'],
        isTrue,
      );

      await tap('undo');
      await tester.pumpAndSettle();
      expect(
        (workspace.current.toJson()['sequences'][0]['tracks'] as List)
            .cast<Map>()
            .singleWhere((t) => t['id'] == videoTrack)['locked'],
        isFalse,
      );
      await tap('redo');
      await tester.pumpAndSettle();
      expect(
        (workspace.current.toJson()['sequences'][0]['tracks'] as List)
            .cast<Map>()
            .singleWhere((t) => t['id'] == videoTrack)['locked'],
        isTrue,
      );

      await tap('clip-$video');
      await tester.pumpAndSettle();
      await enter('edit-frames', '30');
      await tester.pumpAndSettle();
      await tap('move');
      await tester.pumpAndSettle();
      expect(startOf(moveVideos(workspace.current).first), Q.of(0));
      expect(
        Q.fromJson(
          (workspace.current.toJson()['captions'] as List)
              .single['timelineRange']['start'],
        ),
        Q.of(0),
      );

      await tap('video-track-lock-$videoTrack');
      await tester.pumpAndSettle();
      expect(
        (workspace.current.toJson()['sequences'][0]['tracks'] as List)
            .cast<Map>()
            .singleWhere((t) => t['id'] == videoTrack)['locked'],
        isFalse,
      );
      await tap('move');
      await tester.pumpAndSettle();
      expect(startOf(moveVideos(workspace.current).first), Q.of(1));
      expect(
        (workspace.current.toJson()['captions'] as List)
            .single['anchor']['kind'],
        'clipLocal',
      );
      expect(
        Q.fromJson(
          (workspace.current.toJson()['captions'] as List)
              .single['timelineRange']['start'],
        ),
        Q.of(1),
      );

      final archive = File('${dir.path}/track-lock.studio-project');
      await enter('archive-path', archive.path);
      await tap('save-archive');
      await settleIO('media-busy');
      final oldId = workspace.projectId;
      await tap('restore-archive');
      await settleIO('media-busy');
      expect(workspace.projectId, isNot(oldId));
      expect(startOf(moveVideos(workspace.current).first), Q.of(1));
      expect(
        (workspace.current.toJson()['captions'] as List).single['text'],
        'hello',
      );

      final sidecar = File('${dir.path}/lock.vtt');
      await enter('caption-path', sidecar.path);
      await tap('caption-export-vtt');
      expect(sidecar.existsSync(), isTrue);
      expect(sidecar.readAsStringSync(), contains('hello'));
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
