import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_save_as_named_version_probe/studio_save_as_named_version_probe.dart';
import 'package:test/test.dart';

/// Increment 3.19 official I-012 / s5b leftover: Save As must not
/// silently overwrite an existing file, and a named version is a
/// label pin of an immutable checkpoint, not a fork or a rollback.
///
/// This file does not re-qualify `CHECKPOINT_NAME_EXISTS`,
/// fork-new-projectId, Increment 3.10 ExplicitSaveAdmission, or
/// Increment 3.11 CheckpointIdentityAdmission. The “new project
/// copy defaults to a new projectId” and “keep the id and
/// explicitly switch binding” clauses are not officialized here.
/// InversePatch kind stays restoreSnapshot. Project user_version
/// stays 9. I-012 stays partial. Existing I-012 remainingAcceptance
/// wording is not silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('Save As must not silently overwrite an existing file, and a named version is a label pin not a fork or rollback', () {
    final admission = SaveAsNamedVersionAdmission();
    final saveAs = admission.admit(
      const SaveAsNamedVersionRequest(kind: 'saveAs'),
    );
    expect(saveAs.admitted, isTrue);
    expect(saveAs.silentOverwrite, isFalse);
    expect(saveAs.isLabelPin, isFalse);
    expect(saveAs.isFork, isFalse);
    expect(saveAs.isRollback, isFalse);

    final confirmed = admission.admit(
      const SaveAsNamedVersionRequest(
        kind: 'saveAs',
        existingTarget: true,
        overwriteConfirmed: true,
      ),
    );
    expect(confirmed.admitted, isTrue);
    expect(confirmed.silentOverwrite, isFalse);

    expect(
      () => admission.admit(
        const SaveAsNamedVersionRequest(kind: 'saveAs', existingTarget: true),
      ),
      code('SILENT_OVERWRITE_FORBIDDEN'),
    );
    expect(
      () => admission.admit(const SaveAsNamedVersionRequest(kind: 'unknown')),
      code('SAVE_AS_KIND_UNKNOWN'),
    );

    final named = admission.admit(
      const SaveAsNamedVersionRequest(kind: 'namedVersion'),
    );
    expect(named.admitted, isTrue);
    expect(named.isLabelPin, isTrue);
    expect(named.isFork, isFalse);
    expect(named.isRollback, isFalse);
    expect(
      () => admission.admit(
        const SaveAsNamedVersionRequest(kind: 'namedVersion', claimsFork: true),
      ),
      code('NAMED_VERSION_NOT_FORK'),
    );
    expect(
      () => admission.admit(
        const SaveAsNamedVersionRequest(
          kind: 'namedVersion',
          claimsRollback: true,
        ),
      ),
      code('NAMED_VERSION_NOT_ROLLBACK'),
    );
  });

  test('CHECKPOINT_NAME_EXISTS, fork-new-projectId, ExplicitSaveAdmission, and CheckpointIdentityAdmission stay closed', () {
    final admission = SaveAsNamedVersionAdmission();
    expect(admission.checkpointNameExistsRequalified, isFalse);
    expect(admission.forkNewProjectIdRequalified, isFalse);
    expect(admission.explicitSaveRequalified, isFalse);
    expect(admission.checkpointIdentityRequalified, isFalse);
    expect(admission.uniqueCopyRequalified, isFalse);
    expect(admission.packageProjectionRequalified, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
    expect(admission.storagePortInvented, isFalse);
    expect(admission.restoreInvented, isFalse);
    expect(admission.walCheckpointInvented, isFalse);
  });
}
