import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_writer_fence_probe/studio_writer_fence_probe.dart';
import 'package:test/test.dart';

/// Increment 3.09 official I-003 / s5b leftover: a live project writer
/// lock must not be stolen merely because a timer expired. A stale
/// worker result is STALE_WRITER and must not mutate head or the
/// publish target.
///
/// This is the project editor writer fence, not I-032 PlanGraph or
/// harness lease fencing. A PlanGraph manual-lock API is not invented.
/// Crash takeover is not officialized here. This file does not
/// re-qualify Increment 3.08 SqlCloudSideEffectAdmission, I-003
/// revision tests, I-032, or I-011 crash leftovers. InversePatch kind
/// stays restoreSnapshot. Project user_version stays 9. I-003 stays
/// partial. Existing I-003 remainingAcceptance labels are not silently
/// cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a live writer lock is admitted for the owner and must not be stolen by expiry alone', () {
    final admission = WriterFenceAdmission();
    final receipt = admission.admit(const WriterFenceRequest(lockLive: true));
    expect(receipt.admitted, isTrue);
    expect(receipt.headMutated, isFalse);
    expect(receipt.publishTargetMutated, isFalse);
    expect(
      () => admission.admit(
        const WriterFenceRequest(lockLive: true, stealByExpiryOnly: true),
      ),
      code('STEAL_LIVE_LOCK_FORBIDDEN'),
    );
  });

  test('a stale worker result is STALE_WRITER and does not mutate head or the publish target', () {
    final admission = WriterFenceAdmission();
    expect(
      () => admission.admit(
        const WriterFenceRequest(
          staleWorkerResult: true,
          mutatesHead: true,
          mutatesPublishTarget: true,
        ),
      ),
      code('STALE_WRITER'),
    );
    expect(
      () => admission.admit(const WriterFenceRequest(staleWorkerResult: true)),
      code('STALE_WRITER'),
    );
  });

  test('Increment 3.08 SQL cloud-side-effect work, I-032 PlanGraph fencing, a manual-lock API, I-003 revision tests, and I-011 crash leftovers stay closed', () {
    final admission = WriterFenceAdmission();
    expect(admission.sqlCloudSideEffectRequalified, isFalse);
    expect(admission.i032PlanGraphFenceRequalified, isFalse);
    expect(admission.planGraphManualLockInvented, isFalse);
    expect(admission.i011CrashRequalified, isFalse);
    expect(admission.i003RevisionTestsRewritten, isFalse);
    expect(admission.closeCheckpointRequalified, isFalse);
    expect(admission.quoteApplyStarted, isFalse);
    expect(admission.paidApiCalled, isFalse);
    expect(admission.osLockRuntimeInvented, isFalse);
  });
}
