import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

void main() {
  final library = Platform.environment['STUDIO_MEDIA_LIBRARY'];
  test(
    'real local video import → split/trim/slip → save/fork/reopen → native MP4 export',
    () async {
      final dir = Directory.systemTemp.createTempSync('studio-real-video-');
      final source = File('${dir.path}/synthetic.mp4');
      final generated = Process.runSync('ffmpeg', [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'testsrc2=size=320x180:rate=30:duration=3',
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
        '-an',
        source.path,
      ]);
      expect(generated.exitCode, 0, reason: generated.stderr.toString());
      StudioWorkspace open(String app) => StudioWorkspace.open(
        profile: AppProfile(
          appId: app,
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${dir.path}/$app.sqlite',
        tenantId: 'local',
        workspaceId: 'test',
        mediaLibraryPath: library,
        mediaRootPath: '${dir.path}/media',
      );
      var workspace = open('studio');
      StudioWorkspace? restored;
      try {
        workspace.openDemo();
        await workspace.importVideo(
          LocalFileGrant.fromUserSelection(source),
          expectedRevision: BigInt.zero,
        );
        final clipId =
            workspace.current
                    .toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
                as String;
        workspace.edit(
          SplitClip(clipId, Q.of(1), 'right-test'),
          expectedRevision: workspace.current.revision,
        );
        workspace.edit(
          DeleteClip(clipId, ripple: true),
          expectedRevision: workspace.current.revision,
        );
        workspace.edit(
          TrimClip('right-test', 'out', Q.of(-1, 2), ripple: true),
          expectedRevision: workspace.current.revision,
        );
        workspace.edit(
          SlipClip('right-test', Q.of(1, 2)),
          expectedRevision: workspace.current.revision,
        );
        expect(
          Q.fromJson(workspace.current.toJson()['sequences'][0]['duration']),
          Q.of(3, 2),
        );
        await expectLater(
          workspace.saveArchive(source),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'PROTECTED_SOURCE_OUTPUT',
            ),
          ),
        );
        final archive = File('${dir.path}/project.studioproj');
        await workspace.saveArchive(archive);
        final saved = workspace.current;
        workspace.close();
        workspace = open('studio');
        expect(workspace.openDemo().hash, saved.hash);
        final exported = File('${dir.path}/result.mp4');
        exported.writeAsBytesSync([9, 8, 7]);
        final canceled = workspace.exportVideo(exported);
        workspace.cancelExport();
        await expectLater(
          canceled,
          throwsA(
            isA<StudioException>().having((e) => e.code, 'code', 'CANCELED'),
          ),
        );
        expect(exported.readAsBytesSync(), [9, 8, 7]);
        final pending = workspace.exportVideo(exported);
        workspace.rename(
          'Edited while exporting',
          expectedRevision: saved.revision,
        );
        final receipt = await pending;
        expect(workspace.current.revision, BigInt.from(6));
        expect(receipt['warnings'], contains('LICENSE_EVIDENCE_MISSING'));
        expect(receipt['frames'], 45);
        expect(receipt['audio'], 'video-only');
        expect(receipt['revision'], '5');
        final inspection = Process.runSync('ffprobe', [
          '-v',
          'error',
          '-select_streams',
          'v:0',
          '-count_frames',
          '-show_entries',
          'stream=codec_name,nb_read_frames,duration,width,height',
          '-of',
          'json',
          exported.path,
        ]);
        expect(inspection.exitCode, 0);
        expect(
          inspection.stdout.toString(),
          contains('"nb_read_frames": "45"'),
        );
        restored = open('image');
        restored.openDemo();
        final fork = await restored.restoreArchive(
          LocalFileGrant.fromUserSelection(archive),
        );
        expect(fork.namespace.appId, 'image');
        expect(fork.projectId, isNot(saved.projectId));
        expect(
          fork.toJson()['sequences'][0]['id'],
          isNot(saved.toJson()['sequences'][0]['id']),
        );
        final forkOutput = File('${dir.path}/fork.mp4');
        final forkReceipt = await restored.exportVideo(forkOutput);
        expect(forkReceipt['frames'], 45);
        expect(forkOutput.readAsBytesSync(), exported.readAsBytesSync());
        await expectLater(
          workspace.media!.renderAsync({
            'outputPath': '${dir.path}/bad.pending',
            'width': 320,
            'height': 180,
            'fps': {'n': 30, 'd': 1},
            'frameCount': 1,
            'segments': [
              {
                'path': source.absolute.path,
                'startFrame': 0,
                'frameCount': 1,
                'sourceStart': Q.of(3).toJson(),
                'streamIndex': 0,
              },
            ],
          }),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'SOURCE_AFTER_LAST_FRAME',
            ),
          ),
        );
        expect(source.existsSync(), true);
      } finally {
        restored?.close();
        workspace.close();
        dir.deleteSync(recursive: true);
      }
    },
    skip: library == null
        ? 'Set STUDIO_MEDIA_LIBRARY to the real compiled C++ adapter; not counted as validated without it'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
