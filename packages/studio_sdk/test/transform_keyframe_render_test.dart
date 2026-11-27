import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

void main() {
  final lib = Platform.environment['STUDIO_MEDIA_LIBRARY'];
  test(
    'REAL keyframed transform2d edit/undo/split -> evaluated preview -> preencoder -> archive/fork/reopen',
    () async {
      final root = Directory.systemTemp.createTempSync('transform-key-render-');
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
        workspaceId: 'transform-keys',
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
        final original = await w.previewTimelineAt(Q.of(0));
        w.setTransformKeyframe(
          cid,
          Q.of(0),
          'translateX',
          0,
          expectedRevision: w.current.revision,
        );
        w.setTransformKeyframe(
          cid,
          Q.of(2),
          'translateX',
          16,
          expectedRevision: w.current.revision,
        );
        final start = await w.previewTimelineAt(Q.of(0));
        expect(start.rgba, orderedEquals(original.rgba));
        final mid = await w.previewTimelineAt(Q.of(1));
        final staticMid = await w.previewAssetSource(
          w.current.toJson()['assets'][0]['id'] as String,
          Q.of(1),
          transform2d: {...identityTransform2d, 'translateX': 8},
        );
        expect(mid.rgba, orderedEquals(staticMid.rgba));
        expect(mid.rgba, isNot(orderedEquals(original.rgba)));
        final result = await w.exportVideo(
          File('${root.path}/ken-burns.mp4'),
          captureFrames: [0, 30],
        );
        final captures = result['preEncoderSamples'] as List;
        expect(captures.length, 2);
        expect(captures[0]['rgba'], orderedEquals(start.rgba));
        expect(captures[1]['rgba'], orderedEquals(mid.rgba));
        w.undo(expectedRevision: w.current.revision);
        expect(
          (w.current.toJson()['effects'] as List)
              .singleWhere((e) => e['type'] == 'transform2d')['keyframes']
              .length,
          1,
        );
        w.setTransformKeyframe(
          cid,
          Q.of(2),
          'translateX',
          16,
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
          (await w.previewTimelineAt(Q.of(1))).rgba,
          orderedEquals(mid.rgba),
        );
        await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
        var output = await w.exportVideo(
          File('${root.path}/fork.mp4'),
          captureFrames: [30],
        );
        expect(output['preEncoderSamples'][0]['rgba'], orderedEquals(mid.rgba));
        final active =
            w.current.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
                as String;
        w.edit(
          SplitClip(active, Q.of(1), 'transform-key-right'),
          expectedRevision: w.current.revision,
        );
        output = await w.exportVideo(
          File('${root.path}/split.mp4'),
          captureFrames: [30],
        );
        expect(output['preEncoderSamples'][0]['rgba'], orderedEquals(mid.rgba));
      } finally {
        w.close();
        root.deleteSync(recursive: true);
      }
    },
    skip: lib == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
