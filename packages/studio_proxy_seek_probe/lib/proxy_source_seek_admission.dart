import 'package:studio_contracts/studio_contracts.dart';

final class ProxySourceSeekRequest {
  const ProxySourceSeekRequest({
    required this.proxyFrameIndex,
    required this.sourcePtsTicks,
    required this.sourceDurationTicks,
    this.seekOriginalByProxyFrameIndex = false,
    this.previewUsesMap = true,
    this.finalUsesMap = true,
  });

  /// Caller-supplied map lookup: the source PTS for [proxyFrameIndex].
  /// This admission does not invent a demuxer or recompute VFR mapping.
  final int proxyFrameIndex, sourcePtsTicks, sourceDurationTicks;
  final bool seekOriginalByProxyFrameIndex, previewUsesMap, finalUsesMap;
}

final class ProxySourceSeekReceipt {
  const ProxySourceSeekReceipt({required this.sourcePtsTicks});

  final int sourcePtsTicks;
}

/// DEV-PURE I-021 / s4 admission: final render picks the original source
/// frame by the same proxy-frame→source-PTS map as preview, and must not
/// seek the original by proxy frame number. This is not a re-qualification
/// of I-021 20-point seek / VFR / nonzero-PTS / cache suites or Increment
/// 2.84 VFR audio-duration admission, and is not a real demuxer or seeker.
final class ProxySourceSeekAdmission {
  bool i021SeekRequalified = false;
  bool vfrAudioRequalified = false;
  bool retimerInvented = false;
  bool demuxerInvented = false;
  bool oneFrameClaimed = false;
  bool paidApiCalled = false;

  ProxySourceSeekReceipt admit(ProxySourceSeekRequest request) {
    if (request.proxyFrameIndex < 0 ||
        request.sourcePtsTicks < 0 ||
        request.sourceDurationTicks <= 0) {
      throw const StudioException('RATE_INVALID', 'proxy-seek');
    }
    if (request.seekOriginalByProxyFrameIndex) {
      throw const StudioException('PROXY_FRAME_SEEK_FORBIDDEN', 'source');
    }
    if (!request.previewUsesMap || !request.finalUsesMap) {
      throw const StudioException('SOURCE_SELECTION_RULE_MISMATCH', 'source');
    }
    if (request.sourcePtsTicks >= request.sourceDurationTicks) {
      throw const StudioException('SOURCE_FRAME_OUT_OF_RANGE', 'source');
    }
    return ProxySourceSeekReceipt(sourcePtsTicks: request.sourcePtsTicks);
  }
}
