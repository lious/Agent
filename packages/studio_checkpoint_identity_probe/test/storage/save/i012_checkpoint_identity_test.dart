import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_checkpoint_identity_probe/studio_checkpoint_identity_probe.dart';
import 'package:test/test.dart';

/// Increment 3.11 official I-012 / s5b leftover: a product recovery
/// checkpoint is not a SQLite WAL checkpoint and must not recopy
/// media. A lagging `checkpointRevision` does not mean those edits
/// are unsaved.
///
/// This file does not re-qualify ADR 0003 managed checkpoints,
/// Increment 3.07 CloseCheckpointAdmission, Increment 3.10
/// ExplicitSaveAdmission, ADR 0097 durableRevision, or ADR 0098.
/// SQLite WAL recovery remains as already recorded in ADR 0003. A
/// WAL-checkpoint runtime, an I-014 RestoreService, and a Flutter
/// widget tree are not invented. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. I-012 stays
/// partial. Existing I-012 remainingAcceptance wording is not
/// silently rewritten.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a product recovery checkpoint is admitted, is not a SQLite WAL checkpoint, and must not recopy media', () {
    final admission = CheckpointIdentityAdmission();
    final receipt = admission.admit(const CheckpointIdentityRequest());
    expect(receipt.admitted, isTrue);
    expect(receipt.isSqliteWalCheckpoint, isFalse);
    expect(receipt.mediaRecopied, isFalse);
    expect(receipt.lagMeansUnsaved, isFalse);
    expect(
      () => admission.admit(
        const CheckpointIdentityRequest(claimsSqliteWalCheckpoint: true),
      ),
      code('CHECKPOINT_IS_NOT_WAL'),
    );
    expect(
      () =>
          admission.admit(const CheckpointIdentityRequest(recopiesMedia: true)),
      code('CHECKPOINT_MEDIA_RECOPY_FORBIDDEN'),
    );
  });

  test('a lagging checkpointRevision does not mean edits are unsaved', () {
    final admission = CheckpointIdentityAdmission();
    final receipt = admission.admit(
      const CheckpointIdentityRequest(checkpointRevisionLagsHead: true),
    );
    expect(receipt.admitted, isTrue);
    expect(receipt.lagMeansUnsaved, isFalse);
    expect(
      () => admission.admit(
        const CheckpointIdentityRequest(
          checkpointRevisionLagsHead: true,
          claimsEditsUnsavedBecauseCheckpointLags: true,
        ),
      ),
      code('CHECKPOINT_LAG_NOT_UNSAVED'),
    );
  });

  test('ADR 0003, Increment 3.07 close-checkpoint, Increment 3.10 explicit-save, ADR 0097, and a WAL-checkpoint runtime stay closed', () {
    final admission = CheckpointIdentityAdmission();
    expect(admission.adr0003Requalified, isFalse);
    expect(admission.closeCheckpointRequalified, isFalse);
    expect(admission.explicitSaveRequalified, isFalse);
    expect(admission.packageAutoUpdateRequalified, isFalse);
    expect(admission.i011DurableRevisionRequalified, isFalse);
    expect(admission.i011CrashRequalified, isFalse);
    expect(admission.walCheckpointRuntimeInvented, isFalse);
    expect(admission.i014RestoreInvented, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
  });
}
