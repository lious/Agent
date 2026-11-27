import 'dart:io';
import 'dart:math' as math;

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

import 'dissolve_fixture.dart';

void main() {
  final lib = Platform.environment['STUDIO_MEDIA_LIBRARY'];
  test('REAL incomingLuma CPU wipe: formula endpoints, no dissolve fallback, preview matches pre-encoder, undo restoreSnapshot', () async {
    final root = Directory.systemTemp.createTempSync('luma-wipe-render-');
    StudioWorkspace open() => StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${root.path}/db',
      tenantId: 'local',
      workspaceId: 'luma-wipe',
      mediaLibraryPath: lib,
      mediaRootPath: '${root.path}/media',
    );
    var w = open();
    try {
      await installDissolveFixture(w, root);
      expect(w.media!.capabilities['lumaWipeCpuV1'], isTrue);
      final clips = w.current.toJson()['sequences'][0]['tracks'][0]['items'];
      final left = clips[0]['id'] as String, right = clips[1]['id'] as String;
      final a = await w.previewTimelineAt(Q.of(1, 2)),
          b = await w.previewTimelineAt(Q.of(3, 2));
      final before = w.current.toJson();
      w.setLumaWipe(
        left,
        right,
        Q.of(1, 5),
        Q.of(1, 5),
        softness: 0.1,
        expectedRevision: w.current.revision,
      );
      expect(w.current.toJson()['transitions'], isEmpty);
      expect(lumaWipeEffects(w.current.toJson()), hasLength(1));
      final graph = TimelineVideoGraph(w.current);
      final compiled = graph.compileDissolves({
        for (final c in clips)
          c['id'] as String: {'path': '/x', 'streamIndex': 0},
      });
      for (final s in compiled.where((s) => s['secondary'] != null)) {
        expect(s.containsKey('mixFramesQ16'), isFalse);
        expect(s['lumaWipe'], isNotNull);
      }
      final start = await w.previewTimelineAt(Q.of(4, 5));
      expect(start.rgba, orderedEquals(a.rgba));
      final afterWindow = await w.previewTimelineAt(Q.of(6, 5));
      expect(afterWindow.rgba, orderedEquals(b.rgba));

      double linear(int v) {
        final x = v / 255.0;
        return x < .081
            ? x / 4.5
            : math.pow((x + .099) / 1.099, 1 / .45).toDouble();
      }

      int encode(double l) =>
          ((l < .018 ? 4.5 * l : 1.099 * math.pow(l, .45) - .099) * 255)
              .round();

      final midTime = Q.of(1);
      final mid = await w.previewTimelineAt(midTime);
      final br = linear(b.rgba[200]),
          bg = linear(b.rgba[201]),
          bb = linear(b.rgba[202]);
      final wgt = lumaWipeWeight(
        p: 0.5,
        red: br,
        green: bg,
        blue: bb,
        softness: 0.1,
        invert: false,
      );
      final expected = encode((1 - wgt) * linear(a.rgba[200]) + wgt * br);
      expect((mid.rgba[200] - expected).abs(), lessThanOrEqualTo(3));
      // A 50% dissolve of white/black would be near mid grey; incoming black
      // luma keeps the mix away from that uniform dissolve path.
      final dissolveMid = encode((linear(a.rgba[200]) + br) / 2);
      expect((mid.rgba[200] - dissolveMid).abs(), greaterThan(8));

      final frames = [24, 30, 35];
      final previews = [
        for (final f in frames) await w.previewTimelineAt(Q.of(f, 30)),
      ];
      final out = await w.exportVideo(
        File('${root.path}/luma.mp4'),
        captureFrames: frames,
      );
      for (var i = 0; i < frames.length; i++) {
        expect(
          out['preEncoderSamples'][i]['rgba'],
          orderedEquals(previews[i].rgba),
        );
      }
      w.undo(expectedRevision: w.current.revision);
      expect(lumaWipeEffects(w.current.toJson()), isEmpty);
      expect(w.current.toJson()['requiredFeatures'], isEmpty);
      final restored = w.current.toJson()..['revision'] = before['revision'];
      expect(contentHash(restored), contentHash(before));
      expect(w.current.toJson()['transitions'], isEmpty);
    } finally {
      w.close();
      root.deleteSync(recursive: true);
    }
  }, skip: lib == null);
}
