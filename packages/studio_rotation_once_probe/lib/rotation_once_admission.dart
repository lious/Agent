import 'package:studio_contracts/studio_contracts.dart';

final class RotationOnceRequest {
  const RotationOnceRequest({
    required this.applyDisplayMatrix,
    required this.applyBakedPixelRotation,
    this.userTransformRotationDeg = 0,
  });

  /// Interpret container / EXIF / display-matrix orientation.
  final bool applyDisplayMatrix;

  /// Apply the same container orientation a second time to already-rotated
  /// pixels. This is not a user transform2d edit.
  final bool applyBakedPixelRotation;

  /// Creative clip transform; not a second interpretation of source
  /// orientation.
  final int userTransformRotationDeg;
}

final class RotationOnceReceipt {
  const RotationOnceReceipt({
    required this.containerRotationAppliedOnce,
    required this.userTransformRotationDeg,
  });

  final bool containerRotationAppliedOnce;
  final int userTransformRotationDeg;
}

/// DEV-PURE V-006 / s4 admission: source orientation is applied once.
/// This is not an HDR or LUT runtime, not a ColorPipelineAdmission
/// re-qualification, and not a V-006 numeric or appearance claim.
final class RotationOnceAdmission {
  bool hdrRuntimeInvented = false;
  bool lutRuntimeInvented = false;
  bool v006NumericClaimed = false;
  bool v006AppearanceClaimed = false;
  bool colorPipelineRequalified = false;
  bool i059Started = false;
  bool paidApiCalled = false;

  RotationOnceReceipt admit(RotationOnceRequest request) {
    if (request.applyDisplayMatrix && request.applyBakedPixelRotation) {
      throw const StudioException('ROTATION_APPLIED_TWICE', 'orientation');
    }
    return RotationOnceReceipt(
      containerRotationAppliedOnce:
          request.applyDisplayMatrix || request.applyBakedPixelRotation,
      userTransformRotationDeg: request.userTransformRotationDeg,
    );
  }
}
