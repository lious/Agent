import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';

void main() {
  final lib = Platform.environment['STUDIO_MEDIA_LIBRARY'],
      input = Platform.environment['STUDIO_TEST_VIDEO'];
  test(
    'REAL44.1k AAC decode ->48k Dart AudioBus -> Main4/AAC mux -> reopen, gain/mute, atomic failure',
    () async {
      final root = Directory.systemTemp.createTempSync('audio-export-');
      var w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${root.path}/db',
        tenantId: 'local',
        workspaceId: 'audio',
        mediaLibraryPath: lib,
        mediaRootPath: '${root.path}/media',
      );
      try {
        final av = File('${root.path}/input.mp4');
        final made = Process.runSync('ffmpeg', [
          '-v',
          'error',
          '-i',
          input!,
          '-f',
          'lavfi',
          '-i',
          'sine=frequency=997:sample_rate=44100:duration=3',
          '-c:v',
          'copy',
          '-c:a',
          'aac',
          '-ac',
          '2',
          av.path,
        ]);
        expect(made.exitCode, 0, reason: '${made.stderr}');
        w.openDemo();
        await w.importVideo(
          LocalFileGrant.fromUserSelection(av),
          expectedRevision: BigInt.zero,
          acknowledgeVideoOnly: true,
        );
        w.setMasterAudio(gainDb: -6, expectedRevision: w.current.revision);
        final saved = w.current.hash;
        w.close();
        w = StudioWorkspace.open(
          profile: AppProfile(
            appId: 'studio',
            region: 'local',
            features: {'project.metadata', 'media.local'},
          ),
          databasePath: '${root.path}/db',
          tenantId: 'local',
          workspaceId: 'audio',
          mediaLibraryPath: lib,
          mediaRootPath: '${root.path}/media',
        );
        w.openDemo();
        expect(w.current.hash, saved);
        final output = File('${root.path}/sound.mp4');
        final frozenRevision = w.current.revision;
        final startedExport = w.exportVideo(output, includeEmbeddedAudio: true);
        await expectLater(
          w.exportVideo(
            File('${root.path}/busy.mp4'),
            includeEmbeddedAudio: true,
          ),
          throwsA(
            isA<StudioException>().having((e) => e.code, 'code', 'EXPORT_BUSY'),
          ),
        );
        w.setMasterAudio(gainDb: -12, expectedRevision: w.current.revision);
        final result = await startedExport;
        expect(result['revision'], frozenRevision.toString());
        expect(w.current.toJson()['audioBuses'][0]['gainDb'], -12);
        final unchanged = w.current.revision;
        w.setMasterAudio(gainDb: -12, expectedRevision: unchanged);
        expect(w.current.revision, unchanged);
        expect(
          () =>
              w.setMasterAudio(gainDb: double.nan, expectedRevision: unchanged),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'AUDIO_PARAMETER_RANGE',
            ),
          ),
        );
        expect(
          () => w.setMasterAudio(pan: 1.01, expectedRevision: unchanged),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'AUDIO_PARAMETER_RANGE',
            ),
          ),
        );
        expect(w.current.revision, unchanged);
        w.undo(expectedRevision: unchanged);
        expect(w.current.toJson()['audioBuses'][0]['gainDb'], -6);
        expect(result['audio'], 'aac');
        expect(result['audioSamples'], 144000);
        final facts = w.media!.probe(output),
            v = (facts['streams'] as List).singleWhere(
              (x) => x['type'] == 'video',
            ),
            a = (facts['streams'] as List).singleWhere(
              (x) => x['type'] == 'audio',
            );
        expect(v['profile'], 'Main');
        expect(a['sampleRate'], 48000);
        expect(a['channels'], 2);
        double rms(File f) {
          final pcm = File('${f.path}.f32');
          final r = Process.runSync('ffmpeg', [
            '-v',
            'error',
            '-i',
            f.path,
            '-map',
            '0:a:0',
            '-f',
            'f32le',
            '-ac',
            '2',
            '-ar',
            '48000',
            pcm.path,
          ]);
          expect(r.exitCode, 0);
          final data = pcm.readAsBytesSync().buffer.asFloat32List();
          var sum = 0.0;
          for (final x in data) {
            sum += x * x;
          }
          return math.sqrt(sum / data.length);
        }

        final original = rms(av), attenuated = rms(output);
        expect(
          attenuated / original,
          closeTo(math.pow(10, -6 / 20).toDouble(), 0.015),
        );
        w.setMasterAudio(
          gainDb: -6,
          muted: true,
          expectedRevision: w.current.revision,
        );
        final muted = File('${root.path}/mute.mp4');
        await w.exportVideo(muted, includeEmbeddedAudio: true);
        expect(rms(muted), lessThan(0.000001));
        // Materialize persistent audio; unlike the legacy export option it
        // survives storage/reopen/archive and exports automatically by default.
        final videoClip =
            (w.current.toJson()['sequences'][0]['tracks'][0]['items'] as List)
                .firstWhere((c) => c['source'] != null);
        final stream = (w.current.toJson()['assets'][0]['streams'] as List)
            .singleWhere((st) => st['type'] == 'audio');
        w.edit(
          ExtractAudioClip(videoClip['id'] as String, stream['id'] as String),
          expectedRevision: w.current.revision,
        );
        expect(w.current.toJson()['linkGroups'].length, 1);
        w.setMasterAudio(gainDb: -6, expectedRevision: w.current.revision);
        final persisted = File('${root.path}/persistent.mp4');
        await w.exportVideo(persisted);
        expect(rms(persisted), greaterThan(0));
        await expectLater(
          w.exportVideo(
            File('${root.path}/double.mp4'),
            includeEmbeddedAudio: true,
          ),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'AUDIO_SOURCE_MODE_AMBIGUOUS',
            ),
          ),
        );
        final audioTrack =
            (w.current.toJson()['sequences'][0]['tracks'] as List).singleWhere(
              (t) => t['kind'] == 'audio',
            );
        w.edit(
          SetAudioTrackState(
            audioTrack['id'] as String,
            muted: true,
            solo: false,
          ),
          expectedRevision: w.current.revision,
        );
        final trackMuted = File('${root.path}/track-muted.mp4');
        await w.exportVideo(trackMuted);
        expect(rms(trackMuted), lessThan(1e-6));
        w.undo(expectedRevision: w.current.revision);
        w.edit(
          SplitClip(videoClip['id'] as String, Q.of(1), 'persistent-right'),
          expectedRevision: w.current.revision,
        );
        expect(w.current.toJson()['linkGroups'].length, 2);
        final linked = File('${root.path}/linked-split.mp4');
        await w.exportVideo(linked);
        expect(rms(linked), greaterThan(0));
        final linkedHash = w.current.hash;
        w.saveManaged();
        w.close();
        w = StudioWorkspace.open(
          profile: AppProfile(
            appId: 'studio',
            region: 'local',
            features: {'project.metadata', 'media.local'},
          ),
          databasePath: '${root.path}/db',
          tenantId: 'local',
          workspaceId: 'audio',
          mediaLibraryPath: lib,
          mediaRootPath: '${root.path}/media',
        );
        w.openDemo();
        expect(w.current.hash, linkedHash);
        expect(w.current.toJson()['linkGroups'].length, 2);
        final archive = File('${root.path}/linked.studio-project');
        await w.saveArchive(archive);
        final beforeFork = w.projectId;
        await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
        expect(w.projectId, isNot(beforeFork));
        expect(w.current.toJson()['linkGroups'].length, 2);
        final reopened = File('${root.path}/linked-reopened.mp4');
        await w.exportVideo(reopened);
        expect(rms(reopened), greaterThan(0));
        final target = File('${root.path}/untouched.mp4')
          ..writeAsStringSync('existing');
        w.cancelExport();
        final started = w.exportVideo(target);
        w.cancelExport();
        await expectLater(
          started,
          throwsA(
            isA<StudioException>().having((e) => e.code, 'code', 'CANCELED'),
          ),
        );
        expect(target.readAsStringSync(), 'existing');
        expect(
          root.listSync().where((f) => f.path.endsWith('.pending')),
          isEmpty,
        );
        print(
          jsonEncode({
            'sourceSampleRate': 44100,
            'outputSampleRate': 48000,
            'contentSamples': 144000,
            'gainRatio': attenuated / original,
            'outputHash': rawBytesHash(output.readAsBytesSync()),
          }),
        );
      } finally {
        w.close();
        root.deleteSync(recursive: true);
      }
    },
    skip: lib == null || input == null,
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test(
    'REAL PCM44.1k impulse resample drain/trim exact length; layout/gap/resource/overwrite failure cleans private output',
    () async {
      final root = Directory.systemTemp.createTempSync('pcm-qual-'),
          media = NativeMedia.open(lib!, Namespace('studio', 'local', 'pcm'));
      try {
        final wave = File('${root.path}/impulse.wav');
        final made = Process.runSync('ffmpeg', [
          '-v',
          'error',
          '-f',
          'lavfi',
          '-i',
          "aevalsrc='if(eq(n,22050),1,0)':s=44100:d=1",
          '-c:a',
          'pcm_s16le',
          wave.path,
        ]);
        expect(made.exitCode, 0, reason: '${made.stderr}');
        Map<String, dynamic> recipe(
          File out, {
          int start = 0,
          int count = 48000,
        }) => {
          'path': wave.path,
          'outputPath': out.path,
          'streamIndex': 0,
          'startSample': start,
          'sampleCount': count,
        };
        final out = File('${root.path}/region.f32'),
            stats = await media.decodeAudioAsync(recipe(out));
        expect(out.lengthSync(), 48000 * 8);
        expect(stats['writtenSamples'], 48000);
        expect(stats['resampledSamples'], 48000);
        int peak(File f) {
          final data = f.readAsBytesSync().buffer.asFloat32List();
          var best = 0;
          for (var i = 2; i < data.length; i += 2) {
            if (data[i].abs() > data[best].abs()) best = i;
          }
          return best ~/ 2;
        }

        expect(peak(out), closeTo(24000, 1));
        final trimmed = File('${root.path}/trim.f32');
        await media.decodeAudioAsync(
          recipe(trimmed, start: 1000, count: 47000),
        );
        expect(trimmed.lengthSync(), 47000 * 8);
        expect(peak(trimmed), closeTo(23000, 1));
        await expectLater(
          media.decodeAudioAsync(recipe(out)),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'PCM_OUTPUT_MUST_BE_NEW',
            ),
          ),
        );
        expect(out.lengthSync(), 48000 * 8);
        final over = File('${root.path}/over.f32');
        await expectLater(
          media.decodeAudioAsync(recipe(over, count: 48000 * 120 + 1)),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'RECIPE_RANGE',
            ),
          ),
        );
        expect(over.existsSync(), isFalse);
        final surround = File('${root.path}/surround.wav');
        expect(
          Process.runSync('ffmpeg', [
            '-v',
            'error',
            '-f',
            'lavfi',
            '-i',
            'anullsrc=channel_layout=5.1:sample_rate=48000',
            '-t',
            '0.1',
            surround.path,
          ]).exitCode,
          0,
        );
        await expectLater(
          media.decodeAudioAsync({...recipe(over), 'path': surround.path}),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'AUDIO_LAYOUT_UNSUPPORTED',
            ),
          ),
        );
        expect(over.existsSync(), isFalse);
        final invalidPcm = File('${root.path}/invalid.wav'),
            samples = Float32List(4800 * 2)..[0] = double.nan;
        final wav = Uint8List(44 + samples.lengthInBytes),
            header = ByteData.view(wav.buffer);
        void text(int at, String value) =>
            wav.setRange(at, at + value.length, ascii.encode(value));
        text(0, 'RIFF');
        header.setUint32(4, wav.length - 8, Endian.little);
        text(8, 'WAVEfmt ');
        header.setUint32(16, 16, Endian.little);
        header.setUint16(20, 3, Endian.little);
        header.setUint16(22, 2, Endian.little);
        header.setUint32(24, 48000, Endian.little);
        header.setUint32(28, 48000 * 8, Endian.little);
        header.setUint16(32, 8, Endian.little);
        header.setUint16(34, 32, Endian.little);
        text(36, 'data');
        header.setUint32(40, samples.lengthInBytes, Endian.little);
        wav.setRange(44, wav.length, samples.buffer.asUint8List());
        invalidPcm.writeAsBytesSync(wav);
        await expectLater(
          media.decodeAudioAsync({
            ...recipe(over),
            'path': invalidPcm.path,
            'sampleCount': 4800,
          }),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'AUDIO_PCM_INVALID',
            ),
          ),
        );
        expect(over.existsSync(), isFalse);
        final gap = File('${root.path}/gap.m4a');
        final g = Process.runSync('ffmpeg', [
          '-v',
          'error',
          '-f',
          'lavfi',
          '-i',
          'sine=sample_rate=48000:duration=1',
          '-af',
          "asetpts='PTS+if(gte(T,0.5),0.1/TB,0)'",
          '-c:a',
          'aac',
          gap.path,
        ]);
        expect(g.exitCode, 0, reason: '${g.stderr}');
        await expectLater(
          media.decodeAudioAsync({...recipe(over), 'path': gap.path}),
          throwsA(
            isA<StudioException>().having(
              (e) => e.code,
              'code',
              'AUDIO_PTS_DISCONTINUITY',
            ),
          ),
        );
        expect(over.existsSync(), isFalse);
        print(
          jsonEncode({
            'pcmImpulseSamples': 48000,
            'resampledPeakSample': peak(out),
            'trimmedPeakSample': peak(trimmed),
            'resampleDrainSamples': stats['resampledSamples'],
            'sourceRate': 44100,
          }),
        );
      } finally {
        media.close();
        root.deleteSync(recursive: true);
      }
    },
    skip: lib == null,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
