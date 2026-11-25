@Tags(['audio_service'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';

Future<Map<String, dynamic>> until(
  StudioWorkspace w,
  bool Function(Map<String, dynamic>) predicate,
) async {
  final end = DateTime.now().add(const Duration(seconds: 8));
  Map<String, dynamic> last = {};
  while (DateTime.now().isBefore(end)) {
    last = w.timelinePlayback;
    if (predicate(last)) return last;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('service timeout $last');
}

void main() {
  test('REAL Pulse SDK timeline prepare, confirmed clock, pause/seek/rebind/edit fence/cancel/close', () async {
    final dir = Directory.systemTemp.createTempSync('sdk-pulse-');
    final w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${dir.path}/db',
      tenantId: 'local',
      workspaceId: 'pulse',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${dir.path}/media',
    );
    Process? capture;
    Future<void>? captured;
    final monitor = File('${dir.path}/monitor.f32');
    try {
      capture = await Process.start('parec', [
        '--device=studio_test.monitor',
        '--format=float32le',
        '--rate=48000',
        '--channels=2',
        '--raw',
      ]);
      captured = capture.stdout.pipe(monitor.openWrite());
      w.openDemo();
      final av = File('${dir.path}/source.mp4');
      final made = Process.runSync('ffmpeg', [
        '-v',
        'error',
        '-stream_loop',
        '2',
        '-i',
        Platform.environment['STUDIO_TEST_VIDEO']!,
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=1000:sample_rate=44100',
        '-t',
        '9',
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
      final d = w.current.toJson(),
          v = d['sequences'][0]['tracks'][0]['items'][0];
      final a = (d['assets'][0]['streams'] as List).singleWhere(
        (s) => s['type'] == 'audio',
      );
      w.edit(
        ExtractAudioClip(v['id'] as String, a['id'] as String),
        expectedRevision: w.current.revision,
      );
      await w.playTimeline(sink: 'studio_test');
      final playing = await until(
        w,
        (s) =>
            s['state'] == 'playing' &&
            s['clockValid'] == true &&
            (s['presentedSample'] as int) > 4800,
      );
      expect(
        playing['submittedSamples'],
        greaterThan(playing['presentedSample']),
      );
      expect(playing['ringHighWaterFrames'], lessThanOrEqualTo(8192));
      w.controlTimelinePlayback('pause');
      await until(w, (s) => s['state'] == 'paused' && s['clockValid'] == true);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final paused = w.timelinePlayback;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(w.timelinePlayback['presentedSample'], paused['presentedSample']);
      w.controlTimelinePlayback('seek', sample: 48000);
      final seek = await until(
        w,
        (s) => s['state'] == 'paused' && s['clockValid'] == true,
      );
      expect(seek['presentedSample'], 48000);
      expect(seek['epoch'], greaterThan(playing['epoch']));
      w.controlTimelinePlayback('resume');
      await until(
        w,
        (s) => s['clockValid'] == true && (s['presentedSample'] as int) > 52000,
      );
      w.controlTimelinePlayback('rebind', sink: 'second');
      final rebound = await until(
        w,
        (s) =>
            s['state'] == 'paused' &&
            s['sink'] == 'second' &&
            s['clockValid'] == true,
      );
      expect(rebound['epoch'], greaterThan(seek['epoch']));
      w.setMasterAudio(gainDb: -6, expectedRevision: w.current.revision);
      expect(w.timelinePlayback['state'], 'stopped');
      final pending = w.playTimeline(sink: 'studio_test');
      w.pauseTimelinePlaybackForLifecycle();
      await expectLater(
        pending,
        throwsA(
          isA<StudioException>().having((e) => e.code, 'code', 'CANCELED'),
        ),
      );
      expect(w.timelinePlayback['state'], 'stopped');
      final cancelInFlight = w.playTimeline(sink: 'studio_test');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      w.stopTimelinePlayback();
      await expectLater(
        cancelInFlight,
        throwsA(
          isA<StudioException>().having((e) => e.code, 'code', 'CANCELED'),
        ),
      );
      await w.playTimeline(sink: 'studio_test');
      await until(w, (s) => s['clockValid'] == true);
      w.close();
      expect(w.timelinePlayback['state'], 'stopped');
      capture.kill();
      await capture.exitCode;
      await captured;
      capture = null;
      final bytes = monitor.readAsBytesSync(),
          pcm = ByteData.sublistView(bytes);
      expect(bytes.length, greaterThan(4800 * 8));
      var sum = 0.0;
      for (var i = 0; i + 4 <= bytes.length; i += 4) {
        final sample = pcm.getFloat32(i, Endian.little);
        if (!sample.isFinite) fail('nonfinite service capture');
        sum += sample * sample;
      }
      expect(
        math.sqrt(sum / (bytes.length ~/ 4)),
        greaterThan(.005),
        reason: 'Actual SDK-produced audio must reach the real service monitor, not a fake sink',
      );
    } finally {
      if (capture != null) {
        capture.kill();
        await capture.exitCode;
        await captured;
      }
      w.close();
      dir.deleteSync(recursive: true);
    }
  });
}
