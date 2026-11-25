import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:studio_sdk/studio_sdk.dart';

import 'dissolve_fixture.dart';

void main() {
  final lib = Platform.environment['STUDIO_MEDIA_LIBRARY'];
  test(
    'REAL2-source linear dissolve: independent color reference, encoder samples, transform/curve, undo, archive/fork/reopen',
    () async {
      final root = Directory.systemTemp.createTempSync('dissolve-render-');
      StudioWorkspace open() => StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${root.path}/db',
        tenantId: 'local',
        workspaceId: 'dissolve',
        mediaLibraryPath: lib,
        mediaRootPath: '${root.path}/media',
      );
      var w = open();
      try {
        await installDissolveFixture(w, root);
        final clips = w.current.toJson()['sequences'][0]['tracks'][0]['items'];
        final left = clips[0]['id'] as String, right = clips[1]['id'] as String;
        final a = await w.previewTimelineAt(Q.of(1, 2)),
            b = await w.previewTimelineAt(Q.of(3, 2));
        // Isolated fixture only: fail AFTER new transition versions/root work.
        final beforeDissolve = w.current.toJson();
        final db = sql.sqlite3.open('${root.path}/db'),
            beforeFault = w.current.hash;
        final countBefore = db
            .select('SELECT COUNT(*) AS n FROM entity_versions')
            .single['n'];
        try {
          db.execute(
            "CREATE TRIGGER fail_dissolve_event BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'isolated_dissolve_fixture'); END",
          );
          expect(
            () => w.setDissolve(
              left,
              right,
              Q.of(1, 5),
              Q.of(1, 5),
              expectedRevision: w.current.revision,
            ),
            throwsA(isA<sql.SqliteException>()),
          );
          expect(w.current.hash, beforeFault);
          expect(
            db.select('SELECT COUNT(*) AS n FROM entity_versions').single['n'],
            countBefore,
          );
          db.execute('DROP TRIGGER fail_dissolve_event');
        } finally {
          db.dispose();
        }
        w.setDissolve(
          left,
          right,
          Q.of(1, 5),
          Q.of(1, 5),
          expectedRevision: w.current.revision,
        );
        final mid = await w.previewTimelineAt(Q.of(1));
        double linear(int v) {
          final x = v / 255.0;
          return x < .081
              ? x / 4.5
              : math.pow((x + .099) / 1.099, 1 / .45).toDouble();
        }

        final l = (linear(a.rgba[200]) + linear(b.rgba[200])) / 2;
        final ref =
            ((l < .018 ? 4.5 * l : 1.099 * math.pow(l, .45) - .099) * 255)
                .round();
        expect((mid.rgba[200] - ref).abs(), lessThanOrEqualTo(2));
        expect(mid.rgba[200], greaterThan(170));
        final frames = [24, 30, 35, 36];
        final previews = [
          for (final f in frames) await w.previewTimelineAt(Q.of(f, 30)),
        ];
        var out = await w.exportVideo(
          File('${root.path}/dissolve.mp4'),
          captureFrames: frames,
        );
        for (var i = 0; i < frames.length; i++) {
          expect(
            out['preEncoderSamples'][i]['rgba'],
            orderedEquals(previews[i].rgba),
          );
        }
        w.undo(expectedRevision: w.current.revision);
        expect(w.current.toJson()['transitions'], isEmpty);
        final restored = w.current.toJson()
          ..['revision'] = beforeDissolve['revision'];
        expect(
          contentHash(restored),
          contentHash(beforeDissolve),
        ); // only monotonic commit revision differs.
        w.setDissolve(
          left,
          right,
          Q.of(1, 5),
          Q.of(1, 5),
          expectedRevision: w.current.revision,
        );
        w.setClipTransform(left, {
          ...identityTransform2d,
          'translateX': 16,
        }, expectedRevision: w.current.revision);
        w.setOpacityKeyframe(
          left,
          Q.of(0),
          1,
          expectedRevision: w.current.revision,
        );
        w.setOpacityKeyframe(
          left,
          Q.of(1),
          .5,
          expectedRevision: w.current.revision,
        );
        final composite = await w.previewTimelineAt(Q.of(1));
        expect(composite.rgba, isNot(orderedEquals(mid.rgba)));
        out = await w.exportVideo(
          File('${root.path}/effects.mp4'),
          captureFrames: [30],
        );
        expect(
          out['preEncoderSamples'][0]['rgba'],
          orderedEquals(composite.rgba),
        );
        final archive = File('${root.path}/project.zip');
        final oldTransitionId = w.current.toJson()['transitions'][0]['id'],
            oldEffectIds = (w.current.toJson()['effects'] as List)
                .map((e) => e['id'])
                .toSet();
        await w.saveArchive(archive);
        final hash = w.current.hash;
        w.close();
        w = open();
        w.openDemo();
        expect(w.current.hash, hash);
        expect(
          (await w.previewTimelineAt(Q.of(1))).rgba,
          orderedEquals(composite.rgba),
        );
        await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
        expect(
          w.current.toJson()['transitions'][0]['id'],
          isNot(oldTransitionId),
        );
        expect(
          (w.current.toJson()['effects'] as List).any(
            (e) => oldEffectIds.contains(e['id']),
          ),
          isFalse,
        );
        expect(
          () => w.setDissolve(
            w.current.toJson()['transitions'][0]['leftClipId'],
            w.current.toJson()['transitions'][0]['rightClipId'],
            Q.of(1, 5),
            Q.of(1, 5),
            expectedRevision: w.current.revision - BigInt.one,
          ),
          throwsA(isA<StudioException>()),
        );
        final collection = await ResourcePreservationSession.openArchive(
          LocalFileGrant.fromUserSelection(archive),
        );
        await w.adoptPreservedResources(
          collection,
          expectedCollectionReviewHash: collection.collectionReviewHash,
          expectedActiveHash: w.current.hash,
          confirmed: true,
        );
        final forkHash = w.current.hash;
        w.close();
        w = open();
        w.openDemo();
        expect(w.current.hash, forkHash);
        out = await w.exportVideo(
          File('${root.path}/fork.mp4'),
          captureFrames: [30],
        );
        expect(
          out['preEncoderSamples'][0]['rgba'],
          orderedEquals(composite.rgba),
        );
        final transition = w.current.toJson()['transitions'][0];
        final old = w.current.hash;
        expect(
          () => w.edit(
            SlipClip(transition['rightClipId'] as String, Q.of(-1)),
            expectedRevision: w.current.revision,
          ),
          throwsA(isA<StudioException>()),
        );
        expect(w.current.hash, old);
        w.removeDissolve(
          transition['id'] as String,
          expectedRevision: w.current.revision,
        );
        expect(w.current.toJson()['transitions'], isEmpty);
        w.undo(expectedRevision: w.current.revision);
        expect(w.current.toJson()['transitions'].length, 1);
      } finally {
        w.close();
        root.deleteSync(recursive: true);
      }
    },
    skip: lib == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'REAL malformed secondary schedules refuse before output creation',
    () async {
      final root = Directory.systemTemp.createTempSync('bad-dissolve-'),
          input = Platform.environment['STUDIO_TEST_VIDEO']!;
      final media = NativeMedia.open(
        lib!,
        Namespace('studio', 'local', 'bad-dissolve'),
      );
      try {
        for (final values in <List<dynamic>>[
          [0],
          List.filled(90, -1),
          List.filled(90, 65537),
          List.filled(90, .5),
        ]) {
          final out = File('${root.path}/bad.mp4');
          await expectLater(
            media.renderAsync({
              'outputPath': out.path,
              'width': 320,
              'height': 180,
              'fps': {'n': 30, 'd': 1},
              'frameCount': 90,
              'segments': [
                {
                  'path': input,
                  'streamIndex': 0,
                  'sourceStart': Q.of(0).toJson(),
                  'startFrame': 0,
                  'frameCount': 90,
                  'secondary': {
                    'path': input,
                    'streamIndex': 0,
                    'sourceStart': Q.of(0).toJson(),
                  },
                  'mixFramesQ16': values,
                },
              ],
            }),
            throwsA(isA<StudioException>()),
          );
          expect(out.existsSync(), false);
        }
      } finally {
        media.close();
        root.deleteSync(recursive: true);
      }
    },
    skip: lib == null || Platform.environment['STUDIO_TEST_VIDEO'] == null,
  );
  test(
    'REAL individually displayable different-size originals: actual joint consumer rejects and adoption preserves selected root without bypassing earlier graph gate',
    () async {
      final root = Directory.systemTemp.createTempSync('dissolve-admission-');
      final w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${root.path}/db',
        tenantId: 'local',
        workspaceId: 'dissolve-admission',
        mediaLibraryPath: lib,
        mediaRootPath: '${root.path}/media',
      );
      try {
        final collection = await installDissolveFixture(
          w,
          root,
          blackSize: '160x90',
          preserveOnly: true,
        );
        final clips = collection.project
            .toJson()['sequences'][0]['tracks'][0]['items'];
        final candidate = applyEdit(
          collection.project,
          SetDissolve(clips[0]['id'], clips[1]['id'], Q.of(1, 5), Q.of(1, 5)),
          newId: () => 'negative-dissolve',
          nextVersion: (_) => '999',
        );
        final json = File('${root.path}/incompatible.json')
          ..writeAsStringSync(jsonEncode(candidate.toJson()));
        final session = await ResourcePreservationSession.openJson(
          LocalFileGrant.fromUserSelection(json),
        );
        final white = File('${root.path}/white.mp4'),
            black = File('${root.path}/black.mp4');
        await session.attach(LocalFileGrant.fromUserSelection(white));
        await session.attach(LocalFileGrant.fromUserSelection(black));
        final native = NativeMedia.open(
          lib!,
          Namespace('studio', 'local', 'negative-joint'),
        );
        try {
          expect((await native.previewAsync(white, Q.of(1)))['width'], 128);
          expect((await native.previewAsync(black, Q.of(1)))['width'], 128);
          await expectLater(
            native.previewAsync(
              white,
              Q.of(1),
              secondary: {
                'path': black.absolute.path,
                'time': Q.of(1).toJson(),
                'indexed': true,
              },
              mixQ16: 32768,
            ),
            throwsA(
              isA<StudioException>().having(
                (e) => e.code,
                'code',
                'DISSOLVE_SOURCE_MISMATCH',
              ),
            ),
          );
        } finally {
          native.close();
        }
        final before = w.current.hash,
            oldMap = w.currentImportMap,
            archive = File('${root.path}/preserved.zip');
        await session.saveArchive(
          archive,
          confirmedCollection: true,
          expectedCollectionReviewHash: session.collectionReviewHash,
        );
        await expectLater(
          w.adoptPreservedResources(
            session,
            expectedCollectionReviewHash: session.collectionReviewHash,
            expectedActiveHash: before,
            confirmed: true,
          ),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'TIMELINE_SCALING_UNSUPPORTED',
            ),
          ),
        );
        expect(w.current.hash, before);
        expect(w.currentImportMap, oldMap);
        expect(archive.existsSync(), isTrue);
      } finally {
        w.close();
        root.deleteSync(recursive: true);
      }
    },
    skip: lib == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
