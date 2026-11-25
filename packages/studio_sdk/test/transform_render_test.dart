import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  final lib = Platform.environment['STUDIO_MEDIA_LIBRARY'];
  test(
    'REAL transform UI-consumer pipeline: known linear-light bilinear pixels, shared encoder, undo/archive/fork/reopen',
    () async {
      final root = Directory.systemTemp.createTempSync('transform-render-');
      final source = File('${root.path}/white.mp4');
      final made = Process.runSync('ffmpeg', [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'color=c=white:s=128x72:r=30:d=3',
        '-vf',
        'setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=limited',
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
        '-color_primaries',
        'bt709',
        '-color_trc',
        'bt709',
        '-colorspace',
        'bt709',
        '-color_range',
        'tv',
        source.path,
      ]);
      expect(made.exitCode, 0, reason: '${made.stderr}');
      StudioWorkspace open() => StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${root.path}/db',
        tenantId: 'local',
        workspaceId: 'transform',
        mediaLibraryPath: lib,
        mediaRootPath: '${root.path}/media',
      );
      var w = open();
      try {
        w.openDemo();
        await w.importVideo(
          LocalFileGrant.fromUserSelection(source),
          expectedRevision: w.current.revision,
          acknowledgeVideoOnly: true,
        );
        final cid =
            w.current.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
                as String;
        void set(Map<String, double> p) => w.setClipTransform(cid, {
          ...identityTransform2d,
          ...p,
        }, expectedRevision: w.current.revision);
        int channel(SourcePreviewFrame f, int x, int y) =>
            f.rgba[(y * f.width + x) * 4];
        final original = await w.previewTimelineAt(Q.of(0));
        final callerParameters = {...identityTransform2d, 'translateX': 16.0};
        final captured = w.previewAssetSource(
          w.current.toJson()['assets'][0]['id'] as String,
          Q.of(0),
          transform2d: callerParameters,
        );
        callerParameters['translateX'] = 0;
        expect(channel(await captured, 8, 36), inInclusiveRange(0, 2));

        set({'translateX': .5});
        var frame = await w.previewTimelineAt(Q.of(0));
        final encodedWhite = channel(original, 60, 36) / 255.0;
        final linear = encodedWhite < .081
            ? encodedWhite / 4.5
            : math.pow((encodedWhite + .099) / 1.099, 1 / .45).toDouble();
        final half = linear * .5;
        final ref =
            ((half < .018 ? half * 4.5 : 1.099 * math.pow(half, .45) - .099) *
                    255)
                .round();
        expect((channel(frame, 0, 36) - ref).abs(), lessThanOrEqualTo(2));
        expect(channel(frame, 20, 36), inInclusiveRange(253, 255));
        set({'scaleX': .5, 'scaleY': .25});
        frame = await w.previewTimelineAt(Q.of(0));
        expect(channel(frame, 10, 36), inInclusiveRange(0, 2));
        expect(channel(frame, 64, 36), inInclusiveRange(253, 255));
        expect(channel(frame, 64, 5), inInclusiveRange(0, 2));
        expect(channel(frame, 64, 23), inInclusiveRange(0, 2));
        set({'rotationDeg': 90, 'translateX': 16});
        frame = await w.previewTimelineAt(Q.of(0));
        expect(channel(frame, 40, 36), inInclusiveRange(0, 2));
        expect(channel(frame, 48, 36), inInclusiveRange(253, 255));
        expect(channel(frame, 120, 36), inInclusiveRange(0, 2));
        set({'rotationDeg': 90, 'anchorX': 0, 'anchorY': 0});
        frame = await w.previewTimelineAt(Q.of(0));
        expect(channel(frame, 64, 36), inInclusiveRange(0, 2));
        set({});
        expect(
          (await w.previewTimelineAt(Q.of(0))).rgba,
          orderedEquals(original.rgba),
        );
        set({'translateX': 16});
        final transformed = await w.previewTimelineAt(Q.of(1, 3));
        w.undo(expectedRevision: w.current.revision);
        expect(
          (await w.previewTimelineAt(Q.of(1, 3))).rgba,
          orderedEquals(original.rgba),
        );
        set({'translateX': 16});
        w.setOpacityKeyframe(
          cid,
          Q.of(0),
          0,
          expectedRevision: w.current.revision,
        );
        w.setOpacityKeyframe(
          cid,
          Q.of(2),
          1,
          expectedRevision: w.current.revision,
        );
        final before = await w.previewTimelineAt(Q.of(1));
        expect(before.rgba, isNot(orderedEquals(transformed.rgba)));
        var output = await w.exportVideo(
          File('${root.path}/transformed.mp4'),
          captureFrames: [30],
        );
        expect(
          output['preEncoderSamples'][0]['rgba'],
          orderedEquals(before.rgba),
        );
        final archive = File('${root.path}/archive.zip');
        await w.saveArchive(archive);
        final hash = w.current.hash;
        w.close();
        w = open();
        w.openDemo();
        expect(w.current.hash, hash);
        expect(
          (await w.previewTimelineAt(Q.of(1))).rgba,
          orderedEquals(before.rgba),
        );
        await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
        output = await w.exportVideo(
          File('${root.path}/fork.mp4'),
          captureFrames: [30],
        );
        expect(
          output['preEncoderSamples'][0]['rgba'],
          orderedEquals(before.rgba),
        );
        final active =
            w.current.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
                as String;
        w.edit(
          SplitClip(active, Q.of(1), 'transform-cut-right'),
          expectedRevision: w.current.revision,
        );
        output = await w.exportVideo(
          File('${root.path}/split.mp4'),
          captureFrames: [30],
        );
        expect(
          output['preEncoderSamples'][0]['rgba'],
          orderedEquals(before.rgba),
        );
      } finally {
        w.close();
        root.deleteSync(recursive: true);
      }
    },
    skip: lib == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'REAL hostile native transform recipes fail before creating output',
    () async {
      final root = Directory.systemTemp.createTempSync('bad-transform-');
      final media = NativeMedia.open(
        lib!,
        Namespace('studio', 'local', 'bad-transform'),
      );
      try {
        for (final p in <Map<String, dynamic>>[
          {'extra': 1},
          {...identityTransform2d, 'scaleX': 0},
          {...identityTransform2d, 'anchorX': 2},
          {...identityTransform2d, 'translateY': 1000001},
          {...identityTransform2d, 'scaleX': '1'},
        ]) {
          final out = File('${root.path}/bad.mp4');
          await expectLater(
            media.renderAsync({
              'outputPath': out.path,
              'width': 320,
              'height': 180,
              'fps': {'n': 30, 'd': 1},
              'frameCount': 90,
              'segments': [
                {
                  'path': Platform.environment['STUDIO_TEST_VIDEO']!,
                  'startFrame': 0,
                  'frameCount': 90,
                  'sourceStart': Q.of(0).toJson(),
                  'streamIndex': 0,
                  'transform2d': p,
                },
              ],
            }),
            throwsA(isA<StudioException>()),
          );
          expect(out.existsSync(), false);
        }
      } finally {
        media.close();
        root.deleteSync(recursive: true);
      }
    },
    skip: lib == null || Platform.environment['STUDIO_TEST_VIDEO'] == null,
  );
}
