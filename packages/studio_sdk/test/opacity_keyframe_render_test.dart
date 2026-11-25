import 'dart:io';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  final lib = Platform.environment['STUDIO_MEDIA_LIBRARY'];
  final input = Platform.environment['STUDIO_TEST_VIDEO'];
  test(
    'REAL keyframed opacity edit/undo/split -> evaluated preview -> preencoder -> archive/fork/reopen',
    () async {
      final root = Directory.systemTemp.createTempSync('opacity-render-');
      StudioWorkspace open() => StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${root.path}/db',
        tenantId: 'local',
        workspaceId: 'opacity',
        mediaLibraryPath: lib,
        mediaRootPath: '${root.path}/media',
      );
      var w = open();
      try {
        w.openDemo();
        await w.importVideo(
          LocalFileGrant.fromUserSelection(File(input!)),
          expectedRevision: w.current.revision,
          acknowledgeVideoOnly: true,
        );
        final id =
            w.current.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
                as String;
        final original = await w.previewTimelineAt(Q.of(0));
        w.setOpacityKeyframe(
          id,
          Q.of(0),
          0,
          expectedRevision: w.current.revision,
        );
        w.setOpacityKeyframe(
          id,
          Q.of(2),
          1,
          expectedRevision: w.current.revision,
        );
        final effect = w.current.toJson()['effects'][0];
        final preview = await w.previewTimelineAt(Q.of(0)),
            next = await w.previewTimelineAt(Q.of(1, 3));
        expect(preview.rgba, isNot(orderedEquals(original.rgba)));
        final result = await w.exportVideo(
          File('${root.path}/opacity.mp4'),
          captureFrames: [0, 10],
        );
        final captures = result['preEncoderSamples'] as List;
        expect(captures.length, 2);
        for (var i = 0; i < 2; i++) {
          expect(captures[i]['stage'], 'actual-yuv420-before-encoder');
          expect(captures[i]['rgba'], orderedEquals([preview, next][i].rgba));
          expect(captures[i]['width'], preview.width);
          expect(captures[i]['height'], preview.height);
        }
        w.undo(expectedRevision: w.current.revision);
        expect(w.current.toJson()['effects'][0]['keyframes'].length, 1);
        expect(w.current.toJson()['effects'][0]['keyframes'][0]['value'], 0);
        w.setOpacityKeyframe(
          id,
          Q.of(2),
          1,
          expectedRevision: w.current.revision,
        );
        final archive = File('${root.path}/effects.zip');
        await w.saveArchive(archive);
        final before = w.current.hash;
        w.close();
        w = open();
        w.openDemo();
        expect(w.current.hash, before);
        expect(
          w.current.toJson()['effects'][0]['parameters'],
          effect['parameters'],
        );
        expect(
          (await w.previewTimelineAt(Q.of(0))).rgba,
          orderedEquals(preview.rgba),
        );
        await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
        expect(w.current.hash, isNot(before));
        expect(
          w.current.toJson()['effects'][0]['owner']['id'],
          w.current.toJson()['sequences'][0]['tracks'][0]['items'][0]['id'],
        );
        final fork = await w.exportVideo(
          File('${root.path}/fork.mp4'),
          captureFrames: [0, 10],
        );
        expect(
          fork['preEncoderSamples'][0]['rgba'],
          orderedEquals(preview.rgba),
        );
        expect(fork['preEncoderSamples'][1]['rgba'], orderedEquals(next.rgba));
        final json = File('${root.path}/import.json')
          ..writeAsStringSync(jsonEncode(w.current.toJson()));
        final session = await ResourcePreservationSession.openJson(
          LocalFileGrant.fromUserSelection(json),
        );
        await session.attach(LocalFileGrant.fromUserSelection(File(input)));
        await w.adoptPreservedResources(
          session,
          expectedCollectionReviewHash: session.collectionReviewHash,
          expectedActiveHash: w.current.hash,
          confirmed: true,
        );
        expect(
          (await w.previewTimelineAt(Q.of(0))).rgba,
          orderedEquals(preview.rgba),
        );
        final beforeCut = [
          await w.previewTimelineAt(Q.of(29, 30)),
          await w.previewTimelineAt(Q.of(1)),
        ];
        final activeClip =
            w.current.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
                as String;
        w.edit(
          SplitClip(activeClip, Q.of(1), 'keyframe-render-right'),
          expectedRevision: w.current.revision,
        );
        final splitArchive = File('${root.path}/split.zip');
        await w.saveArchive(splitArchive);
        w.close();
        w = open();
        w.openDemo();
        expect(w.current.toJson()['effects'].length, 2);
        final splitResult = await w.exportVideo(
          File('${root.path}/split.mp4'),
          captureFrames: [29, 30],
        );
        for (var i = 0; i < 2; i++) {
          expect(
            splitResult['preEncoderSamples'][i]['rgba'],
            orderedEquals(beforeCut[i].rgba),
          );
        }
        final p = w.previewTimelineAt(Q.of(1, 3));
        final stale = expectLater(
          p,
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              anyOf('PREVIEW_PROJECT_CHANGED', 'PREVIEW_SUPERSEDED'),
            ),
          ),
        );
        w.setOpacityKeyframe(
          w.current.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
              as String,
          Q.of(0),
          .25,
          expectedRevision: w.current.revision,
        );
        await stale;
        await expectLater(
          w.exportVideo(File('${root.path}/bad.mp4'), captureFrames: [0, 0]),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'CAPTURE_LIMIT',
            ),
          ),
        );
        expect(File('${root.path}/bad.mp4').existsSync(), isFalse);
        w.edit(
          MoveClip(
            w.current.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
                as String,
            Q.of(5000),
          ),
          expectedRevision: w.current.revision,
        );
        await expectLater(
          w.exportVideo(File('${root.path}/over-limit.mp4')),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'RENDER_FRAME_LIMIT',
            ),
          ),
        );
        expect(File('${root.path}/over-limit.mp4').existsSync(), isFalse);
      } finally {
        w.close();
        root.deleteSync(recursive: true);
      }
    },
    skip: lib == null || input == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'REAL native malformed opacity schedules refuse before file creation',
    () async {
      final dir = Directory.systemTemp.createTempSync('bad-opacity-schedule-');
      final media = NativeMedia.open(
        lib!,
        Namespace('studio', 'local', 'bad-schedule'),
      );
      try {
        for (final values in <List<dynamic>>[
          [0],
          List.filled(90, -1),
          List.filled(90, 65537),
          List.filled(90, .5),
        ]) {
          final out = File('${dir.path}/bad.mp4');
          await expectLater(
            media.renderAsync({
              'outputPath': out.path,
              'width': 320,
              'height': 180,
              'fps': {'n': 30, 'd': 1},
              'frameCount': 90,
              'segments': [
                {
                  'path': input!,
                  'startFrame': 0,
                  'frameCount': 90,
                  'sourceStart': Q.of(0).toJson(),
                  'streamIndex': 0,
                  'opacityFramesQ16': values,
                },
              ],
            }),
            throwsA(isA<StudioException>()),
          );
          expect(out.existsSync(), false);
        }
      } finally {
        media.close();
        dir.deleteSync(recursive: true);
      }
    },
    skip: lib == null || input == null,
  );
}
