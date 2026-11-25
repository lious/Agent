import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';

Q durOf(Map c) => Q.fromJson(c['timelineRange']['duration']);

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);

void main() {
  testWidgets(
    'REAL path: split keeps a left cue, leave-gap trim leaves an absolute remnant, undo/archive/sidecar, no MP4',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('caption-split-trim-ui-');
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
      await tap('caption-panel');
      await tester.pumpAndSettle();
      await enter('caption-text', 'split-trim');
      await enter('caption-start', '200');
      await enter('caption-duration', '500');
      await tap('caption-add');
      expect(workspace.current.toJson()['captions'], hasLength(1));
      expect(
        workspace.current.toJson()['captions'][0]['anchor']['kind'],
        'clipLocal',
      );

      await tap('clip-$video');
      await tester.pumpAndSettle();
      await enter('edit-frames', '30');
      await tester.pumpAndSettle();
      await tap('split');
      await tester.pumpAndSettle();
      expect(moveVideos(workspace.current), hasLength(2));
      expect(
        (workspace.current.toJson()['sequences'][0]['tracks'] as List)
            .singleWhere((tr) => tr['kind'] == 'audio')['items']
            .where((c) => c['source'] != null)
            .length,
        2,
      );
      expect(workspace.current.toJson()['captions'][0]['text'], 'split-trim');
      expect(
        workspace.current.toJson()['captions'][0]['anchor']['kind'],
        'clipLocal',
      );
      expect(
        workspace.current.toJson()['captions'][0]['anchor']['clipId'],
        video,
      );
      expect(
        Q.fromJson(
          workspace.current.toJson()['captions'][0]['timelineRange']['start'],
        ),
        Q.of(1, 5),
      );

      await tap('clip-$video');
      await tester.pumpAndSettle();
      await enter('edit-frames', '15');
      await tap('trim');
      await tester.pumpAndSettle();
      expect(
        durOf(
          moveVideos(workspace.current).firstWhere((c) => c['id'] == video),
        ),
        Q.of(1, 2),
      );
      final captions = (workspace.current.toJson()['captions'] as List)
          .cast<Map>();
      expect(captions, hasLength(2));
      final local = captions.singleWhere(
        (c) => c['anchor']['kind'] == 'clipLocal',
      );
      final abs = captions.singleWhere(
        (c) => c['anchor']['kind'] == 'absolute',
      );
      expect(local['text'], 'split-trim');
      expect(Q.fromJson(local['timelineRange']['start']), Q.of(1, 5));
      expect(Q.fromJson(local['timelineRange']['duration']), Q.of(3, 10));
      expect(abs['text'], 'split-trim');
      expect(Q.fromJson(abs['timelineRange']['start']), Q.of(1, 2));
      expect(Q.fromJson(abs['timelineRange']['duration']), Q.of(1, 5));

      final trimmed = workspace.current.toJson();
      await tap('undo');
      await tester.pumpAndSettle();
      expect(workspace.current.toJson()['captions'], hasLength(1));
      expect(
        durOf(
          moveVideos(workspace.current).firstWhere((c) => c['id'] == video),
        ),
        Q.of(1),
      );
      await tap('redo');
      await tester.pumpAndSettle();
      expect(workspace.current.toJson()['captions'], hasLength(2));
      expect(workspace.current.toJson()['sequences'], trimmed['sequences']);

      final archive = File('${dir.path}/caption-split-trim.studio-project');
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
        {'split-trim'},
      );

      final sidecar = File('${dir.path}/split-trim.vtt');
      await enter('caption-path', sidecar.path);
      await tap('caption-export-vtt');
      expect(sidecar.existsSync(), isTrue);
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
      expect(File('${dir.path}/must-not.mp4').existsSync(), false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => workspace.closeAsync().timeout(const Duration(seconds: 5)),
      );
    },
  );
}
