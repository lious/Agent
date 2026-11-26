import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);

Q durationOf(Map c) => Q.fromJson(c['timelineRange']['duration']);

List<Map> audios(ProjectDocument p) => [
      for (final t in p.toJson()['sequences'][0]['tracks'])
        if (t['kind'] == 'audio')
          for (final c in t['items'])
            if (c['source'] != null) c as Map,
    ];

String policy(ProjectDocument p) =>
    p.toJson()['linkGroups'][0]['syncPolicy'] as String;

Q seqDur(ProjectDocument p) =>
    Q.fromJson(p.toJson()['sequences'][0]['duration']);

Map clipOf(ProjectDocument p, String id) =>
    [...moveVideos(p), ...audios(p)].singleWhere((c) => c['id'] == id);

void main() {
  testWidgets(
    'REAL path: invert includeLinks=false MoveClips of the video host after a later marker edit, undo/archive/sidecar, no MP4',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync(
        'invert-ignore-links-ui-',
      );
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

      await tap('caption-panel');
      await tester.pumpAndSettle();
      await enter('caption-text', 'hello');
      await enter('caption-start', '0');
      await enter('caption-duration', '500');
      await tap('caption-add');
      expect(workspace.current.toJson()['captions'], hasLength(1));

      await tap('clip-$video');
      await tester.pumpAndSettle();
      await tap('extract-persistent-audio');
      await tester.pumpAndSettle();
      expect(audios(workspace.current), hasLength(1));
      final audio = audios(workspace.current).single['id'] as String;
      expect(policy(workspace.current), 'preserve');

      await tap('caption-panel');
      await tester.pumpAndSettle();
      await enter('caption-text', 'stay');
      await enter('caption-start', '2000');
      await enter('caption-duration', '500');
      await tap('caption-add');
      expect(workspace.current.toJson()['captions'], hasLength(2));
      final stayId =
          (workspace.current.toJson()['captions'] as List)
                  .cast<Map>()
                  .singleWhere((c) => c['text'] == 'stay')['id']
              as String;
      await tap('cue-$stayId');
      await tester.pumpAndSettle();
      await tap('caption-make-absolute');
      await tester.pumpAndSettle();
      expect(
        (workspace.current.toJson()['captions'] as List)
            .cast<Map>()
            .singleWhere((c) => c['text'] == 'stay')['anchor']['kind'],
        'absolute',
      );

      await tap('move-ignore-links');
      await tester.pumpAndSettle();
      await enter('edit-frames', '30');
      await tester.pumpAndSettle();
      await tap('clear-multi-selection');
      await tester.pumpAndSettle();
      await tap('multi-select-$video');
      await tester.pumpAndSettle();
      await tap('preview-multi-right');
      await settleIO('multi-preview-busy');
      expect(find.byKey(const Key('multi-gesture-active')), findsOneWidget);
      // Native ghost of a caption-bearing timeline still refuses burn-in; the
      // pending MoveClips gesture itself remains commitable.
      expect(
        tester.widget<Text>(find.byKey(const Key('multi-error'))).data,
        'Multi-move: CAPTION_RENDER_POLICY_NOT_IMPLEMENTED',
      );
      expect(find.byKey(const Key('multi-ghost-preview')), findsNothing);
      await tap('commit-multi-move');
      await tester.pumpAndSettle();
      expect(startOf(clipOf(workspace.current, video)), Q.of(1));
      expect(startOf(clipOf(workspace.current, audio)), Q.of(0));
      expect(durationOf(clipOf(workspace.current, video)), Q.of(3));
      expect(durationOf(clipOf(workspace.current, audio)), Q.of(3));
      expect(policy(workspace.current), 'allowOutOfSync');
      expect(seqDur(workspace.current), Q.of(4));
      expect(
        Q.fromJson(
          (workspace.current.toJson()['captions'] as List)
              .cast<Map>()
              .singleWhere((c) => c['text'] == 'hello')['timelineRange']['start'],
        ),
        Q.of(1),
      );
      expect(
        (workspace.current.toJson()['captions'] as List)
            .cast<Map>()
            .singleWhere((c) => c['text'] == 'hello')['anchor']['kind'],
        'clipLocal',
      );
      expect(
        Q.fromJson(
          (workspace.current.toJson()['captions'] as List)
              .cast<Map>()
              .singleWhere((c) => c['text'] == 'stay')['timelineRange']['start'],
        ),
        Q.of(2),
      );
      expect(
        (workspace.current.toJson()['captions'] as List)
            .cast<Map>()
            .singleWhere((c) => c['text'] == 'stay')['anchor']['kind'],
        'absolute',
      );
      final moveId = workspace.commandLog
          .where((c) => c['kind'] == 'moveClips')
          .last['id']!;

      await tap('marker-panel');
      await tester.pumpAndSettle();
      await enter('marker-label', 'later');
      await enter('marker-time', '3000');
      await tap('marker-add');
      await tester.pumpAndSettle();
      expect(workspace.current.toJson()['markers'], hasLength(1));

      await enter('invert-command-id', moveId);
      await tap('invert-command');
      await tester.pumpAndSettle();
      expect(moveVideos(workspace.current), hasLength(1));
      expect(audios(workspace.current), hasLength(1));
      expect(startOf(clipOf(workspace.current, video)), Q.of(0));
      expect(startOf(clipOf(workspace.current, audio)), Q.of(0));
      expect(policy(workspace.current), 'preserve');
      expect(seqDur(workspace.current), Q.of(3));
      expect(
        (workspace.current.toJson()['markers'] as List).single['label'],
        'later',
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
        Q.of(2),
      );
      expect(
        captions.singleWhere((c) => c['text'] == 'stay')['anchor']['kind'],
        'absolute',
      );
      expect(
        captions.singleWhere((c) => c['text'] == 'hello')['anchor']['kind'],
        'clipLocal',
      );

      await tap('undo');
      await tester.pumpAndSettle();
      expect(startOf(clipOf(workspace.current, video)), Q.of(1));
      expect(startOf(clipOf(workspace.current, audio)), Q.of(0));
      expect(policy(workspace.current), 'allowOutOfSync');
      expect(seqDur(workspace.current), Q.of(4));
      expect(
        (workspace.current.toJson()['markers'] as List).single['label'],
        'later',
      );
      await tap('redo');
      await tester.pumpAndSettle();
      expect(moveVideos(workspace.current), hasLength(1));
      expect(startOf(clipOf(workspace.current, video)), Q.of(0));
      expect(startOf(clipOf(workspace.current, audio)), Q.of(0));
      expect(policy(workspace.current), 'preserve');
      expect(seqDur(workspace.current), Q.of(3));

      final archive = File('${dir.path}/invert-ignore-links.studio-project');
      await enter('archive-path', archive.path);
      await tap('save-archive');
      await settleIO('media-busy');
      final oldId = workspace.projectId;
      await tap('restore-archive');
      await settleIO('media-busy');
      expect(workspace.projectId, isNot(oldId));
      expect(moveVideos(workspace.current), hasLength(1));
      expect(audios(workspace.current), hasLength(1));
      expect(
        (workspace.current.toJson()['captions'] as List)
            .map((c) => c['text'])
            .toSet(),
        {'hello', 'stay'},
      );
      expect(
        (workspace.current.toJson()['markers'] as List).single['label'],
        'later',
      );
      expect(
        startOf(moveVideos(workspace.current).single),
        Q.of(0),
      );
      expect(
        startOf(audios(workspace.current).single),
        Q.of(0),
      );
      expect(policy(workspace.current), 'preserve');
      expect(seqDur(workspace.current), Q.of(3));
      expect(
        (workspace.current.toJson()['captions'] as List)
            .cast<Map>()
            .singleWhere((c) => c['text'] == 'stay')['anchor']['kind'],
        'absolute',
      );

      final sidecar = File('${dir.path}/invert-ignore-links.vtt');
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
