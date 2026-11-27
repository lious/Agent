import 'package:studio_contracts/studio_contracts.dart';

final class IccFirstRequest {
  const IccFirstRequest({
    required this.iccProfilePresent,
    required this.iccApplied,
    this.colorOpsBeforeIcc = false,
  });

  final bool iccProfilePresent, iccApplied, colorOpsBeforeIcc;
}

final class IccFirstReceipt {
  const IccFirstReceipt({required this.iccAppliedFirst});

  final bool iccAppliedFirst;
}

/// DEV-PURE V-006 / s4 admission: image ICC is applied first, before
/// working-space color operations. This is not an ICC, HDR, or LUT
/// runtime, not a ColorPipelineAdmission or RotationOnceAdmission
/// re-qualification, and not a V-006 numeric or appearance claim.
final class IccFirstAdmission {
  bool iccRuntimeInvented = false;
  bool hdrRuntimeInvented = false;
  bool lutRuntimeInvented = false;
  bool v006NumericClaimed = false;
  bool v006AppearanceClaimed = false;
  bool colorPipelineRequalified = false;
  bool rotationOnceRequalified = false;
  bool renderRecipeRequalified = false;
  bool i059Started = false;
  bool paidApiCalled = false;

  IccFirstReceipt admit(IccFirstRequest request) {
    if (!request.iccProfilePresent) {
      return const IccFirstReceipt(iccAppliedFirst: false);
    }
    if (!request.iccApplied) {
      throw const StudioException('ICC_TRANSFORM_SKIPPED', 'icc');
    }
    if (request.colorOpsBeforeIcc) {
      throw const StudioException('ICC_MUST_BE_FIRST', 'icc');
    }
    return const IccFirstReceipt(iccAppliedFirst: true);
  }
}
