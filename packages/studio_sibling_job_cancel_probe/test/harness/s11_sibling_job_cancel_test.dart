import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_sibling_job_cancel_probe/studio_sibling_job_cancel_probe.dart';
import 'package:test/test.dart';

/// Increment 3.40 official s11 leftover: cancelling one shot's
/// generation job must not cancel the other shots' jobs.
///
/// This file does not officialize usage accounting or
/// candidate.ready-without-accept, and does not re-qualify
/// Increment 3.04 JobCancelAdmission, Increment 3.36
/// SessionNavigationAdmission, Increment 3.39
/// DeleteKindAdmission, ADR 0028, I-031 private-reasoning
/// journal omission, I-040, or I-005. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. This is not
/// an I-013 packing or archive slice, not an I-002 measurement
/// claim, and not a license, session-navigation, delete-kind,
/// model-context, or offline-capability leftover already
/// officialized in 3.32, 3.35, 3.36, 3.37, 3.38, or 3.39.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test("cancelling one shot must not cancel the other shots' jobs", () {
    final admission = SiblingJobCancelAdmission();
    final receipt = admission.admit(
      const SiblingJobCancelRequest(
        kind: 'siblingJobCancel',
        cancelTarget: 'jA',
        cancelledJobs: ['jA'],
      ),
    );
    expect(receipt.admitted, isTrue);
    expect(receipt.siblingJobsCancelled, isFalse);

    expect(
      () => admission.admit(
        const SiblingJobCancelRequest(
          kind: 'unknown',
          cancelTarget: 'jA',
          cancelledJobs: ['jA'],
        ),
      ),
      code('SIBLING_JOB_CANCEL_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const SiblingJobCancelRequest(
          kind: 'siblingJobCancel',
          cancelTarget: '',
          cancelledJobs: ['jA'],
        ),
      ),
      code('SIBLING_JOB_CANCEL_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const SiblingJobCancelRequest(
          kind: 'siblingJobCancel',
          cancelTarget: 'jA',
          cancelledJobs: ['jA', 'jB', 'jC'],
        ),
      ),
      code('CANCEL_SIBLING_JOB'),
    );
    expect(
      () => admission.admit(
        const SiblingJobCancelRequest(
          kind: 'siblingJobCancel',
          cancelTarget: 'jA',
          cancelledJobs: ['jB'],
        ),
      ),
      code('CANCEL_SIBLING_JOB'),
    );
  });

  test('JobCancelAdmission, SessionNavigationAdmission, DeleteKindAdmission, ADR 0028, I-040, and usage accounting stay closed', () {
    final admission = SiblingJobCancelAdmission();
    expect(admission.jobCancelRequalified, isFalse);
    expect(admission.sessionNavigationRequalified, isFalse);
    expect(admission.deleteKindRequalified, isFalse);
    expect(admission.adr0028Requalified, isFalse);
    expect(admission.i040Requalified, isFalse);
    expect(admission.i005Rewritten, isFalse);
    expect(admission.usageAccountingOfficialized, isFalse);
    expect(admission.candidateReadyOfficialized, isFalse);
    expect(admission.workflowCoordinatorInvented, isFalse);
    expect(admission.paidApiCalled, isFalse);
    expect(admission.privateReasoningRequalified, isFalse);
    expect(admission.offlineCapabilityRequalified, isFalse);
    expect(admission.modelContextRequalified, isFalse);
  });
}
