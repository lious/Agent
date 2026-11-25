import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'dissolve_fixture.dart';

double linear(int v) {
  final x = v / 255;
  return x < .081 ? x / 4.5 : math.pow((x + .099) / 1.099, 1 / .45).toDouble();
}

int encoded(double v) =>
    ((v < .018 ? v * 4.5 : 1.099 * math.pow(v, .45) - .099) * 255)
        .round()
        .clamp(0, 255);
int pixel(SourcePreviewFrame f, int x, [int y = 36]) =>
    f.rgba[(y * 128 + x) * 4];
void main() {
  final lib = Platform.environment['STUDIO_MEDIA_LIBRARY'];
  test(
    'REAL source crop coverage, colour order/late clamp, single inverse/SQL rollback, two-leg effects→MP4/archive/fork/admission/reopen',
    () async {
      final root = Directory.systemTemp.createTempSync('raster-render-');
      StudioWorkspace open() => StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${root.path}/db',
        tenantId: 'local',
        workspaceId: 'raster',
        mediaLibraryPath: lib,
        mediaRootPath: '${root.path}/media',
      );
      var w = open();
      try {
        await installDissolveFixture(w, root);
        final clips = w.current.toJson()['sequences'][0]['tracks'][0]['items'];
        final left = clips[0]['id'] as String,
            right = clips[1]['id'] as String,
            asset = clips[0]['source']['id'] as String;
        final before = w.current.toJson();
        w.setClipCrop(left, {
          ...identityCrop,
          'left': 64.5 / 128,
        }, expectedRevision: w.current.revision);
        final cropped = await w.previewTimelineAt(Q.of(1, 2));
        expect(pixel(cropped, 20), lessThanOrEqualTo(1));
        expect((pixel(cropped, 64) - encoded(.5)).abs(), lessThanOrEqualTo(2));
        expect(pixel(cropped, 90), greaterThanOrEqualTo(253));
        w.undo(expectedRevision: w.current.revision);
        final restored = w.current.toJson()..['revision'] = before['revision'];
        expect(contentHash(restored), contentHash(before));
        final db = sql.sqlite3.open('${root.path}/db'), hash = w.current.hash;
        try {
          db.execute(
            "CREATE TRIGGER raster_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'isolated_raster_fixture');END",
          );
          expect(
            () => w.setClipColorBasic(left, {
              ...identityColorBasic,
              'contrast': 0,
            }, expectedRevision: w.current.revision),
            throwsA(isA<sql.SqliteException>()),
          );
          expect(w.current.hash, hash);
          db.execute('DROP TRIGGER raster_fail');
        } finally {
          db.dispose();
        }
        w.setClipCrop(left, {
          ...identityCrop,
          'left': 64.5 / 128,
        }, expectedRevision: w.current.revision);
        w.setClipColorBasic(left, {
          ...identityColorBasic,
          'contrast': 0,
        }, expectedRevision: w.current.revision);
        final contrast = await w.previewTimelineAt(Q.of(1, 2));
        expect(pixel(contrast, 20), lessThanOrEqualTo(1));
        expect(
          (pixel(contrast, 64) - encoded(.09)).abs(),
          lessThanOrEqualTo(2),
        );
        expect(
          (pixel(contrast, 90) - encoded(.18)).abs(),
          lessThanOrEqualTo(2),
        );
        w.setClipCrop(left, identityCrop, expectedRevision: w.current.revision);
        w.setClipColorBasic(left, {
          ...identityColorBasic,
          'exposureStops': 2,
          'contrast': .2,
        }, expectedRevision: w.current.revision);
        w.setClipOpacity(left, .25, expectedRevision: w.current.revision);
        expect(
          (pixel(await w.previewTimelineAt(Q.of(1, 2)), 90) -
                  encoded(((4 - .18) * .2 + .18) * .25))
              .abs(),
          lessThanOrEqualTo(2),
        );
        w.setClipOpacity(left, 1, expectedRevision: w.current.revision);
        w.setClipColorBasic(left, {
          ...identityColorBasic,
          'exposureStops': 1,
        }, expectedRevision: w.current.revision);
        w.setDissolve(
          left,
          right,
          Q.of(1, 5),
          Q.of(1, 5),
          expectedRevision: w.current.revision,
        );
        expect(
          pixel(await w.previewTimelineAt(Q.of(1)), 90),
          greaterThanOrEqualTo(253),
        ); // no clipping of EV before dissolve.
        w.setClipCrop(left, {
          ...identityCrop,
          'left': .25,
          'top': .1,
          'right': .9,
          'bottom': .9,
        }, expectedRevision: w.current.revision);
        w.setClipTransform(left, {
          ...identityTransform2d,
          'translateX': 8,
          'rotationDeg': 10,
        }, expectedRevision: w.current.revision);
        w.setOpacityKeyframe(
          left,
          Q.of(0),
          .25,
          expectedRevision: w.current.revision,
        );
        w.setOpacityKeyframe(
          left,
          Q.of(1),
          .75,
          expectedRevision: w.current.revision,
        );
        w.setClipCrop(right, {
          ...identityCrop,
          'left': .1,
          'right': .9,
        }, expectedRevision: w.current.revision);
        w.setClipColorBasic(right, {
          ...identityColorBasic,
          'contrast': 0,
        }, expectedRevision: w.current.revision);
        final frames = [24, 30, 35, 36],
            previews = [
              for (final f in frames) await w.previewTimelineAt(Q.of(f, 30)),
            ];
        var out = await w.exportVideo(
          File('${root.path}/raster.mp4'),
          captureFrames: frames,
        );
        for (var i = 0; i < frames.length; i++) {
          expect(
            out['preEncoderSamples'][i]['rgba'],
            orderedEquals(previews[i].rgba),
          );
        }
        final mutable = {...identityCrop, 'left': .5};
        final pending = w.previewAssetSource(
          asset,
          Q.of(1, 2),
          rasterEffects: {'crop': mutable},
        );
        mutable['left'] = 0;
        expect(pixel(await pending, 20), lessThanOrEqualTo(1));
        final archive = File('${root.path}/project.zip');
        await w.saveArchive(archive);
        final saved = w.current.hash;
        w.close();
        w = open();
        w.openDemo();
        expect(w.current.hash, saved);
        await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
        final session = await ResourcePreservationSession.openArchive(
          LocalFileGrant.fromUserSelection(archive),
        );
        await w.adoptPreservedResources(
          session,
          expectedCollectionReviewHash: session.collectionReviewHash,
          expectedActiveHash: w.current.hash,
          confirmed: true,
        );
        final fork = w.current.hash;
        w.close();
        w = open();
        w.openDemo();
        expect(w.current.hash, fork);
        out = await w.exportVideo(
          File('${root.path}/reopened.mp4'),
          captureFrames: frames,
        );
        for (var i = 0; i < frames.length; i++) {
          expect(
            out['preEncoderSamples'][i]['rgba'],
            orderedEquals(previews[i].rgba),
          );
        }
        expect(
          () => w.setClipCrop(
            w.current.toJson()['transitions'][0]['leftClipId'],
            identityCrop,
            expectedRevision: w.current.revision - BigInt.one,
          ),
          throwsA(isA<StudioException>()),
        );
      } finally {
        w.close();
        root.deleteSync(recursive: true);
      }
    },
    skip: lib == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test('REAL coloured-source luma/saturation golden keeps negative and >1 intermediates until final transfer', () async {
    final root = Directory.systemTemp.createTempSync('raster-colour-');
    final red = File('${root.path}/red.mp4');
    final r = await Process.run('ffmpeg', [
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'color=c=red:s=128x72:r=30:d=1',
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
      red.path,
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final media = NativeMedia.open(
      lib!,
      Namespace('studio', 'local', 'raster-colour'),
    );
    try {
      final source = await media.previewAsync(red, Q.of(0)),
          px = source['rgba'] as List;
      final rgb = [
        for (var c = 0; c < 3; c++)
          (linear(px[200 + c] as int) * math.sqrt2 - .18) * 1.2 + .18,
      ];
      final luma = .2126 * rgb[0] + .7152 * rgb[1] + .0722 * rgb[2];
      final sample = await media.previewAsync(
        red,
        Q.of(0),
        rasterEffects: {
          'colorBasic': {'exposureStops': .5, 'contrast': 1.2, 'saturation': 0},
        },
      );
      for (var c = 0; c < 3; c++) {
        expect(
          ((sample['rgba'][200 + c] as int) - encoded(luma)).abs(),
          lessThanOrEqualTo(2),
        );
      }
    } finally {
      media.close();
      root.deleteSync(recursive: true);
    }
  }, skip: lib == null);
  test('REAL malformed raster primary/secondary reject before creating encoder output', () async {
    final root = Directory.systemTemp.createTempSync('bad-raster-'),
        input = Platform.environment['STUDIO_TEST_VIDEO']!;
    final media = NativeMedia.open(
      lib!,
      Namespace('studio', 'local', 'bad-raster'),
    );
    try {
      for (final bad in <Map<String, dynamic>>[
        {},
        {
          'lua': {'code': 'never_execute'},
        },
        {
          'crop': {...identityCrop, 'left': 1},
        },
        {
          'crop': {...identityCrop, 'extra': 0},
        },
        {
          'colorBasic': {...identityColorBasic, 'exposureStops': 9},
        },
        {
          'colorBasic': {...identityColorBasic, 'saturation': '1'},
        },
      ]) {
        for (final side in ['primary', 'secondary']) {
          final out = File('${root.path}/bad.mp4');
          final segment = <String, dynamic>{
            'path': input,
            'streamIndex': 0,
            'sourceStart': Q.of(0).toJson(),
            'startFrame': 0,
            'frameCount': 90,
          };
          if (side == 'primary') {
            segment['rasterEffects'] = bad;
          } else {
            segment['secondary'] = {
              'path': input,
              'streamIndex': 0,
              'sourceStart': Q.of(0).toJson(),
              'rasterEffects': bad,
            };
            segment['mixFramesQ16'] = List.filled(90, 32768);
          }
          await expectLater(
            media.renderAsync({
              'outputPath': out.path,
              'width': 320,
              'height': 180,
              'fps': {'n': 30, 'd': 1},
              'frameCount': 90,
              'segments': [segment],
            }),
            throwsA(isA<StudioException>()),
          );
          expect(out.existsSync(), isFalse);
        }
      }
    } finally {
      media.close();
      root.deleteSync(recursive: true);
    }
  }, skip: lib == null || Platform.environment['STUDIO_TEST_VIDEO'] == null);
}
