import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

AudioBusGraph domainGraph() => AudioBusGraph([
  AudioBus(id: 'master', inputs: ['music', 'voice']),
  AudioBus(id: 'music', inputs: [], output: 'master'),
  AudioBus(id: 'voice', inputs: [], output: 'master'),
], 'master');

Map<String, dynamic> bus({
  required String id,
  required String name,
  List<String> inputs = const [],
  String? output,
  double gainDb = 0,
}) => {
  'id': id,
  'name': name,
  'inputBusIds': inputs,
  'gainDb': gainDb,
  'pan': 0,
  'effectIds': <dynamic>[],
  'muted': false,
  'solo': false,
  'outputBusId': output,
};

ProjectDocument avFixture() {
  final d = jsonDecode(
    File('fixtures/project/local-video.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final st = Map<String, dynamic>.from(d['assets'][0]['streams'][0] as Map)
    ..addAll({
      'id': 'audio-stream',
      'type': 'audio',
      'codec': 'aac',
      'profile': 'LC',
      'width': null,
      'height': null,
      'pixelFormat': null,
      'color': null,
      'nominalFrameRate': null,
      'sampleRate': 48000,
      'channels': 2,
      'channelLayout': 'stereo',
      'timeBase': Q.of(1, 48000).toJson(),
    });
  (d['assets'][0]['streams'] as List).add(st);
  return ProjectDocument.fromJson(d);
}

void main() {
  var serial = 0;
  final versions = <String, int>{};
  ProjectDocument apply(ProjectDocument p, EditOperation op) => applyEdit(
    p,
    op,
    newId: () => 'i009-test-${serial++}',
    nextVersion: (id) =>
        '${versions.update(id, (v) => v + 1, ifAbsent: () => 10)}',
  );
  String video(ProjectDocument p) =>
      p.toJson()['sequences'][0]['tracks'][0]['items'].firstWhere(
            (x) => x['source'] != null,
          )['id']
          as String;
  List<dynamic> tracks(ProjectDocument p) =>
      p.toJson()['sequences'][0]['tracks'] as List;
  setUp(() {
    serial = 0;
    versions.clear();
  });

  test('route group with a cycle is refused as a whole and leaves the current graph unused', () {
    final current = domainGraph();
    expect(
      () => applyAudioBusRouteGroup(current, [
        AudioRouteChange(busId: 'music', output: 'voice', inputs: ['voice']),
        AudioRouteChange(busId: 'voice', output: 'music', inputs: ['music']),
        AudioRouteChange(busId: 'master', inputs: []),
      ]),
      code('AUDIO_ROUTE_CYCLE'),
    );
    expect(current.recipe, ['music', 'voice', 'master']);
    expect(current.buses['music']!.output, 'master');
    expect(current.buses['voice']!.output, 'master');
    expect(
      () => applyAudioBusRouteGroup(current, [
        AudioRouteChange(busId: 'music', output: 'voice'),
      ]),
      code('AUDIO_ROUTE_MISMATCH'),
    );
    expect(current.buses['music']!.output, 'master');
    final same = applyAudioBusRouteGroup(current, [
      AudioRouteChange(busId: 'music', output: 'master', inputs: []),
    ]);
    expect(same.buses['music']!.output, 'master');
    expect(same.recipe, current.recipe);
  });

  test('silent tracks are omitted from the mix and unrouted silent inputs do not fail the group', () {
    final audible = PcmInput(
      busId: 'voice',
      samples: Float32List.fromList([0.5, 0.5]),
      channels: 2,
    );
    final silent = PcmInput(
      busId: 'music',
      samples: Float32List.fromList([1, 1]),
      channels: 2,
      silent: true,
    );
    final mixed = mix48k(domainGraph(), [audible, silent]);
    expect(mixed.interleavedStereo, [0.5, 0.5]);
    final muted = mix48k(domainGraph(), [
      audible,
      PcmInput(
        busId: 'music',
        samples: Float32List.fromList([1, 1]),
        channels: 2,
        muted: true,
      ),
    ]);
    expect(muted.interleavedStereo, [0.5, 0.5]);
    final g = AudioBusGraph([
      AudioBus(id: 'm', inputs: []),
      AudioBus(id: 'unused', inputs: []),
    ], 'm');
    final unusedSilent = mix48k(g, [
      PcmInput(
        busId: 'unused',
        samples: Float32List.fromList([1, 1]),
        channels: 2,
        silent: true,
      ),
    ]);
    expect(unusedSilent.interleavedStereo, [0.0, 0.0]);
  });

  test('analysis apply never rewrites manual gain points or locked tracks (mutations=0)', () {
    final manual = GainEnvelope([
      GainPoint(Q.of(0), -3),
      GainPoint(Q.of(5), -4),
    ]);
    final original = List<GainPoint>.from(manual.points);
    final clip = TimeRange(Q.of(10), Q.of(5));
    final speech = [TimeRange(Q.of(11), Q.of(1))];
    final playback = AnalysisGainPlayback.apply(
      manual: manual,
      clip: clip,
      speech: speech,
    );
    expect(identical(playback.manual, manual), isTrue);
    expect(manual.points, original);
    expect(playback.manualMutations, 0);
    expect(playback.at(Q.of(3, 2)), closeTo(manual.at(Q.of(3, 2)) - 9, 1e-12));
    final protected = AnalysisGainPlayback.apply(
      manual: manual,
      clip: clip,
      speech: speech,
      manualProtected: [TimeRange(Q.of(1), Q.of(2))],
    );
    expect(protected.warnings, everyElement('MANUAL_REGION_SKIPPED'));
    expect(protected.at(Q.of(3, 2)), closeTo(manual.at(Q.of(3, 2)), 1e-12));
    expect(manual.points, original);
    expect(
      () => AnalysisGainPlayback.apply(
        manual: manual,
        clip: clip,
        speech: speech,
        trackLocked: true,
      ),
      code('TRACK_LOCKED'),
    );
    expect(
      () => AnalysisGainPlayback.apply(
        manual: manual,
        clip: clip,
        speech: speech,
        gainLocked: true,
      ),
      code('MANUAL_LOCKED'),
    );
    expect(manual.points, original);
    expect(identical(manual.points[0], original[0]), isTrue);
  });

  test('source-anchored gain cues follow the admitted linear timeMap/rate after 2x retime', () {
    final curve = GainEnvelope([
      GainPoint(Q.of(0), 0),
      GainPoint(Q.of(1), -12),
      GainPoint(Q.of(2), 0),
    ]);
    final frames = 48000;
    final pcm = Float32List(frames * 2)..fillRange(0, frames * 2, 1);
    final mixed = mix48k(domainGraph(), [
      PcmInput(
        busId: 'music',
        samples: pcm,
        channels: 2,
        automation: curve,
        clipStart: Q.of(10),
        sourceStart: Q.of(0),
        rate: Q.of(2),
        sourceAnchored: true,
      ),
    ], timelineStart: Q.of(10));
    // Timeline 10.5s -> source 1s at rate 2, which is the -12dB cue.
    expect(
      mixed.interleavedStereo[24000 * 2],
      closeTo(gainAmplitude(-12), 1e-6),
    );
    expect(mixed.interleavedStereo[0], closeTo(1, 1e-6));
    expect(
      () => PcmInput(
        busId: 'music',
        samples: Float32List.fromList([1, 1]),
        channels: 2,
        rate: Q.of(0),
      ),
      code('TIME_MAP_MISMATCH'),
    );
  });

  test('official persist path: cyclic SetAudioBusRoutes is whole-group rejected; SetMasterAudio keeps sibling buses', () {
    var p = avFixture();
    p = apply(p, ExtractAudioClip(video(p), 'audio-stream'));
    final audioTrackId =
        tracks(p).singleWhere((t) => t['kind'] == 'audio')['id'] as String;
    final master = bus(
      id: 'bus-master',
      name: 'Master',
      inputs: ['music', 'voice'],
    );
    final music = bus(id: 'music', name: 'Music', output: 'bus-master');
    final voice = bus(id: 'voice', name: 'Voice', output: 'bus-master');
    final routed = apply(
      p,
      SetAudioBusRoutes(
        buses: [master, music, voice],
        masterId: 'bus-master',
        trackBusIds: {audioTrackId: 'music'},
      ),
    );
    expect(routed.toJson()['audioBuses'].length, 3);
    expect(
      tracks(routed).singleWhere((t) => t['kind'] == 'audio')['busId'],
      'music',
    );
    final gained = apply(routed, const SetMasterAudio(gainDb: -6));
    expect(gained.toJson()['audioBuses'][0]['gainDb'], -6);
    expect((gained.toJson()['audioBuses'] as List).map((b) => b['id']), [
      'bus-master',
      'music',
      'voice',
    ]);
    final beforeCycle = jsonEncode(gained.toJson()['audioBuses']);
    final beforeTracks = jsonEncode(gained.toJson()['sequences'][0]['tracks']);
    expect(
      () => apply(
        gained,
        SetAudioBusRoutes(
          buses: [
            bus(id: 'bus-master', name: 'Master', inputs: []),
            bus(id: 'music', name: 'Music', inputs: ['voice'], output: 'voice'),
            bus(id: 'voice', name: 'Voice', inputs: ['music'], output: 'music'),
          ],
          masterId: 'bus-master',
          trackBusIds: {audioTrackId: 'music'},
        ),
      ),
      code('AUDIO_ROUTE_CYCLE'),
    );
    expect(jsonEncode(gained.toJson()['audioBuses']), beforeCycle);
    expect(jsonEncode(gained.toJson()['sequences'][0]['tracks']), beforeTracks);
    expect(gained.toJson()['audioBuses'][0]['gainDb'], -6);
    final locked = apply(gained, SetTrackState(audioTrackId, locked: true));
    final beforeLock = jsonEncode(locked.toJson());
    expect(
      () => apply(
        locked,
        SetAudioBusRoutes(
          buses: [master, music, voice],
          masterId: 'bus-master',
          trackBusIds: {audioTrackId: 'voice'},
        ),
      ),
      code('FIELD_LOCKED'),
    );
    expect(jsonEncode(locked.toJson()), beforeLock);
  });

  test('official mix recipe omits muted/silent tracks and keeps the audible bus contribution', () {
    final musicPcm = Float32List.fromList([1, 1]);
    final voicePcm = Float32List.fromList([0.25, 0.25]);
    final project = {
      'sequences': [
        {
          'masterBusId': 'bus-master',
          'tracks': [
            {
              'id': 't-music',
              'kind': 'audio',
              'busId': 'music',
              'muted': true,
              'items': [
                {
                  'id': 'c-music',
                  'enabled': true,
                  'source': {'id': 'a'},
                  'timeMap': {'kind': 'linear', 'rate': Q.of(1).toJson()},
                  'timelineRange': {
                    'start': Q.of(0).toJson(),
                    'duration': Q.of(1, 48000).toJson(),
                  },
                  'sourceRange': {
                    'start': Q.of(0).toJson(),
                    'duration': Q.of(1, 48000).toJson(),
                  },
                },
              ],
            },
            {
              'id': 't-voice',
              'kind': 'audio',
              'busId': 'voice',
              'muted': false,
              'items': [
                {
                  'id': 'c-voice',
                  'enabled': true,
                  'source': {'id': 'a'},
                  'timeMap': {'kind': 'linear', 'rate': Q.of(1).toJson()},
                  'timelineRange': {
                    'start': Q.of(0).toJson(),
                    'duration': Q.of(1, 48000).toJson(),
                  },
                  'sourceRange': {
                    'start': Q.of(0).toJson(),
                    'duration': Q.of(1, 48000).toJson(),
                  },
                },
              ],
            },
          ],
        },
      ],
      'audioBuses': [
        bus(id: 'bus-master', name: 'Master', inputs: ['music', 'voice']),
        bus(id: 'music', name: 'Music', output: 'bus-master'),
        bus(id: 'voice', name: 'Voice', output: 'bus-master'),
      ],
    };
    final inputs = compileOfficialMixInputs(
      project: project,
      pcmByClipId: {'c-music': musicPcm, 'c-voice': voicePcm},
    );
    expect(inputs.length, 1);
    expect(inputs.single.busId, 'voice');
    final mixed = mix48k(
      AudioBusGraph([
        for (final raw in project['audioBuses'] as List)
          AudioBus.fromJson(Map<String, dynamic>.from(raw as Map)),
      ], 'bus-master'),
      inputs,
    );
    expect(mixed.interleavedStereo, [0.25, 0.25]);
  });

  test('official analysis plan against a hand-tuned master and locked audio track mutates 0 fields', () {
    var p = avFixture();
    p = apply(p, ExtractAudioClip(video(p), 'audio-stream'));
    p = apply(p, const SetMasterAudio(gainDb: -3));
    final manual = GainEnvelope([
      GainPoint(Q.of(0), -3),
      GainPoint(Q.of(5), -3),
    ]);
    final audioId =
        tracks(p).singleWhere((t) => t['kind'] == 'audio')['id'] as String;
    final locked = apply(p, SetTrackState(audioId, locked: true));
    final before = jsonEncode(locked.toJson());
    expect(
      () => AnalysisGainPlayback.apply(
        manual: manual,
        clip: TimeRange(Q.of(0), Q.of(5)),
        speech: [TimeRange(Q.of(1), Q.of(1))],
        trackLocked:
            locked.toJson()['sequences'][0]['tracks'].singleWhere(
              (t) => t['id'] == audioId,
            )['locked'] ==
            true,
      ),
      code('TRACK_LOCKED'),
    );
    expect(jsonEncode(locked.toJson()), before);
    expect(locked.toJson()['audioBuses'][0]['gainDb'], -3);
    final unlocked = apply(locked, SetTrackState(audioId, locked: false));
    final after = AnalysisGainPlayback.apply(
      manual: manual,
      clip: TimeRange(Q.of(0), Q.of(5)),
      speech: [TimeRange(Q.of(1), Q.of(1))],
    );
    expect(after.manualMutations, 0);
    expect(unlocked.toJson()['audioBuses'][0]['gainDb'], -3);
    expect(manual.points.first.db, -3);
    expect(manual.points.last.db, -3);
  });
}
