import 'package:studio_contracts/studio_contracts.dart';

const stillImageSourceKinds = {'image', 'imageDocument'};

final class StillImageClipRequest {
  const StillImageClipRequest({
    required this.sourceKind,
    this.streamId,
    this.videoAvailableRangeApplied = false,
    this.linear1x = true,
    this.sourceRangeIsStaticDomain = true,
  });

  /// `image` (image Asset) or `imageDocument`.
  final String sourceKind;
  final String? streamId;
  final bool videoAvailableRangeApplied, linear1x, sourceRangeIsStaticDomain;
}

final class StillImageClipReceipt {
  const StillImageClipReceipt({
    required this.streamIdNull,
    required this.staticSamplingDomain,
  });

  final bool streamIdNull, staticSamplingDomain;
}

/// DEV-PURE I-008 / s4 admission: an imageDocument or image Asset clip
/// has `streamId=null`, a synthesized `[0, Clip.duration)` static
/// sampling domain, and linear 1x. Video `availableRange` rules must
/// not refuse a still. This is not a re-qualification of ADR 0108 Ken
/// Burns transform keyframes or I-026 leftovers, and not a V-003
/// measurement or unregistered plugin.
final class StillImageClipAdmission {
  bool kenBurnsRequalified = false;
  bool i026Requalified = false;
  bool i008KeyframeRequalified = false;
  bool videoGenerationInvented = false;
  bool v003Claimed = false;
  bool unregisteredPluginInvented = false;
  bool paidApiCalled = false;

  StillImageClipReceipt admit(StillImageClipRequest request) {
    if (!stillImageSourceKinds.contains(request.sourceKind)) {
      throw const StudioException('STILL_IMAGE_KIND_REQUIRED', 'still');
    }
    if (request.streamId != null) {
      throw const StudioException('SOURCE_STREAM_MISMATCH', 'still');
    }
    if (request.videoAvailableRangeApplied) {
      throw const StudioException('VIDEO_AVAILABLE_RANGE_ON_STILL', 'still');
    }
    if (!request.linear1x || !request.sourceRangeIsStaticDomain) {
      throw const StudioException('STATIC_SOURCE_DOMAIN_INVALID', 'still');
    }
    return const StillImageClipReceipt(
      streamIdNull: true,
      staticSamplingDomain: true,
    );
  }
}
