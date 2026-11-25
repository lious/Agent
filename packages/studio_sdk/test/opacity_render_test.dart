import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  final lib = Platform.environment['STUDIO_MEDIA_LIBRARY'];
  final input = Platform.environment['STUDIO_TEST_VIDEO'];
  test(
    'REAL opacity edit/undo -> full-source preview -> actual preencoder pixels -> export/archive/fork/reopen',
    () async {
      final root = Directory.systemTemp.createTempSync('opacity-render-');
      StudioWorkspace open() => StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${root.path}/db',
        tenantId: 'local',
        workspaceId: 'opacity',
        mediaLibraryPath: lib,
        mediaRootPath: '${root.path}/media',
      );
      var w = open();
      try {
        w.openDemo();
        await w.importVideo(
          LocalFileGrant.fromUserSelection(File(input!)),
          expectedRevision: w.current.revision,
          acknowledgeVideoOnly: true,
        );
        final id =
            w.current.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
                as String;
        final original = await w.previewTimelineAt(Q.of(0));
        w.setClipOpacity(id, .5, expectedRevision: w.current.revision);
        final effect = w.current.toJson()['effects'][0];
        final preview = await w.previewTimelineAt(Q.of(0)),
            next = await w.previewTimelineAt(Q.of(1, 3));
        expect(preview.rgba, isNot(orderedEquals(original.rgba)));
        final result = await w.exportVideo(
          File('${root.path}/opacity.mp4'),
          captureFrames: [0, 10],
        );
        final captures = result['preEncoderSamples'] as List;
        expect(captures.length, 2);
        for (var i = 0; i < 2; i++) {
          expect(captures[i]['stage'], 'actual-yuv420-before-encoder');
          expect(captures[i]['rgba'], orderedEquals([preview, next][i].rgba));
          expect(captures[i]['width'], preview.width);
          expect(captures[i]['height'], preview.height);
        }
        w.undo(expectedRevision: w.current.revision);
        expect(w.current.toJson()['effects'], isEmpty);
        expect(
          (await w.previewTimelineAt(Q.of(0))).rgba,
          orderedEquals(original.rgba),
        );
        w.setClipOpacity(id, .5, expectedRevision: w.current.revision);
        final archive = File('${root.path}/effects.zip');
        await w.saveArchive(archive);
        final before = w.current.hash;
        w.close();
        w = open();
        w.openDemo();
        expect(w.current.hash, before);
        expect(
          w.current.toJson()['effects'][0]['parameters'],
          effect['parameters'],
        );
        expect(
          (await w.previewTimelineAt(Q.of(0))).rgba,
          orderedEquals(preview.rgba),
        );
        await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
        expect(w.current.hash, isNot(before));
        expect(
          w.current.toJson()['effects'][0]['owner']['id'],
          w.current.toJson()['sequences'][0]['tracks'][0]['items'][0]['id'],
        );
        final fork = await w.exportVideo(
          File('${root.path}/fork.mp4'),
          captureFrames: [0],
        );
        expect(
          fork['preEncoderSamples'][0]['rgba'],
          orderedEquals(preview.rgba),
        );
        final json = File('${root.path}/import.json')
          ..writeAsStringSync(jsonEncode(w.current.toJson()));
        final session = await ResourcePreservationSession.openJson(
          LocalFileGrant.fromUserSelection(json),
        );
        await session.attach(LocalFileGrant.fromUserSelection(File(input)));
        await w.adoptPreservedResources(
          session,
          expectedCollectionReviewHash: session.collectionReviewHash,
          expectedActiveHash: w.current.hash,
          confirmed: true,
        );
        expect(
          (await w.previewTimelineAt(Q.of(0))).rgba,
          orderedEquals(preview.rgba),
        );
        final p = w.previewTimelineAt(Q.of(1, 3));
        final stale = expectLater(
          p,
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              anyOf('PREVIEW_PROJECT_CHANGED', 'PREVIEW_SUPERSEDED'),
            ),
          ),
        );
        w.setClipOpacity(
          w.current.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
              as String,
          .25,
          expectedRevision: w.current.revision,
        );
        await stale;
        await expectLater(
          w.exportVideo(File('${root.path}/bad.mp4'), captureFrames: [0, 0]),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'CAPTURE_LIMIT',
            ),
          ),
        );
        expect(File('${root.path}/bad.mp4').existsSync(), isFalse);
      } finally {
        w.close();
        root.deleteSync(recursive: true);
      }
    },
    skip: lib == null || input == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'REAL native linear-light BT709 grayscale reference, zero/identity and strict invalid recipes',
    () async {
      final root = Directory.systemTemp.createTempSync('opacity-golden-');
      final media = NativeMedia.open(
        lib!,
        Namespace('studio', 'local', 'opacity-golden'),
      );
      try {
        final file = File('${root.path}/gray.mp4');
        final made = Process.runSync('ffmpeg', [
          '-v',
          'error',
          '-f',
          'lavfi',
          '-i',
          'color=c=gray:size=128x72:rate=30:duration=1',
          '-vf',
          'setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=limited',
          '-c:v',
          'libx264',
          '-crf',
          '18',
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
          file.path,
        ]);
        expect(made.exitCode, 0, reason: '${made.stderr}');
        final a = await media.previewAsync(file, Q.of(0));
        final b = await media.previewAsync(file, Q.of(0), opacityQ16: 32768);
        final z = await media.previewAsync(file, Q.of(0), opacityQ16: 0);
        final identity = await media.previewAsync(
          file,
          Q.of(0),
          opacityQ16: 65536,
        );
        expect(identity['rgba'], orderedEquals(a['rgba'] as List));
        final recipe = <String, dynamic>{
          'outputPath': '${root.path}/gray-opacity.mp4',
          'width': 128,
          'height': 72,
          'fps': {'n': 30, 'd': 1},
          'frameCount': 30,
          'captureFrames': [0],
          'segments': [
            {
              'path': file.path,
              'startFrame': 0,
              'frameCount': 30,
              'sourceStart': Q.of(0).toJson(),
              'streamIndex': 0,
              'opacityQ16': 32768,
            },
          ],
        };
        final rendered = await media.renderAsync(recipe);
        expect(
          rendered['preEncoderSamples'][0]['rgba'],
          orderedEquals(b['rgba'] as List),
        );
        final bad = File('${root.path}/invalid.mp4');
        await expectLater(
          media.renderAsync({
            ...recipe,
            'outputPath': bad.path,
            'captureFrames': [0, 1, 2, 3, 4],
          }),
          throwsA(isA<StudioException>()),
        );
        expect(bad.existsSync(), isFalse);

        final rgba = a['rgba'] as List,
            half = b['rgba'] as List,
            zero = z['rgba'] as List;
        for (var i = 0; i < rgba.length; i++) {
          if (i % 4 == 3) {
            expect(half[i], 255);
            expect(zero[i], 255);
            continue;
          }
          final encoded = (rgba[i] as int) / 255.0;
          final linear = encoded < .081
              ? encoded / 4.5
              : math.pow((encoded + .099) / 1.099, 1 / .45).toDouble();
          final dark = linear * .5;
          final expected =
              ((dark < .018 ? dark * 4.5 : 1.099 * math.pow(dark, .45) - .099) *
                      255)
                  .round();
          expect((half[i] as int) - expected, inInclusiveRange(-2, 2));
          expect(zero[i], inInclusiveRange(0, 1));
        }
        expect(
          () => media.previewAsync(file, Q.of(0), opacityQ16: -1),
          throwsA(isA<StudioException>()),
        );
      } finally {
        media.close();
        root.deleteSync(recursive: true);
      }
    },
    skip: lib == null,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
