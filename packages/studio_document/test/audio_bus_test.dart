import 'dart:math' as math;
import 'dart:typed_data';

import 'package:studio_document/studio_document.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));
AudioBusGraph graph({
  bool muteMusic = false,
  bool soloVoice = false,
  double masterGain = 0,
}) => AudioBusGraph([
  AudioBus(id: 'master', inputs: ['music', 'voice'], gainDb: masterGain),
  AudioBus(id: 'music', inputs: [], output: 'master', muted: muteMusic),
  AudioBus(id: 'voice', inputs: [], output: 'master', solo: soloVoice),
], 'master');
void main() {
  test('graph reciprocal refs, duplicate and disconnected cycles are refused deterministically', () {
    expect(graph().recipe, ['music', 'voice', 'master']);
    expect(
      () => AudioBusGraph([
        AudioBus(id: 'm', inputs: ['x']),
      ], 'm'),
      code('AUDIO_ROUTE_MISMATCH'),
    );
    expect(
      () => AudioBusGraph([
        AudioBus(id: 'm', inputs: []),
        AudioBus(id: 'a', inputs: ['b'], output: 'b'),
        AudioBus(id: 'b', inputs: ['a'], output: 'a'),
      ], 'm'),
      code('AUDIO_ROUTE_CYCLE'),
    );
    expect(
      () => AudioBus(id: 'x', inputs: ['y', 'y']),
      code('DUPLICATE_AUDIO_ROUTE'),
    );
    expect(
      () => AudioBusGraph([
        AudioBus(id: 'm', inputs: []),
        AudioBus(id: 'm', inputs: []),
      ], 'm'),
      code('DUPLICATE_ID'),
    );
  });
  test('gain, mono equal-power pan and stereo balance have explicit distinct policies', () {
    expect(gainAmplitude(-6), closeTo(0.5011872336, 1e-9));
    expect(monoPan(0).reduce((a, b) => a * a + b * b), closeTo(1, 1e-12));
    expect(monoPan(-1)[0], 1);
    expect(monoPan(1)[1], 1);
    expect(stereoBalance(0), [1, 1]);
    expect(stereoBalance(-1), [1, 0]);
    expect(stereoBalance(1), [0, 1]);
    expect(() => gainAmplitude(double.nan), code('AUDIO_PARAMETER_RANGE'));
    expect(() => monoPan(1.01), code('AUDIO_PARAMETER_RANGE'));
  });
  test('exact absolute sample mapping, hold/linear interpolation and source anchors survive 2x retime', () {
    final curve = GainEnvelope([
      GainPoint(Q.of(0), 0),
      GainPoint(Q.of(1), -12),
      GainPoint(Q.of(2), 0),
    ]);
    expect(curve.at(Q.of(1, 2)), -6);
    expect(curve.at(Q.of(1)), -12);
    expect(
      curve.atTimeline(
        Q.of(10, 1) + Q.of(1, 2),
        clipStart: Q.of(10),
        sourceStart: Q.of(0),
        rate: Q.of(2),
        sourceAnchored: true,
      ),
      -12,
    );
    expect(
      curve.atTimeline(
        Q.of(11),
        clipStart: Q.of(10),
        sourceStart: Q.of(0),
        rate: Q.of(1),
        sourceAnchored: true,
      ),
      -12,
    );
    final hold = GainEnvelope([
      GainPoint(Q.of(0), 0, interpolation: GainInterpolation.hold),
      GainPoint(Q.of(1), -12),
    ]);
    expect(hold.at(Q.of(47999, 48000)), 0);
    expect(hold.at(Q.of(48000, 48000)), -12);
    expect(
      () => GainEnvelope([GainPoint(Q.of(1), 0), GainPoint(Q.of(1), 1)]),
      code('GAIN_TIME_ORDER'),
    );
    expect(
      () => curve.points.add(GainPoint(Q.of(3), 0)),
      throwsUnsupportedError,
    );
  });
  test('duck proposal is a separate lower envelope, clips endpoints and protects manual regions and locks', () {
    final manual = GainEnvelope([
          GainPoint(Q.of(0), -3),
          GainPoint(Q.of(5), -4),
        ]),
        original = manual.points.toList();
    final clip = TimeRange(Q.of(10), Q.of(5)),
        speech = [
          TimeRange(Q.of(11), Q.of(1)),
          TimeRange(Q.of(23, 2), Q.of(1)),
        ];
    final proposal = DuckingProposal.plan(clip: clip, speech: speech);
    expect(proposal.at(Q.of(4, 5)), closeTo(0, 1e-12));
    expect(proposal.at(Q.of(19, 20)), -9);
    expect(proposal.at(Q.of(6, 5)), -9);
    expect(proposal.at(Q.of(5)), 0);
    expect(manual.points, original);
    final protected = DuckingProposal.plan(
      clip: clip,
      speech: speech,
      manualProtected: [TimeRange(Q.of(1), Q.of(2))],
    );
    expect(protected.envelopes, isEmpty);
    expect(protected.warnings, everyElement('MANUAL_REGION_SKIPPED'));
    expect(
      () => DuckingProposal.plan(clip: clip, speech: speech, trackLocked: true),
      code('TRACK_LOCKED'),
    );
    expect(
      () => DuckingProposal.plan(clip: clip, speech: speech, gainLocked: true),
      code('MANUAL_LOCKED'),
    );
    final boundary = DuckingProposal.plan(
      clip: clip,
      speech: [TimeRange(Q.of(9), Q.of(10))],
    );
    expect(boundary.at(Q.of(0)), -9);
    expect(boundary.at(Q.of(5)), -9);
  });
  test('actual float PCM mute/solo/bus closure, stereo balance, no implicit limiter and source immutability', () {
    final samples = Float32List.fromList([1, 1, 1]);
    final music = PcmInput(busId: 'music', samples: samples, channels: 1),
        voice = PcmInput(
          busId: 'voice',
          samples: Float32List.fromList([0.5, 0.5, 0.5]),
          channels: 1,
        );
    samples[0] = 99;
    expect(music.samples[0], 1);
    expect(() => music.samples[0] = 2, throwsUnsupportedError);
    final muted = mix48k(graph(muteMusic: true), [music, voice]);
    expect(muted.interleavedStereo[0], closeTo(0.5 / math.sqrt2, 1e-6));
    final solo = mix48k(graph(soloVoice: true), [music, voice]);
    expect(solo.interleavedStereo, muted.interleavedStereo);
    final clipped = mix48k(graph(masterGain: 12), [music, voice]);
    expect(clipped.peak, greaterThan(1));
    expect(clipped.warnings, ['CLIPPING_RISK']);
    final left = mix48k(graph(), [
      PcmInput(
        busId: 'music',
        samples: Float32List.fromList([1, 0.5]),
        channels: 2,
        pan: -1,
      ),
    ]);
    expect(left.interleavedStereo, [1, 0]);
  });
  test(
    'bus automation at actual sample boundaries and finite PCM/length failures',
    () {
      final data = Float32List(8)..fillRange(0, 8, 1);
      final result = mix48k(
        graph(),
        [PcmInput(busId: 'music', samples: data, channels: 2)],
        automation: {
          'music': GainEnvelope([
            GainPoint(Q.of(0), 0, interpolation: GainInterpolation.hold),
            GainPoint(Q.of(2, 48000), -6),
          ]),
        },
      );
      expect(result.interleavedStereo[2], 1);
      expect(result.interleavedStereo[4], closeTo(gainAmplitude(-6), 1e-6));
      expect(
        () => PcmInput(
          busId: 'music',
          samples: Float32List.fromList([double.nan]),
          channels: 1,
        ),
        code('AUDIO_PCM_INVALID'),
      );
      expect(
        () => mix48k(graph(), [
          PcmInput(busId: 'music', samples: Float32List(1), channels: 1),
          PcmInput(busId: 'voice', samples: Float32List(2), channels: 1),
        ]),
        code('AUDIO_LENGTH_MISMATCH'),
      );
    },
  );
  test('silent/disconnected routes, scratch bounds and non-finite overflow fail explicitly', () {
    final g = AudioBusGraph([
      AudioBus(id: 'm', inputs: []),
      AudioBus(id: 'unused', inputs: [], solo: true),
    ], 'm');
    expect(mix48k(g, []).interleavedStereo, isEmpty);
    expect(
      () => mix48k(g, [
        PcmInput(busId: 'unused', samples: Float32List(1), channels: 1),
      ]),
      code('AUDIO_BUS_UNROUTED'),
    );
    expect(
      () => mix48k(graph(), [
        PcmInput(
          busId: 'voice',
          samples: Float32List(60 * 48000 + 1),
          channels: 1,
        ),
      ]),
      code('AUDIO_BLOCK_RESOURCE_LIMIT'),
    );
    expect(
      () => mix48k(graph(masterGain: 12), [
        PcmInput(
          busId: 'voice',
          samples: Float32List.fromList([3e38, 3e38]),
          channels: 2,
          gainDb: 12,
        ),
      ]),
      code('AUDIO_PCM_INVALID'),
    );
  });
  test('real 60 second 48k PCM processing preserves exact sample count and impulse index, not device/AAC qualification', () {
    const count = 60 * 48000, index = 48 * 48000 + 17;
    final pcm = Float32List(count)..[index] = 0.75;
    final mixed = mix48k(graph(), [
      PcmInput(busId: 'voice', samples: pcm, channels: 1, pan: -1),
    ]);
    expect(mixed.interleavedStereo.length, count * 2);
    expect(mixed.interleavedStereo[index * 2], 0.75);
    expect(mixed.peak, 0.75);
    expect(mixed.interleavedStereo.where((v) => v != 0).length, 1);
    expect(mixed.warnings, isEmpty);
  });
}
