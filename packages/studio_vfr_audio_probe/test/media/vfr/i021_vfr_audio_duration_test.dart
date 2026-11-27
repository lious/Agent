import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_vfr_audio_probe/studio_vfr_audio_probe.dart';
import 'package:test/test.dart';

/// Increment 2.84 official s4 leftover: VFR normalization retains actual
/// audio duration and must not stretch audio to a nominal fps duration.
/// This file does not rewrite source_preview_test or frame_proxy_test,
/// does not re-qualify I-021 20-point seek / VFR / nonzero-PTS / cache
/// leftovers, Increment 2.83 VarispeedAdmission, Increment 2.82 I-005
/// 0.02s link-offset work, Increment 2.81 V-023 PressureAdmission,
/// Increment 2.79 delivery-fps, or Increment 2.80 media retention, and
/// does not invent a retimer, time-stretch engine, limiter, or muxer.
/// InversePatch kind stays restoreSnapshot. Project user_version stays 9.
/// I-021 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('VFR normalize keeps actual audio samples; stretching to nominal fps duration is refused', () {
    final admission = VfrAudioDurationAdmission();
    // 30 VFR frames, nominal 30 fps => 1s / 48000 samples, but actual audio is 1.2s.
    const request = VfrAudioNormalizeRequest(
      frameCount: 30,
      nominalFpsNum: 30,
      nominalFpsDen: 1,
      actualAudioSamples: 57600,
      sampleRate: 48000,
      outputAudioSamples: 57600,
    );
    expect(request.nominalAudioSamples, 48000);
    final receipt = admission.admit(request);
    expect(receipt.outputAudioSamples, 57600);
    expect(
      () => admission.admit(
        const VfrAudioNormalizeRequest(
          frameCount: 30,
          nominalFpsNum: 30,
          nominalFpsDen: 1,
          actualAudioSamples: 57600,
          sampleRate: 48000,
          outputAudioSamples: 48000,
          stretchAudioToNominal: true,
        ),
      ),
      code('AUDIO_STRETCHED_TO_NOMINAL_FPS'),
    );
  });

  test('writing audio length from nominal fps without an explicit stretch flag is still refused', () {
    final admission = VfrAudioDurationAdmission();
    expect(
      () => admission.admit(
        const VfrAudioNormalizeRequest(
          frameCount: 30,
          nominalFpsNum: 30,
          nominalFpsDen: 1,
          actualAudioSamples: 57600,
          sampleRate: 48000,
          outputAudioSamples: 48000,
        ),
      ),
      code('AUDIO_STRETCHED_TO_NOMINAL_FPS'),
    );
    expect(
      () => admission.admit(
        const VfrAudioNormalizeRequest(
          frameCount: 30,
          nominalFpsNum: 0,
          nominalFpsDen: 1,
          actualAudioSamples: 48000,
          sampleRate: 48000,
          outputAudioSamples: 48000,
        ),
      ),
      code('RATE_INVALID'),
    );
  });

  test('I-021 seek/VFR/PTS leftovers, delivery-fps, media retention, and varispeed stay closed', () {
    final admission = VfrAudioDurationAdmission();
    expect(admission.i021SeekRequalified, isFalse);
    expect(admission.deliveryFpsRequalified, isFalse);
    expect(admission.mediaRetentionRequalified, isFalse);
    expect(admission.varispeedRequalified, isFalse);
    expect(admission.retimerInvented, isFalse);
    expect(admission.timeStretchInvented, isFalse);
    expect(admission.muxerInvented, isFalse);
    expect(admission.limiterInvented, isFalse);
    expect(admission.pcmRemapInvented, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
