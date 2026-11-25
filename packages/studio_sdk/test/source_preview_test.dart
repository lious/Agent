import 'dart:io';

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));
void main() {
  final library = Platform.environment['STUDIO_MEDIA_LIBRARY'],
      fixture = Platform.environment['STUDIO_TEST_VIDEO'];
  test('REAL FFmpeg indexed seeks equal sequential PTS/pixels at20 random CFR points plus nonzero PTS and VFR', () async {
    final root = Directory.systemTemp.createTempSync('real-index-seek-');
    final media = NativeMedia.open(
      library!,
      Namespace('seek', 'local', 'reference'),
    );
    try {
      final cfr = File('${root.path}/gop.mp4');
      final generated = Process.runSync('ffmpeg', [
        '-v',
        'error',
        '-i',
        fixture!,
        '-g',
        '15',
        '-keyint_min',
        '15',
        '-sc_threshold',
        '0',
        '-c:v',
        'libx264',
        '-an',
        cfr.path,
      ]);
      expect(generated.exitCode, 0, reason: '${generated.stderr}');
      var demonstratedIndexedGain = false;
      for (final n in [
        0,
        89,
        15,
        44,
        3,
        63,
        29,
        60,
        75,
        1,
        50,
        21,
        88,
        30,
        17,
        68,
        37,
        80,
        8,
        54,
      ]) {
        final indexed = SourcePreviewFrame(
              await media.previewAsync(cfr, Q.of(n, 30)),
            ),
            reference = SourcePreviewFrame(
              await media.previewAsync(cfr, Q.of(n, 30), indexed: false),
            );
        expect(indexed.pts, reference.pts);
        expect(
          Q(indexed.pts - indexed.startPts, BigInt.one) * indexed.timeBase,
          Q.of(n, 30),
        );
        expect(rawBytesHash(indexed.rgba), rawBytesHash(reference.rgba));
        expect(indexed.width <= 128 && indexed.height <= 128, isTrue);
        if (indexed.packetsRead < reference.packetsRead) {
          demonstratedIndexedGain = true;
        }
      }
      expect(demonstratedIndexedGain, isTrue);
      final offset = File('${root.path}/offset.mp4');
      final shifted = Process.runSync('ffmpeg', [
        '-v',
        'error',
        '-i',
        cfr.path,
        '-c',
        'copy',
        '-output_ts_offset',
        '7',
        offset.path,
      ]);
      expect(shifted.exitCode, 0);
      final off = SourcePreviewFrame(
            await media.previewAsync(offset, Q.of(3, 2)),
          ),
          offRef = SourcePreviewFrame(
            await media.previewAsync(offset, Q.of(3, 2), indexed: false),
          );
      expect(off.startPts, greaterThan(BigInt.zero));
      expect(off.pts, offRef.pts);
      expect(Q(off.pts - off.startPts, BigInt.one) * off.timeBase, Q.of(3, 2));
      expect(rawBytesHash(off.rgba), rawBytesHash(offRef.rgba));
      final vfr = File('${root.path}/vfr.mp4');
      final variable = Process.runSync('ffmpeg', [
        '-v',
        'error',
        '-i',
        cfr.path,
        '-vf',
        "setpts='if(lt(N,45),N,45+(N-45)*2)/(30*TB)'",
        '-fps_mode',
        'vfr',
        '-c:v',
        'libx264',
        '-g',
        '15',
        '-an',
        vfr.path,
      ]);
      expect(variable.exitCode, 0, reason: '${variable.stderr}');
      for (final ms in [1400, 1600, 2100, 3200]) {
        final a = SourcePreviewFrame(
              await media.previewAsync(vfr, Q.of(ms, 1000)),
            ),
            b = SourcePreviewFrame(
              await media.previewAsync(vfr, Q.of(ms, 1000), indexed: false),
            );
        expect(a.pts, b.pts);
        final sourceTime = Q(a.pts - a.startPts, BigInt.one) * a.timeBase;
        expect(sourceTime <= Q.of(ms, 1000), isTrue);
        expect(Q.of(ms, 1000) - sourceTime < Q.of(2, 30), isTrue);
        if (ms == 1600) expect(sourceTime, Q.of(47, 30));
        expect(rawBytesHash(a.rgba), rawBytesHash(b.rgba));
      }
      await expectLater(
        media.previewAsync(cfr, Q.of(-1)),
        code('RECIPE_RANGE'),
      );
      final multi = File('${root.path}/multi.mp4');
      expect(
        Process.runSync('ffmpeg', [
          '-v',
          'error',
          '-i',
          cfr.path,
          '-map',
          '0:v',
          '-map',
          '0:v',
          '-c',
          'copy',
          multi.path,
        ]).exitCode,
        0,
      );
      await expectLater(
        media.previewAsync(multi, Q.of(0)),
        code('MULTI_VIDEO_STREAM_PREVIEW_UNSUPPORTED'),
      );
      final hdr = File('${root.path}/hdr.mp4');
      expect(
        Process.runSync('ffmpeg', [
          '-v',
          'error',
          '-i',
          cfr.path,
          '-c:v',
          'libx264',
          '-color_primaries',
          'bt2020',
          '-color_trc',
          'smpte2084',
          '-colorspace',
          'bt2020nc',
          hdr.path,
        ]).exitCode,
        0,
      );
      await expectLater(
        media.previewAsync(hdr, Q.of(0)),
        code('COLOR_POLICY_REQUIRED'),
      );
      await expectLater(
        media.previewAsync(cfr, Q.of(4)),
        code('SOURCE_AFTER_LAST_FRAME'),
      );
    } finally {
      media.close();
      root.deleteSync(recursive: true);
    }
  }, skip: library == null || fixture == null);
  test('REAL source preview LRU immutable bytes, budget/eviction/oversize and SDK superseded request cannot return stale frame', () async {
    final root = Directory.systemTemp.createTempSync('preview-sdk-');
    final w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${root.path}/db',
      tenantId: 'local',
      workspaceId: 'preview',
      mediaLibraryPath: library,
      mediaRootPath: '${root.path}/media',
    );
    try {
      w.openDemo();
      await w.importVideo(
        LocalFileGrant.fromUserSelection(File(fixture!)),
        expectedRevision: BigInt.zero,
      );
      final id = w.current.toJson()['assets'][0]['id'] as String;
      final a = await w.previewAssetSource(id, Q.of(0));
      expect(identical(await w.previewAssetSource(id, Q.of(0)), a), isTrue);
      final cache = SourcePreviewCache(budgetBytes: a.rgba.length * 2);
      cache.put('a', a);
      cache.put('b', a);
      expect(cache.get('a'), same(a));
      cache.put('c', a);
      expect(cache.get('b'), isNull);
      expect(cache.bytes, a.rgba.length * 2);
      expect(() => a.rgba[0] = 0, throwsUnsupportedError);
      expect(
        () => SourcePreviewFrame({
          'width': 1,
          'height': 1,
          'rgba': [0, 0, 0, 256],
        }),
        code('PREVIEW_FRAME_INVALID'),
      );
      expect(
        () => SourcePreviewFrame({'width': 99999999, 'height': 1, 'rgba': []}),
        code('PREVIEW_FRAME_INVALID'),
      );
      final capped = SourcePreviewCache(budgetBytes: 64 * 1024 * 1024);
      for (var n = 0; n < 300; n++) {
        capped.put('k$n', a);
      }
      expect(capped.entries, 256);
      expect(capped.get('k0'), isNull);
      final noCache = SourcePreviewCache(budgetBytes: 0)..put('a', a);
      expect(noCache.entries, 0);
      expect(
        () => SourcePreviewCache(budgetBytes: -1),
        code('CACHE_BUDGET_INVALID'),
      );
      final old = w.previewAssetSource(id, Q.of(1)),
          fresh = w.previewAssetSource(id, Q.of(2));
      await expectLater(old, code('PREVIEW_SUPERSEDED'));
      final result = await fresh;
      expect(result.pts, greaterThan(a.pts));
      final changed = w.previewAssetSource(id, Q.of(3, 2));
      w.rename('changed while loading', expectedRevision: w.current.revision);
      await expectLater(changed, code('PREVIEW_PROJECT_CHANGED'));
      await expectLater(
        w.previewAssetSource(id, Q.of(-1)),
        code('PREVIEW_TIME_INVALID'),
      );
      final closing = w.previewAssetSource(id, Q.of(5, 2));
      w.close();
      await expectLater(closing, code('PREVIEW_SUPERSEDED'));
      expect(
        w.sourcePreviewCache.bytes,
        lessThanOrEqualTo(w.sourcePreviewCache.budgetBytes),
      );
    } finally {
      w.close();
      root.deleteSync(recursive: true);
    }
  }, skip: library == null || fixture == null);
}
