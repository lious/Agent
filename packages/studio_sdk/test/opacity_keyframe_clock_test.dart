@Tags(['audio_service'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';

import 'timeline_audio_test.dart' show until;

void main() {
  test('REAL Pulse confirmed-sample clock consumes clip-local opacity curve; paused seek pixels match, edits invalidate', () async {
    final dir = Directory.systemTemp.createTempSync('opacity-clock-');
    final w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${dir.path}/db',
      tenantId: 'local',
      workspaceId: 'opacity-clock',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${dir.path}/media',
    );
    try {
      w.openDemo();
      final av = File('${dir.path}/source.mp4');
      final made = Process.runSync('ffmpeg', [
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
      expect(made.exitCode, 0, reason: '${made.stderr}');
      await w.importVideo(
        LocalFileGrant.fromUserSelection(av),
        expectedRevision: w.current.revision,
        acknowledgeVideoOnly: true,
      );
      final clip =
          w.current.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
              as String;
      w.setOpacityKeyframe(
        clip,
        Q.of(0),
        0,
        expectedRevision: w.current.revision,
      );
      w.setOpacityKeyframe(
        clip,
        Q.of(2),
        1,
        expectedRevision: w.current.revision,
      );
      final stream = (w.current.toJson()['assets'][0]['streams'] as List)
          .singleWhere((s) => s['type'] == 'audio');
      w.edit(
        ExtractAudioClip(clip, stream['id'] as String),
        expectedRevision: w.current.revision,
      );

      await w.buildTimelinePreviewProxies();
      await w.playTimeline(sink: 'studio_test');
      await until(
        w,
        (s) =>
            s['clockValid'] == true &&
            s['state'] == 'playing' &&
            (s['presentedSample'] as int) > 4800,
      );
      w.controlTimelinePlayback('pause');
      await until(w, (s) => s['clockValid'] == true && s['state'] == 'paused');
      w.controlTimelinePlayback('seek', sample: 48000);
      await until(w, (s) => s['clockValid'] == true && s['state'] == 'paused');
      final frame = await w.renderTimelineFromAudioClock();
      expect(frame, isNotNull);
      expect(frame!.clockSample, 48000);
      expect(frame.proxyIndex, -1);
      final exact = await w.previewTimelineAt(Q.of(1));
      expect(frame.pixels.rgba, orderedEquals(exact.rgba));
      final stable = await w.renderTimelineFromAudioClock();
      expect(stable!.clockSample, frame.clockSample);
      expect(stable.pixels.rgba, orderedEquals(frame.pixels.rgba));
      w.controlTimelinePlayback('seek', sample: 0);
      await until(w, (s) => s['clockValid'] == true && s['state'] == 'paused');
      expect(w.isTimelineFrameCurrent(frame), false);
      final zero = await w.renderTimelineFromAudioClock();
      expect(zero!.clockSample, 0);
      expect(zero.pixels.pts, isNot(frame.pixels.pts));
      final zeroReference = await w.previewAssetSource(
        zero.assetId!,
        Q.of(0),
        opacityQ16: 0,
      );
      expect(zero.pixels.rgba, orderedEquals(zeroReference.rgba));
      // Same SDR YUV420 -> RGB8 display conversion as the static-node golden:
      // nominal black can round to 1, not an ideal unconverted RGB(0,0,0).
      for (var i = 0; i < zero.pixels.rgba.length; i++) {
        expect(
          zero.pixels.rgba[i],
          i % 4 == 3 ? equals(255) : inInclusiveRange(0, 1),
        );
      }
      w.setOpacityKeyframe(
        clip,
        Q.of(0),
        .25,
        expectedRevision: w.current.revision,
      );
      expect(w.timelinePlayback['state'], 'stopped');
      expect(w.isTimelineFrameCurrent(zero), false);
      expect(await w.renderTimelineFromAudioClock(), null);
    } finally {
      w.close();
      dir.deleteSync(recursive: true);
    }
  });
}
