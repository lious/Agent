import 'package:studio_contracts/studio_contracts.dart';

const jobCancelKinds = {'exportJob', 'cloudGeneration'};

final class JobCancelRequest {
  const JobCancelRequest({
    required this.kind,
    required this.userEditsCommitted,
    this.undoesCommittedUserEdits = false,
  });

  /// `exportJob` or `cloudGeneration`.
  final String kind;
  final bool userEditsCommitted;
  final bool undoesCommittedUserEdits;
}

final class JobCancelReceipt {
  const JobCancelReceipt({
    required this.cancelled,
    required this.userEditsRetained,
  });

  final bool cancelled;
  final bool userEditsRetained;
}

/// DEV-PURE I-005 / s3 admission: canceling a failed export or a
/// cloud generation must not undo already-completed user edits.
///
/// This is not a rewrite of Increment 3.03 ConflictReplanAdmission,
/// Increment 3.02 CommandClampAdmission, ADR 0028 gesture cancel, or
/// official I-024 export suites. A WorkflowCoordinator, quote/apply,
/// and an I-014 RestoreService commit path are not invented.
final class JobCancelAdmission {
  bool conflictReplanRequalified = false;
  bool commandClampRequalified = false;
  bool gestureCancelRequalified = false;
  bool i024ExportRequalified = false;
  bool i014RestoreInvented = false;
  bool workflowCoordinatorInvented = false;
  bool quoteApplyStarted = false;
  bool paidApiCalled = false;
  bool trimPlannerInvented = false;
  bool flutterWidgetTreeInvented = false;

  JobCancelReceipt admit(JobCancelRequest request) {
    if (!jobCancelKinds.contains(request.kind)) {
      throw const StudioException('JOB_CANCEL_KIND_UNKNOWN', 'command');
    }
    if (request.undoesCommittedUserEdits) {
      throw const StudioException('USER_EDITS_MUST_BE_RETAINED', 'command');
    }
    return JobCancelReceipt(
      cancelled: true,
      userEditsRetained: request.userEditsCommitted,
    );
  }
}
