import 'package:studio_contracts/studio_contracts.dart';

final class WriterFenceRequest {
  const WriterFenceRequest({
    this.lockLive = false,
    this.stealByExpiryOnly = false,
    this.staleWorkerResult = false,
    this.mutatesHead = false,
    this.mutatesPublishTarget = false,
  });

  /// The current owner still holds a live project writer lock.
  final bool lockLive;
  final bool stealByExpiryOnly;
  final bool staleWorkerResult;
  final bool mutatesHead;
  final bool mutatesPublishTarget;
}

final class WriterFenceReceipt {
  const WriterFenceReceipt({
    required this.admitted,
    required this.headMutated,
    required this.publishTargetMutated,
  });

  final bool admitted;
  final bool headMutated;
  final bool publishTargetMutated;
}

/// DEV-PURE I-003 / s5b admission: a live project writer lock must not
/// be stolen merely because a timer expired. A stale worker result is
/// `STALE_WRITER` and must not mutate head or the publish target.
///
/// This is the project editor writer fence, not I-032 PlanGraph or
/// harness lease fencing (`LEASE_FENCED`). A PlanGraph manual-lock API
/// is not invented. Crash takeover and pending-publication
/// reconciliation are not officialized here. I-003 revision tests,
/// Increment 3.08 SqlCloudSideEffectAdmission, I-032, and I-011 crash
/// leftovers are not re-qualified.
final class WriterFenceAdmission {
  bool sqlCloudSideEffectRequalified = false;
  bool i032PlanGraphFenceRequalified = false;
  bool planGraphManualLockInvented = false;
  bool i011CrashRequalified = false;
  bool i003RevisionTestsRewritten = false;
  bool closeCheckpointRequalified = false;
  bool quoteApplyStarted = false;
  bool paidApiCalled = false;
  bool osLockRuntimeInvented = false;

  WriterFenceReceipt admit(WriterFenceRequest request) {
    if (request.stealByExpiryOnly && request.lockLive) {
      throw const StudioException('STEAL_LIVE_LOCK_FORBIDDEN', 'writer');
    }
    if (request.staleWorkerResult) {
      throw const StudioException('STALE_WRITER', 'writer');
    }
    return const WriterFenceReceipt(
      admitted: true,
      headMutated: false,
      publishTargetMutated: false,
    );
  }
}
