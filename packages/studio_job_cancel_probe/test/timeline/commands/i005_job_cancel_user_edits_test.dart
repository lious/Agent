import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_job_cancel_probe/studio_job_cancel_probe.dart';
import 'package:test/test.dart';

/// Increment 3.04 official I-005 / s3 leftover: canceling a failed
/// export or a cloud generation must not undo already-completed user
/// edits.
///
/// This file does not re-qualify Increment 3.03 ConflictReplanAdmission,
/// Increment 3.02 CommandClampAdmission, ADR 0028 gesture cancel, or
/// official I-024 export suites. A WorkflowCoordinator, quote/apply,
/// and an I-014 RestoreService commit path are not invented.
/// InversePatch kind stays restoreSnapshot. Project user_version
/// stays 9. I-005 stays partial. Remaining I-005 remainingAcceptance
/// labels are not silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('canceling a failed export or a cloud generation keeps already-completed user edits', () {
    final admission = JobCancelAdmission();
    for (final kind in jobCancelKinds) {
      final receipt = admission.admit(
        JobCancelRequest(kind: kind, userEditsCommitted: true),
      );
      expect(receipt.cancelled, isTrue);
      expect(receipt.userEditsRetained, isTrue);
    }
  });

  test('a cancel that would undo committed user edits, or an unknown job kind, is refused', () {
    final admission = JobCancelAdmission();
    expect(
      () => admission.admit(
        const JobCancelRequest(
          kind: 'exportJob',
          userEditsCommitted: true,
          undoesCommittedUserEdits: true,
        ),
      ),
      code('USER_EDITS_MUST_BE_RETAINED'),
    );
    expect(
      () => admission.admit(
        const JobCancelRequest(
          kind: 'userTimelineEdit',
          userEditsCommitted: true,
        ),
      ),
      code('JOB_CANCEL_KIND_UNKNOWN'),
    );
  });

  test('Increment 3.03 conflict-replan work, I-024 export suites, quote/apply, and an I-014 RestoreService stay closed', () {
    final admission = JobCancelAdmission();
    expect(admission.conflictReplanRequalified, isFalse);
    expect(admission.commandClampRequalified, isFalse);
    expect(admission.gestureCancelRequalified, isFalse);
    expect(admission.i024ExportRequalified, isFalse);
    expect(admission.i014RestoreInvented, isFalse);
    expect(admission.workflowCoordinatorInvented, isFalse);
    expect(admission.quoteApplyStarted, isFalse);
    expect(admission.paidApiCalled, isFalse);
    expect(admission.trimPlannerInvented, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
  });
}
