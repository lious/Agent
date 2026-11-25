import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

void main() {
  test(
    'actual caption-before-video append, portable archive/fork and sidecar preserve cues; unsupported MP4 text render refuses',
    () async {
      final dir = Directory.systemTemp.createTempSync('caption-media-'),
          w = StudioWorkspace.open(
            profile: AppProfile(
              appId: 'studio',
              region: 'local',
              features: {'project.metadata', 'media.local'},
            ),
            databasePath: '${dir.path}/db',
            tenantId: 'local',
            workspaceId: 'caps',
            mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
            mediaRootPath: '${dir.path}/media',
          );
      try {
        w.openDemo();
        w.edit(
          SetCaptions(
            CaptionStore([
              CaptionCue(
                'manual',
                TimeRange(Q.of(123, 1000), Q.of(4)),
                '你好🙂 שלום',
                manualFields: {'text', 'timing'},
              ),
            ]),
          ),
          expectedRevision: BigInt.zero,
        );
        await w.importVideo(
          LocalFileGrant.fromUserSelection(
            File(Platform.environment['STUDIO_TEST_VIDEO']!),
          ),
          expectedRevision: BigInt.one,
        );
        expect(
          w.current.toJson()['sequences'][0]['tracks'][0]['kind'],
          'video',
        );
        expect(
          w.current
              .toJson()['sequences'][0]['tracks'][0]['items'][0]['timelineRange']['start'],
          Q.of(0).toJson(),
        );
        final archive = File('${dir.path}/project.archive');
        await w.saveArchive(archive);
        await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
        expect(w.current.toJson()['captions'][0]['text'], '你好🙂 שלום');
        final output = File('${dir.path}/out.vtt');
        w.exportCaptions(output, CaptionFormat.vtt);
        expect(
          CaptionFormats.decode(
            output.readAsStringSync(),
            CaptionFormat.vtt,
          ).captions.cues.single.range.start,
          Q.of(123, 1000),
        );
        await expectLater(
          w.exportVideo(File('${dir.path}/no-silent-loss.mp4')),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'CAPTION_RENDER_POLICY_NOT_IMPLEMENTED',
            ),
          ),
        );
        expect(File('${dir.path}/no-silent-loss.mp4').existsSync(), false);
      } finally {
        w.close();
        dir.deleteSync(recursive: true);
      }
    },
    skip:
        Platform.environment['STUDIO_MEDIA_LIBRARY'] == null ||
        Platform.environment['STUDIO_TEST_VIDEO'] == null,
  );
}
