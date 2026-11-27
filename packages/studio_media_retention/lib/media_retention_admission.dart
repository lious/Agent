import 'package:studio_contracts/studio_contracts.dart';

final class RetentionRequest {
  const RetentionRequest({
    required this.originalHash,
    required this.ptsTicks,
    required this.colorMetadata,
    this.replaceOriginal = false,
    this.dropPts = false,
    this.dropColorMetadata = false,
    this.normalize = false,
    this.explicitNormalize = false,
  });

  final String originalHash, colorMetadata;
  final List<int> ptsTicks;
  final bool replaceOriginal,
      dropPts,
      dropColorMetadata,
      normalize,
      explicitNormalize;
}

final class RetentionReceipt {
  RetentionReceipt({
    required this.originalHash,
    required this.ptsTicks,
    required this.colorMetadata,
    required this.originalRetained,
    required this.ptsRetained,
    required this.colorMetadataRetained,
    required this.derivedNormalization,
    required this.unsupportedNotice,
  });

  final String originalHash, colorMetadata;
  final List<int> ptsTicks;
  final bool originalRetained,
      ptsRetained,
      colorMetadataRetained,
      derivedNormalization,
      unsupportedNotice;
}

/// DEV-PURE s6c original/PTS/color-metadata retention. Normalization
/// must be explicit, or the path is an unsupported notice. This is
/// not a re-qualification of V-006 ColorPipelineAdmission or the
/// Increment 2.79 delivery-fps PTS resample slice, and not a real
/// HDR, LUT, or retimer runtime.
final class MediaRetentionAdmission {
  bool v006Requalified = false;
  bool deliveryFpsRequalified = false;
  bool hdrRuntimeInvented = false;
  bool lutRuntimeInvented = false;
  bool retimerInvented = false;
  bool muxerInvented = false;
  bool i059Started = false;
  bool paidApiCalled = false;

  RetentionReceipt inspect(RetentionRequest request) {
    requireId(request.originalHash);
    if (request.replaceOriginal) {
      throw const StudioException('SOURCE_NOT_RETAINED', 'original');
    }
    if (request.dropPts) {
      throw const StudioException('PTS_NOT_RETAINED', 'pts');
    }
    if (request.dropColorMetadata) {
      throw const StudioException('COLOR_METADATA_NOT_RETAINED', 'color');
    }
    if (request.normalize && !request.explicitNormalize) {
      throw const StudioException(
        'NORMALIZATION_MUST_BE_EXPLICIT',
        'normalize',
      );
    }
    return RetentionReceipt(
      originalHash: request.originalHash,
      ptsTicks: List<int>.unmodifiable(request.ptsTicks),
      colorMetadata: request.colorMetadata,
      originalRetained: true,
      ptsRetained: true,
      colorMetadataRetained: true,
      derivedNormalization: request.normalize && request.explicitNormalize,
      unsupportedNotice: !request.normalize,
    );
  }
}
