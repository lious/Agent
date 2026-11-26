import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);

List<Map> audios(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    if (t['kind'] == 'audio')
      for (final c in t['items'])
        if (c['source'] != null) c as Map,
];

int groupCount(ProjectDocument p) => (p.toJson()['linkGroups'] as List).length;

void main() {
  testWidgets(
    'REAL path: invert unlink after an aligned leave-gap move, undo/archive/sidecar, no MP4',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('invert-unlink-ui-');
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
      final right =
          moveVideos(workspace.current)
                  .singleWhere((c) => c['id'] != video)['id']
              as String;
      final rightAudio =
          audios(workspace.current)
                  .singleWhere((c) => startOf(c) == Q.of(1))['id']
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
      expect(groupCount(workspace.current), 2);

      await tap('clip-$right');
      await tester.pumpAndSettle();
      await tap('unlink-persistent-audio');
      await tester.pumpAndSettle();
      expect(groupCount(workspace.current), 1);
      final unlinkId = workspace.commandLog
          .where((c) => c['kind'] == 'unlinkAudioVideo')
          .last['id']!;

      if (find
          .byKey(const Key('clear-multi-selection'))
          .evaluate()
          .isNotEmpty) {
        await tap('clear-multi-selection');
        await tester.pumpAndSettle();
      }
      await tap('multi-select-$right');
      await tester.pumpAndSettle();
      await tap('multi-select-$rightAudio');
      await tester.pumpAndSettle();
      await enter('edit-frames', '30');
      await tester.pumpAndSettle();
      await tap('preview-multi-right');
      await settleIO('multi-preview-busy');
      await tap('commit-multi-move');
      await tester.pumpAndSettle();
      expect(
        startOf(
          moveVideos(workspace.current).firstWhere((c) => c['id'] == right),
        ),
        Q.of(2),
      );
      expect(
        startOf(
          audios(workspace.current).firstWhere((c) => c['id'] == rightAudio),
        ),
        Q.of(2),
      );
      expect(groupCount(workspace.current), 1);

      await enter('invert-command-id', unlinkId);
      await tap('invert-command');
      await tester.pumpAndSettle();
      expect(groupCount(workspace.current), 2);
      expect(
        startOf(
          moveVideos(workspace.current).firstWhere((c) => c['id'] == video),
        ),
        Q.of(0),
      );
      expect(
        startOf(
          moveVideos(workspace.current).firstWhere((c) => c['id'] == right),
        ),
        Q.of(2),
      );
      expect(
        startOf(
          audios(workspace.current).firstWhere((c) => c['id'] == rightAudio),
        ),
        Q.of(2),
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
        Q.of(5, 2),
      );

      await tap('undo');
      await tester.pumpAndSettle();
      expect(groupCount(workspace.current), 1);
      expect(
        startOf(
          moveVideos(workspace.current).firstWhere((c) => c['id'] == right),
        ),
        Q.of(2),
      );
      await tap('redo');
      await tester.pumpAndSettle();
      expect(groupCount(workspace.current), 2);
      expect(
        startOf(
          moveVideos(workspace.current).firstWhere((c) => c['id'] == right),
        ),
        Q.of(2),
      );

      final archive = File('${dir.path}/invert-unlink.studio-project');
      await enter('archive-path', archive.path);
      await tap('save-archive');
      await settleIO('media-busy');
      final oldId = workspace.projectId;
      await tap('restore-archive');
      await settleIO('media-busy');
      expect(workspace.projectId, isNot(oldId));
      expect(groupCount(workspace.current), 2);
      expect(
        (workspace.current.toJson()['captions'] as List)
            .map((c) => c['text'])
            .toSet(),
        {'hello', 'stay'},
      );
      expect(
        moveVideos(workspace.current).map((c) => startOf(c)),
        containsAll([Q.of(0), Q.of(2)]),
      );

      final sidecar = File('${dir.path}/invert-unlink.vtt');
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
