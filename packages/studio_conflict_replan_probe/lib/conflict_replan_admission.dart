import 'package:studio_contracts/studio_contracts.dart';

const conflictSubmitCodes = {
  'REVISION_CONFLICT',
  'READSET_STALE',
  'FIELD_LOCKED',
};

final class ConflictSubmitRequest {
  const ConflictSubmitRequest({
    required this.conflictCode,
    required this.candidateRetained,
    this.replanned = false,
    this.previewedAfterReplan = false,
    this.autoRetryOverwrite = false,
  });

  /// One of `REVISION_CONFLICT`, `READSET_STALE`, or `FIELD_LOCKED`.
  final String conflictCode;
  final bool candidateRetained;
  final bool replanned;
  final bool previewedAfterReplan;
  final bool autoRetryOverwrite;
}

final class ConflictSubmitReceipt {
  const ConflictSubmitReceipt({
    required this.submitted,
    required this.candidateRetained,
  });

  final bool submitted;
  final bool candidateRetained;
}

/// DEV-PURE I-005 / s3 admission: after `REVISION_CONFLICT`,
/// `READSET_STALE`, or `FIELD_LOCKED`, the candidate is retained.
/// A later submit is allowed only after a new plan and a new preview.
/// An automatic retry must not overwrite.
///
/// This is not a PlanGraph, IntentReducer, or Flutter widget tree,
/// and not a re-qualification of Increment 3.02 CommandClampAdmission,
/// Increment 2.82 0.02s link-offset work, the frozen s3 1/30s suite,
/// I-003 revision tests, or I-025 leftovers closed by ADR 0104.
final class ConflictReplanAdmission {
  bool commandClampRequalified = false;
  bool linkOffsetRequalified = false;
  bool frozenS3SuiteRewritten = false;
  bool trimPlannerInvented = false;
  bool flutterWidgetTreeInvented = false;
  bool videoMutedSoloOpened = false;
  bool osClipboardInvented = false;
  bool autoCloseInvented = false;
  bool planGraphInvented = false;
  bool intentReducerInvented = false;
  bool i003Requalified = false;
  bool i025Requalified = false;

  ConflictSubmitReceipt admit(ConflictSubmitRequest request) {
    if (!conflictSubmitCodes.contains(request.conflictCode)) {
      throw const StudioException('CONFLICT_CODE_UNKNOWN', 'command');
    }
    if (request.autoRetryOverwrite) {
      throw const StudioException('AUTO_RETRY_OVERWRITE_FORBIDDEN', 'command');
    }
    if (!request.candidateRetained) {
      throw const StudioException('CANDIDATE_NOT_RETAINED', 'command');
    }
    if (!request.replanned || !request.previewedAfterReplan) {
      throw const StudioException('REPLAN_PREVIEW_REQUIRED', 'command');
    }
    return const ConflictSubmitReceipt(
      submitted: true,
      candidateRetained: true,
    );
  }
}
