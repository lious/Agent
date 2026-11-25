@Tags(['audio_service'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';

import 'timeline_audio_test.dart' show until;

void main() {
  test('REAL AudioSink-clock RenderGraph selects generated proxy, freezes paused, fences seek/rebind/revision and closes resources', () async {
    final root = Directory.systemTemp.createTempSync('timeline-video-');
    final w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${root.path}/db',
      tenantId: 'local',
      workspaceId: 'avgraph',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${root.path}/media',
    );
    try {
      w.openDemo();
      final av = File('${root.path}/av.mp4');
      expect(
        Process.runSync('ffmpeg', [
          '-v',
          'error',
          '-stream_loop',
          '2',
          '-i',
          Platform.environment['STUDIO_TEST_VIDEO']!,
          '-f',
          'lavfi',
          '-i',
          'sine=frequency=600:sample_rate=44100',
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
        ]).exitCode,
        0,
      );
      await w.importVideo(
        LocalFileGrant.fromUserSelection(av),
        expectedRevision: w.current.revision,
        acknowledgeVideoOnly: true,
      );
      final d = w.current.toJson(),
          clip = d['sequences'][0]['tracks'][0]['items'][0],
          audio = (d['assets'][0]['streams'] as List).singleWhere(
            (s) => s['type'] == 'audio',
          );
      w.edit(
        ExtractAudioClip(clip['id'] as String, audio['id'] as String),
        expectedRevision: w.current.revision,
      );
      final revision = w.current.hash,
          facts = await w.buildTimelinePreviewProxies();
      expect(facts['proxies'], 1);
      expect(w.current.hash, revision);
      expect(w.previewProxyBytes, lessThanOrEqualTo(64 * 1024 * 1024));
      expect((await w.buildTimelinePreviewProxies())['bytes'], facts['bytes']);
      await w.playTimeline(sink: 'studio_test');
      await until(
        w,
        (s) =>
            s['clockValid'] == true &&
            s['state'] == 'playing' &&
            (s['presentedSample'] as int) > 4800,
      );
      final indices = <int>{};
      for (var i = 0; i < 10; i++) {
        try {
          final frame = await w.renderTimelineFromAudioClock();
          expect(frame, isNotNull);
          if (frame != null) {
            indices.add(frame.proxyIndex);
            expect(frame.snapshotHash, revision);
            expect(frame.clockSample, greaterThan(0));
            expect(frame.pixels.rgba.any((v) => v != 0 && v != 255), isTrue);
          }
        } on StudioException catch (e) {
          if (e.code != 'TIMELINE_FRAME_STALE') rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      expect(
        indices.length,
        greaterThan(2),
        reason: 'real confirmed clock must select distinct actual video frames',
      );
      w.controlTimelinePlayback('pause');
      await until(w, (s) => s['state'] == 'paused' && s['clockValid'] == true);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final request = w.renderTimelineFromAudioClock();
      await expectLater(
        w.renderTimelineFromAudioClock(),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'TIMELINE_RENDER_BUSY',
          ),
        ),
      );
      final paused = await request;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final stable = await w.renderTimelineFromAudioClock();
      expect(stable!.clockSample, paused!.clockSample);
      expect(stable.proxyIndex, paused.proxyIndex);
      w.controlTimelinePlayback('seek', sample: 48000);
      await until(w, (s) => s['state'] == 'paused' && s['clockValid'] == true);
      expect(w.isTimelineFrameCurrent(paused), isFalse);
      final seek = await w.renderTimelineFromAudioClock();
      expect(seek!.proxyIndex, 30);
      expect(seek.clockSample, 48000);
      w.controlTimelinePlayback('rebind', sink: 'second');
      await until(w, (s) => s['state'] == 'paused' && s['clockValid'] == true);
      expect(w.isTimelineFrameCurrent(seek), isFalse);
      final rebound = await w.renderTimelineFromAudioClock();
      expect(rebound!.proxyIndex, 30);
      w.stopTimelinePlayback();
      await w.playTimeline(sink: 'studio_test');
      await until(w, (s) => s['clockValid'] == true && s['state'] == 'playing');
      final restarted = await w.renderTimelineFromAudioClock();
      expect(restarted!.playbackGeneration, isNot(rebound.playbackGeneration));
      expect(w.isTimelineFrameCurrent(rebound), isFalse);
      w.edit(
        SplitClip(clip['id'] as String, Q.of(1), 'graph-right'),
        expectedRevision: w.current.revision,
      );
      expect(w.isTimelineFrameCurrent(rebound), isFalse);
      expect(w.timelinePlayback['state'], 'stopped');
      expect(await w.renderTimelineFromAudioClock(), isNull);
      final pending = w.buildTimelinePreviewProxies();
      w.cancelPreviewProxyBuild();
      await expectLater(
        pending,
        throwsA(
          isA<StudioException>().having((e) => e.code, 'code', 'CANCELED'),
        ),
      );
      w.clearPreviewProxies();
      expect(w.previewProxyBytes, 0);
    } finally {
      w.close();
      root.deleteSync(recursive: true);
    }
  });
}
