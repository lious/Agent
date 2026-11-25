import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_editor_ui/studio_editor_ui.dart';
import 'package:studio_sdk/studio_sdk.dart';

import '../../studio_sdk/test/multi_move_fixture.dart';

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);

Q durOf(Map c) => Q.fromJson(c['timelineRange']['duration']);

Q seqDur(ProjectDocument p) =>
    Q.fromJson(p.toJson()['sequences'][0]['duration']);

void main() {
  testWidgets(
    'REAL s3 path: split packed A/B/C, reject A+6 collision, ripple-trim A, undo, archive/sidecar, no MP4',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('s3-opened-ui-');
      final workspace = openMoveWorkspace(dir);
      addTearDown(() async {
        workspace.close();
        dir.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1100, 1900));
      await tester.runAsync(() async {
        workspace.openDemo();
        await workspace.importVideo(
          LocalFileGrant.fromUserSelection(
            File(Platform.environment['STUDIO_TEST_VIDEO']!),
          ),
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

      var clips = moveVideos(workspace.current);
      expect(clips, hasLength(1));
      await tap('clip-${clips.first['id']}');
      await enter('edit-frames', '30');
      await tap('split');
      await tester.pumpAndSettle();
      clips = moveVideos(workspace.current);
      expect(clips, hasLength(2));
      final right = clips.firstWhere((c) => startOf(c) == Q.of(1));
      await tap('clip-${right['id']}');
      await enter('edit-frames', '30');
      await tap('split');
      await tester.pumpAndSettle();
      clips = moveVideos(workspace.current);
      expect(clips, hasLength(3));
      expect(clips.map(startOf).toSet(), {Q.of(0), Q.of(1), Q.of(2)});
      expect(seqDur(workspace.current), Q.of(3));

      await tap('caption-panel');
      await tester.pumpAndSettle();
      await enter('caption-text', 's3-follow');
      await enter('caption-start', '100');
      await enter('caption-duration', '200');
      await tap('caption-add');
      expect(workspace.current.toJson()['captions'], hasLength(1));
      await tap('marker-panel');
      await tester.pumpAndSettle();
      await enter('marker-label', 'stay');
      await enter('marker-time', '250');
      await tap('marker-add');
      expect(workspace.current.toJson()['markers'], hasLength(1));

      final a = clips.firstWhere((c) => startOf(c) == Q.of(0))['id'] as String;
      await tap('multi-select-$a');
      await enter('edit-frames', '6');
      final beforeCollision = workspace.current.hash;
      final rev = workspace.current.revision;
      await tap('preview-multi-right');
      await settleIO('multi-preview-busy');
      expect(workspace.current.hash, beforeCollision);
      expect(workspace.current.revision, rev);
      expect(find.byKey(const Key('multi-error')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('multi-error'))).data,
        contains('COLLISION'),
      );
      if (find.byKey(const Key('cancel-multi-move')).hitTestable().evaluate().isNotEmpty) {
        await tap('cancel-multi-move');
        await tester.pumpAndSettle();
      }

      await tap('clip-$a');
      await enter('edit-frames', '3');
      await tap('ripple-trim');
      await tester.pumpAndSettle();
      final afterTrim = moveVideos(workspace.current);
      final trimmedA = afterTrim.firstWhere((c) => c['id'] == a);
      expect(durOf(trimmedA), Q.of(9, 10));
      expect(
        startOf(afterTrim.singleWhere((c) => startOf(c) == Q.of(9, 10))),
        Q.of(9, 10),
      );
      expect(seqDur(workspace.current), Q.of(29, 10));
      expect(workspace.current.toJson()['captions'][0]['text'], 's3-follow');
      expect(
        Q.fromJson(
          workspace.current.toJson()['markers'][0]['time'],
        ),
        Q.of(1, 4),
      );

      final trimmed = workspace.current.toJson();
      await tap('undo');
      await tester.pumpAndSettle();
      expect(seqDur(workspace.current), Q.of(3));
      expect(durOf(moveVideos(workspace.current).singleWhere((c) => c['id'] == a)), Q.of(1));
      await tap('redo');
      await tester.pumpAndSettle();
      expect(workspace.current.toJson()['sequences'], trimmed['sequences']);
      expect(workspace.current.toJson()['captions'][0]['text'], 's3-follow');

      final archive = File('${dir.path}/s3-matrix.studio-project');
      await enter('archive-path', archive.path);
      await tap('save-archive');
      await settleIO('media-busy');
      final oldId = workspace.projectId;
      await tap('restore-archive');
      await settleIO('media-busy');
      expect(workspace.projectId, isNot(oldId));
      expect(workspace.current.toJson()['captions'][0]['text'], 's3-follow');
      expect(workspace.current.toJson()['markers'][0]['label'], 'stay');
      expect(seqDur(workspace.current), Q.of(29, 10));

      final sidecar = File('${dir.path}/s3.vtt');
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
