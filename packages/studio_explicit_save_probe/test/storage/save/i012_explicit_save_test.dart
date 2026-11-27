import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_explicit_save_probe/studio_explicit_save_probe.dart';
import 'package:test/test.dart';

/// Increment 3.10 official I-012 / s5b leftover: library-mode
/// `saveManaged` writes a checkpoint and an explicit save receipt and
/// must not imply a `.studioproj` was written. `saveBoundPackage`
/// requires an external binding and may claim success only after a
/// StoragePort receipt.
///
/// This file does not re-qualify Increment 3.07
/// CloseCheckpointAdmission, Increment 3.05 PackageAutoUpdateAdmission,
/// Increment 3.06 ArtifactKindAdmission, or ADR 0098 I-012 leftovers.
/// A Flutter widget tree, a SAF or iCloud adapter, a StoragePort
/// runtime, and an I-014 RestoreService are not invented. InversePatch
/// kind stays restoreSnapshot. Project user_version stays 9. I-012
/// stays partial. Existing I-012 remainingAcceptance wording is not
/// silently rewritten.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('saveManaged is admitted with a checkpoint and an explicit receipt and does not imply a .studioproj', () {
    final admission = ExplicitSaveAdmission();
    final receipt = admission.admit(
      const ExplicitSaveRequest(
        mode: 'saveManaged',
        checkpointWritten: true,
        explicitSaveReceiptWritten: true,
        claimsLibrarySaved: true,
      ),
    );
    expect(receipt.admitted, isTrue);
    expect(receipt.librarySaved, isTrue);
    expect(receipt.externalFileWritten, isFalse);
    expect(receipt.boundSuccess, isFalse);
    expect(
      () => admission.admit(
        const ExplicitSaveRequest(
          mode: 'saveManaged',
          claimsLibrarySaved: true,
        ),
      ),
      code('EXPLICIT_SAVE_RECEIPT_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const ExplicitSaveRequest(
          mode: 'saveManaged',
          checkpointWritten: true,
          explicitSaveReceiptWritten: true,
          claimsExternalFileWritten: true,
        ),
      ),
      code('UNBOUND_STUDIOPROJ_NOT_IMPLIED'),
    );
    expect(
      () => admission.admit(const ExplicitSaveRequest(mode: 'unknown')),
      code('EXPLICIT_SAVE_MODE_UNKNOWN'),
    );
  });

  test('saveBoundPackage requires an external binding and may claim success only after a StoragePort receipt', () {
    final admission = ExplicitSaveAdmission();
    final pending = admission.admit(
      const ExplicitSaveRequest(
        mode: 'saveBoundPackage',
        boundToExternalFile: true,
      ),
    );
    expect(pending.admitted, isTrue);
    expect(pending.externalFileWritten, isFalse);
    expect(pending.boundSuccess, isFalse);
    final done = admission.admit(
      const ExplicitSaveRequest(
        mode: 'saveBoundPackage',
        boundToExternalFile: true,
        storagePortReceipt: true,
        claimsBoundSuccess: true,
        claimsExternalFileWritten: true,
      ),
    );
    expect(done.admitted, isTrue);
    expect(done.externalFileWritten, isTrue);
    expect(done.boundSuccess, isTrue);
    expect(
      () => admission.admit(
        const ExplicitSaveRequest(
          mode: 'saveBoundPackage',
          claimsBoundSuccess: true,
        ),
      ),
      code('EXTERNAL_BINDING_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const ExplicitSaveRequest(
          mode: 'saveBoundPackage',
          boundToExternalFile: true,
          claimsBoundSuccess: true,
        ),
      ),
      code('STORAGE_PORT_RECEIPT_REQUIRED'),
    );
  });

  test('Increment 3.07 close-checkpoint, Increment 3.05 package auto-update, Increment 3.06 artifact-kind, ADR 0098, a Flutter widget tree, and a SAF/iCloud adapter stay closed', () {
    final admission = ExplicitSaveAdmission();
    expect(admission.closeCheckpointRequalified, isFalse);
    expect(admission.packageAutoUpdateRequalified, isFalse);
    expect(admission.artifactKindRequalified, isFalse);
    expect(admission.i012UserSavedRevisionRequalified, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
    expect(admission.safIcloudInvented, isFalse);
    expect(admission.storagePortRuntimeInvented, isFalse);
    expect(admission.i014RestoreInvented, isFalse);
    expect(admission.v005QualificationClaimed, isFalse);
    expect(admission.writerFenceRequalified, isFalse);
  });
}
