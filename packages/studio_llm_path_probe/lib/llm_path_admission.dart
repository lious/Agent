import 'package:studio_contracts/studio_contracts.dart';

const pathOriginKinds = {'documentPath'};

/// Origins that are not an LLM. The s2 bound only forbids an
/// LLM-supplied path; it does not invent a broader path-tracker.
const allowedPathOrigins = {'application', 'user'};

final class LlmPathRequest {
  const LlmPathRequest({required this.kind, this.origin = 'application'});

  /// `documentPath`.
  final String kind;

  /// `application`, `user`, or `llm`.
  final String origin;
}

final class LlmPathReceipt {
  const LlmPathReceipt({required this.admitted, required this.pathFromLlm});

  final bool admitted;
  final bool pathFromLlm;
}

/// DEV-PURE s2 admission: a document path must not come from an LLM.
///
/// This does not re-qualify Increment 3.33 DropFrameAdmission, the
/// same s2 paragraph’s rational-second / per-frame formulas, or the
/// already-official “timeline time does not use wall clock” clock
/// ADRs. It does not officialize the same 基础类型 row’s createdAt /
/// updatedAt closed-root sentences. Increment 3.31
/// ErrorClassAdmission, Increment 3.32 LicenseExecutionAdmission,
/// and the remaining I-002 measurement labels are not re-qualified.
/// Schema v10 is not merged. The closed root is not extended.
/// Unknown fields are not swallowed.
final class LlmPathAdmission {
  bool rationalOpsRequalified = false;
  bool fkOverlapOverflowRequalified = false;
  bool syntheticProjectRequalified = false;
  bool errorClassRequalified = false;
  bool dropFrameRequalified = false;
  bool licenseExecutionRequalified = false;
  bool wallClockRequalified = false;
  bool closedRootExtended = false;
  bool unknownFieldsSwallowed = false;
  bool pathTrackerInvented = false;

  LlmPathReceipt admit(LlmPathRequest request) {
    if (!pathOriginKinds.contains(request.kind)) {
      throw const StudioException('PATH_ORIGIN_KIND_UNKNOWN', 'validator');
    }
    if (request.origin == 'llm') {
      throw const StudioException('PATH_FROM_LLM', 'validator');
    }
    if (!allowedPathOrigins.contains(request.origin)) {
      throw const StudioException('PATH_ORIGIN_KIND_UNKNOWN', 'validator');
    }
    return const LlmPathReceipt(admitted: true, pathFromLlm: false);
  }
}
