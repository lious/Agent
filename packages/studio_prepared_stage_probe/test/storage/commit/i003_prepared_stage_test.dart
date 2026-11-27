import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_prepared_stage_probe/studio_prepared_stage_probe.dart';
import 'package:test/test.dart';

/// Increment 3.12 official I-003 / s5b leftover: the save prepared
/// stage must not hold a long SQLite write transaction.
///
/// This file does not re-qualify Increment 3.09 WriterFenceAdmission,
/// Increment 3.08 SqlCloudSideEffectAdmission, Increment 3.11
/// CheckpointIdentityAdmission, or I-003 revision tests. An OS lock
/// runtime, crash takeover, pending-publication reconciliation, and a
/// publish-path serial coordinator are not invented. The leftover
/// “different apps do not share a private workspace” / App Group
/// clause is not officialized here. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. I-003 stays
/// partial. Existing I-003 remainingAcceptance labels (100 concurrent
/// same-baseRevision, undo creates a new revision, no half-write,
/// namespace isolation) are not silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('the save prepared stage is admitted when it does not hold a long SQLite write transaction', () {
    final admission = PreparedStageAdmission();
    final receipt = admission.admit(
      const PreparedStageRequest(preparedStage: true),
    );
    expect(receipt.admitted, isTrue);
    expect(receipt.sqliteWriteHeldLong, isFalse);
    expect(
      () => admission.admit(const PreparedStageRequest()),
      code('PREPARED_STAGE_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const PreparedStageRequest(
          preparedStage: true,
          holdsLongSqliteWriteTransaction: true,
        ),
      ),
      code('PREPARED_STAGE_LONG_WRITE_FORBIDDEN'),
    );
  });

  test('Increment 3.09 writer-fence, Increment 3.08 SQL cloud-side-effect, I-003 revision tests, an OS lock runtime, crash takeover, and a serial coordinator stay closed', () {
    final admission = PreparedStageAdmission();
    expect(admission.writerFenceRequalified, isFalse);
    expect(admission.sqlCloudSideEffectRequalified, isFalse);
    expect(admission.checkpointIdentityRequalified, isFalse);
    expect(admission.i003RevisionTestsRewritten, isFalse);
    expect(admission.i011CrashRequalified, isFalse);
    expect(admission.osLockRuntimeInvented, isFalse);
    expect(admission.crashTakeoverOfficialized, isFalse);
    expect(admission.coordinatorInvented, isFalse);
    expect(admission.appGroupShareOfficialized, isFalse);
    expect(admission.i032PlanGraphFenceRequalified, isFalse);
  });
}
