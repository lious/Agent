import 'package:studio_contracts/studio_contracts.dart';

final class VfrAudioNormalizeRequest {
  const VfrAudioNormalizeRequest({
    required this.frameCount,
    required this.nominalFpsNum,
    required this.nominalFpsDen,
    required this.actualAudioSamples,
    required this.sampleRate,
    required this.outputAudioSamples,
    this.stretchAudioToNominal = false,
  });

  final int frameCount,
      nominalFpsNum,
      nominalFpsDen,
      actualAudioSamples,
      sampleRate,
      outputAudioSamples;
  final bool stretchAudioToNominal;

  /// Nominal CFR duration in samples: frameCount * sampleRate * den / num,
  /// exact only when it divides.
  int? get nominalAudioSamples {
    if (nominalFpsNum <= 0 ||
        nominalFpsDen <= 0 ||
        sampleRate <= 0 ||
        frameCount < 0) {
      return null;
    }
    final product = frameCount * sampleRate * nominalFpsDen;
    if (product % nominalFpsNum != 0) return null;
    return product ~/ nominalFpsNum;
  }
}

final class VfrAudioNormalizeReceipt {
  const VfrAudioNormalizeReceipt({required this.outputAudioSamples});

  final int outputAudioSamples;
}

/// DEV-PURE I-021 / s4 admission: VFR normalization retains actual audio
/// duration and must not stretch audio to a nominal fps duration. This is
/// not a retimer, not a time-stretch engine, and not a re-qualification of
/// I-021 seek/VFR/PTS mapping, Increment 2.79 delivery-fps, Increment 2.80
/// media retention, or Increment 2.83 varispeed-and-pitch policy.
final class VfrAudioDurationAdmission {
  bool i021SeekRequalified = false;
  bool deliveryFpsRequalified = false;
  bool mediaRetentionRequalified = false;
  bool varispeedRequalified = false;
  bool retimerInvented = false;
  bool timeStretchInvented = false;
  bool muxerInvented = false;
  bool limiterInvented = false;
  bool pcmRemapInvented = false;
  bool paidApiCalled = false;

  VfrAudioNormalizeReceipt admit(VfrAudioNormalizeRequest request) {
    if (request.frameCount < 0 ||
        request.nominalFpsNum <= 0 ||
        request.nominalFpsDen <= 0 ||
        request.actualAudioSamples < 0 ||
        request.sampleRate <= 0 ||
        request.outputAudioSamples < 0) {
      throw const StudioException('RATE_INVALID', 'vfr-audio');
    }
    if (request.stretchAudioToNominal ||
        request.outputAudioSamples != request.actualAudioSamples) {
      throw const StudioException('AUDIO_STRETCHED_TO_NOMINAL_FPS', 'audio');
    }
    return VfrAudioNormalizeReceipt(
      outputAudioSamples: request.actualAudioSamples,
    );
  }
}
