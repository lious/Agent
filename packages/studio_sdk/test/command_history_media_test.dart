import 'dart:io';

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  final lib = Platform.environment['STUDIO_MEDIA_LIBRARY'];
  test(
    'REAL AV effects/audio/captions/proxy multiundo-redo, durable reopen, empty fork history and preview/MP4',
    () async {
      final root = Directory.systemTemp.createTempSync('history-media-');
      StudioWorkspace open() => StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${root.path}/db',
        tenantId: 'local',
        workspaceId: 'undo-media',
        mediaLibraryPath: lib,
        mediaRootPath: '${root.path}/media',
      );
      var w = open();
      String contents() => contentHash(w.current.toJson()..remove('revision'));
      try {
        w.openDemo();
        final av = File('${root.path}/av.mp4');
        final made = await Process.run('ffmpeg', [
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
        final states = [contents()];
        final audio = (w.current.toJson()['assets'][0]['streams'] as List)
            .singleWhere((s) => s['type'] == 'audio');
        w.edit(
          ExtractAudioClip(clip, audio['id'] as String),
          expectedRevision: w.current.revision,
        );
        states.add(contents());
        w.setClipCrop(clip, {
          ...identityCrop,
          'left': .25,
        }, expectedRevision: w.current.revision);
        states.add(contents());
        w.setClipColorBasic(clip, {
          ...identityColorBasic,
          'exposureStops': 1,
        }, expectedRevision: w.current.revision);
        states.add(contents());
        final beforePixels = await w.previewTimelineAt(Q.of(1));
        final caption = File('${root.path}/sub.srt')
          ..writeAsStringSync(
            '1\n00:00:00,000 --> 00:00:01,000\nKeep this exact text\n',
          );
        await w.importCaptions(
          LocalFileGrant.fromUserSelection(caption),
          CaptionFormat.srt,
          expectedRevision: w.current.revision,
        );
        states.add(contents());
        await w.buildTimelinePreviewProxies();
        states.add(contents());
        for (var i = states.length - 2; i >= 0; i--) {
          w.undo(expectedRevision: w.current.revision);
          expect(contents(), states[i]);
        }
        w.close();
        w = open();
        w.openDemo();
        expect(w.canRedo, isTrue);
        for (var i = 1; i < states.length; i++) {
          w.redo(expectedRevision: w.current.revision);
          expect(contents(), states[i]);
        }
        expect(
          w.current.toJson()['captions'][0]['text'],
          'Keep this exact text',
        );
        final archive = File('${root.path}/all.zip');
        await w.saveArchive(archive);
        final selected = w.current.hash;
        w.close();
        w = open();
        w.openDemo();
        expect(w.current.hash, selected);
        expect(w.canRedo, isFalse);
        w.undo(expectedRevision: w.current.revision); // proxy metadata only
        w.undo(
          expectedRevision: w.current.revision,
        ); // caption cannot be silently dropped by encoder
        expect(contents(), states[3]);
        final pixels = await w.previewTimelineAt(Q.of(1));
        expect(pixels.rgba, orderedEquals(beforePixels.rgba));
        final out = await w.exportVideo(
          File('${root.path}/edited.mp4'),
          captureFrames: [30],
        );
        expect(out['preEncoderSamples'][0]['rgba'], orderedEquals(pixels.rgba));
        w.redo(expectedRevision: w.current.revision);
        w.redo(expectedRevision: w.current.revision);
        await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
        expect(w.canUndo, isFalse);
        expect(w.canRedo, isFalse);
        expect(
          w.current.toJson()['captions'][0]['text'],
          'Keep this exact text',
        );
        // Imported historical IDs are not executable local commands. New edit starts
        // a fresh stack while typed references, audio and derived resources survive.
        final fork = contents();
        w.rename('fork edit', expectedRevision: w.current.revision);
        w.undo(expectedRevision: w.current.revision);
        expect(contents(), fork);
        w.redo(expectedRevision: w.current.revision);
        expect(w.current.title, 'fork edit');
      } finally {
        w.close();
        root.deleteSync(recursive: true);
      }
    },
    skip: lib == null || Platform.environment['STUDIO_TEST_VIDEO'] == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
