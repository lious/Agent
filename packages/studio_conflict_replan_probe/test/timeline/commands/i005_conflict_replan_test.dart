import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_conflict_replan_probe/studio_conflict_replan_probe.dart';
import 'package:test/test.dart';

/// Increment 3.03 official I-005 / s3 leftover: after REVISION_CONFLICT,
/// READSET_STALE, or FIELD_LOCKED, the candidate is retained. A later
/// submit is allowed only after a new plan and a new preview. An
/// automatic retry must not overwrite.
///
/// This file does not invent a PlanGraph, IntentReducer, TrimPlanner,
/// or Flutter widget tree, and does not re-qualify Increment 3.02
/// CommandClampAdmission, Increment 2.82 0.02s link-offset work, the
/// frozen s3 1/30s suite, I-003 revision tests, or I-025 leftovers
/// closed by ADR 0104. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9. I-005 stays partial. Remaining I-005
/// remainingAcceptance labels are not silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('after a retained conflict, a submit is admitted only once a new plan has been previewed', () {
    final admission = ConflictReplanAdmission();
    for (final conflict in conflictSubmitCodes) {
      final receipt = admission.admit(
        ConflictSubmitRequest(
          conflictCode: conflict,
          candidateRetained: true,
          replanned: true,
          previewedAfterReplan: true,
        ),
      );
      expect(receipt.submitted, isTrue);
      expect(receipt.candidateRetained, isTrue);
    }
  });

  test('an automatic overwrite retry, a dropped candidate, or a submit without a new plan and preview is refused', () {
    final admission = ConflictReplanAdmission();
    expect(
      () => admission.admit(
        const ConflictSubmitRequest(
          conflictCode: 'REVISION_CONFLICT',
          candidateRetained: true,
          autoRetryOverwrite: true,
        ),
      ),
      code('AUTO_RETRY_OVERWRITE_FORBIDDEN'),
    );
    expect(
      () => admission.admit(
        const ConflictSubmitRequest(
          conflictCode: 'READSET_STALE',
          candidateRetained: false,
          replanned: true,
          previewedAfterReplan: true,
        ),
      ),
      code('CANDIDATE_NOT_RETAINED'),
    );
    expect(
      () => admission.admit(
        const ConflictSubmitRequest(
          conflictCode: 'FIELD_LOCKED',
          candidateRetained: true,
        ),
      ),
      code('REPLAN_PREVIEW_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const ConflictSubmitRequest(
          conflictCode: 'FIELD_LOCKED',
          candidateRetained: true,
          replanned: true,
        ),
      ),
      code('REPLAN_PREVIEW_REQUIRED'),
    );
  });

  test('Increment 3.02 command-clamp work, a TrimPlanner, a Flutter widget tree, and I-003 / I-025 suites stay closed', () {
    final admission = ConflictReplanAdmission();
    expect(admission.commandClampRequalified, isFalse);
    expect(admission.linkOffsetRequalified, isFalse);
    expect(admission.frozenS3SuiteRewritten, isFalse);
    expect(admission.trimPlannerInvented, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
    expect(admission.videoMutedSoloOpened, isFalse);
    expect(admission.osClipboardInvented, isFalse);
    expect(admission.autoCloseInvented, isFalse);
    expect(admission.planGraphInvented, isFalse);
    expect(admission.intentReducerInvented, isFalse);
    expect(admission.i003Requalified, isFalse);
    expect(admission.i025Requalified, isFalse);
  });
}
