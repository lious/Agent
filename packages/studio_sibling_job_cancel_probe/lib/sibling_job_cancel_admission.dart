import 'package:studio_contracts/studio_contracts.dart';

const siblingJobCancelKinds = {'siblingJobCancel'};

final class SiblingJobCancelRequest {
  const SiblingJobCancelRequest({
    required this.kind,
    required this.cancelTarget,
    required this.cancelledJobs,
  });

  /// `siblingJobCancel`.
  final String kind;

  /// The job being cancelled, for example `jA`.
  final String cancelTarget;

  /// Jobs actually cancelled. Must equal exactly `[cancelTarget]`.
  final List<String> cancelledJobs;
}

final class SiblingJobCancelReceipt {
  const SiblingJobCancelReceipt({
    required this.admitted,
    required this.siblingJobsCancelled,
  });

  final bool admitted;
  final bool siblingJobsCancelled;
}

/// DEV-PURE s11 admission: cancelling one shot's generation job
/// must not cancel the other shots' jobs.
///
/// This does not officialize “usage独立对账,” “先完成jB不自动替换画面,”
/// or “generation完成只发布candidate.ready，不执行accept.” It does
/// not re-qualify Increment 3.04 JobCancelAdmission, Increment 3.36
/// SessionNavigationAdmission, Increment 3.39 DeleteKindAdmission,
/// ADR 0028, I-031 private-reasoning journal omission, I-040, or
/// I-005. A WorkflowCoordinator is not invented, and no paid API
/// is called.
final class SiblingJobCancelAdmission {
  bool jobCancelRequalified = false;
  bool sessionNavigationRequalified = false;
  bool deleteKindRequalified = false;
  bool adr0028Requalified = false;
  bool i040Requalified = false;
  bool i005Rewritten = false;
  bool usageAccountingOfficialized = false;
  bool candidateReadyOfficialized = false;
  bool workflowCoordinatorInvented = false;
  bool paidApiCalled = false;
  bool privateReasoningRequalified = false;
  bool offlineCapabilityRequalified = false;
  bool modelContextRequalified = false;

  SiblingJobCancelReceipt admit(SiblingJobCancelRequest request) {
    if (!siblingJobCancelKinds.contains(request.kind) ||
        request.cancelTarget.isEmpty) {
      throw const StudioException(
        'SIBLING_JOB_CANCEL_KIND_UNKNOWN',
        'validator',
      );
    }
    final cancelled = request.cancelledJobs.toSet();
    if (!cancelled.contains(request.cancelTarget) || cancelled.length != 1) {
      final extras = cancelled.difference({request.cancelTarget});
      if (extras.isNotEmpty) {
        throw const StudioException('CANCEL_SIBLING_JOB', 'validator');
      }
      throw const StudioException(
        'SIBLING_JOB_CANCEL_KIND_UNKNOWN',
        'validator',
      );
    }
    return const SiblingJobCancelReceipt(
      admitted: true,
      siblingJobsCancelled: false,
    );
  }
}
