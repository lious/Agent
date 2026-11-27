import 'package:studio_contracts/studio_contracts.dart';

enum ProbeDirection { decode, encode }

enum MediaModality { video, audio }

final class CodecProbeRequest {
  const CodecProbeRequest({
    required this.direction,
    required this.modality,
    required this.container,
    required this.codec,
    this.width,
    this.height,
    this.fpsNum,
    this.fpsDen,
    this.sampleRate,
    this.channelCount,
    this.channelLayout,
    this.bitrate,
    this.sampleFormat,
    this.advertised = false,
    this.sessionCreated = false,
    this.sampleProcessed = false,
    this.unknown = false,
    this.claimSupported = false,
    this.applyAs,
    this.forgeUnrelatedZeros = false,
    this.inferAudioFromVideoCaps = false,
  });

  final ProbeDirection direction;
  final MediaModality modality;
  final String container, codec;
  final String? width,
      height,
      fpsNum,
      fpsDen,
      sampleRate,
      channelCount,
      channelLayout,
      bitrate,
      sampleFormat;
  final bool advertised,
      sessionCreated,
      sampleProcessed,
      unknown,
      claimSupported,
      forgeUnrelatedZeros,
      inferAudioFromVideoCaps;
  final ProbeDirection? applyAs;
}

final class CodecProbeResult {
  CodecProbeResult({
    required this.direction,
    required this.modality,
    required this.supported,
    required this.advertised,
    required this.sessionCreated,
    required this.sampleProcessed,
    required this.width,
    required this.height,
    required this.fpsNum,
    required this.fpsDen,
    required this.sampleRate,
    required this.channelCount,
    required this.channelLayout,
    required this.bitrate,
    required this.sampleFormat,
  });

  final ProbeDirection direction;
  final MediaModality modality;
  final bool supported, advertised, sessionCreated, sampleProcessed;
  final String? width,
      height,
      fpsNum,
      fpsDen,
      sampleRate,
      channelCount,
      channelLayout,
      bitrate,
      sampleFormat;
}

/// DEV-PURE s6c CodecProbePort. This is not a real codec, FFmpeg,
/// VideoToolbox, MediaCodec, MFT, or WebCodecs probe, and it is
/// not a re-qualification of V-002 format-reason or I-015 leftovers.
final class CodecProbePort {
  bool realProbeInvented = false;
  bool formatReasonRequalified = false;
  bool i015Requalified = false;
  bool registryRequalified = false;
  bool fallbackPlannerRequalified = false;
  bool v001Requalified = false;
  bool i042LeaseRequalified = false;
  bool paidApiCalled = false;
  bool v007Claimed = false;

  CodecProbeResult probe(CodecProbeRequest request) {
    if (request.applyAs != null && request.applyAs != request.direction) {
      throw const StudioException(
        'DECODE_ENCODE_NOT_INTERCHANGEABLE',
        'direction',
      );
    }
    if (request.inferAudioFromVideoCaps) {
      throw const StudioException('COMBINATION_NOT_INFERRED', 'audio');
    }
    if (request.forgeUnrelatedZeros) {
      throw const StudioException('FORGED_MODALITY_ZERO', 'modality');
    }
    _rejectForgedZeros(request);

    final unknown = request.unknown || !request.sampleProcessed;
    final qualified =
        !unknown && request.sessionCreated && request.sampleProcessed;
    if (request.claimSupported && !qualified) {
      throw const StudioException('UNKNOWN_NOT_SUPPORTED', 'supported');
    }

    final video = request.modality == MediaModality.video;
    return CodecProbeResult(
      direction: request.direction,
      modality: request.modality,
      supported: qualified && request.claimSupported,
      advertised: request.advertised,
      sessionCreated: request.sessionCreated,
      sampleProcessed: request.sampleProcessed,
      width: video ? request.width : null,
      height: video ? request.height : null,
      fpsNum: video ? request.fpsNum : null,
      fpsDen: video ? request.fpsDen : null,
      sampleRate: video ? null : request.sampleRate,
      channelCount: video ? null : request.channelCount,
      channelLayout: video ? null : request.channelLayout,
      bitrate: video ? null : request.bitrate,
      sampleFormat: video ? null : request.sampleFormat,
    );
  }

  void _rejectForgedZeros(CodecProbeRequest request) {
    final unrelated = request.modality == MediaModality.video
        ? [
            request.sampleRate,
            request.channelCount,
            request.channelLayout,
            request.bitrate,
            request.sampleFormat,
          ]
        : [request.width, request.height, request.fpsNum, request.fpsDen];
    for (final value in unrelated) {
      if (value == '0') {
        throw const StudioException('FORGED_MODALITY_ZERO', 'modality');
      }
    }
  }
}
