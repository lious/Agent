import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_identity_collision_probe/studio_identity_collision_probe.dart';
import 'package:test/test.dart';

/// Increment 3.15 official I-014 / s5d leftover: a same
/// projectId+revision+hash import is a duplicate and must not
/// overwrite the existing project. The same projectId and revision
/// with a different hash is `IDENTITY_COLLISION` and must not
/// overwrite.
///
/// This file does not invent an I-014 RestoreService or a Flutter
/// open-or-fork widget. Already-official I-014 conclusions (zip slip,
/// fork new projectId, migration keeps a good copy, unsupported
/// feature stays read-only) and Increment 2.51 restore event-seq are
/// not re-qualified. InversePatch kind stays restoreSnapshot. Project
/// user_version stays 9. I-014 stays partial. Existing I-014
/// remainingAcceptance wording is not silently rewritten.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a duplicate import is admitted without overwrite, and a same-id same-revision different-hash import is IDENTITY_COLLISION', () {
    final admission = IdentityCollisionAdmission();
    final fresh = admission.admit(const IdentityCollisionRequest());
    expect(fresh.admitted, isTrue);
    expect(fresh.duplicateImport, isFalse);
    expect(fresh.overwritten, isFalse);
    final duplicate = admission.admit(
      const IdentityCollisionRequest(
        sameProjectId: true,
        sameRevision: true,
        sameHash: true,
      ),
    );
    expect(duplicate.admitted, isTrue);
    expect(duplicate.duplicateImport, isTrue);
    expect(duplicate.overwritten, isFalse);
    expect(
      () => admission.admit(
        const IdentityCollisionRequest(
          sameProjectId: true,
          sameRevision: true,
          sameHash: true,
          overwriteExisting: true,
        ),
      ),
      code('DUPLICATE_IMPORT_NO_OVERWRITE'),
    );
    expect(
      () => admission.admit(
        const IdentityCollisionRequest(
          sameProjectId: true,
          sameRevision: true,
          overwriteExisting: true,
        ),
      ),
      code('IDENTITY_COLLISION'),
    );
  });

  test('Increment 2.51 restore event-seq, an I-014 RestoreService, fork-new-id, migration-copy, zip-slip, and a Flutter widget tree stay closed', () {
    final admission = IdentityCollisionAdmission();
    expect(admission.casDbGapRequalified, isFalse);
    expect(admission.i011CrashRequalified, isFalse);
    expect(admission.i014RestoreInvented, isFalse);
    expect(admission.forkNewIdRequalified, isFalse);
    expect(admission.migrationCopyRequalified, isFalse);
    expect(admission.unsupportedFeatureReadonlyRequalified, isFalse);
    expect(admission.restoreEventSeqRequalified, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
    expect(admission.zipSlipRequalified, isFalse);
  });
}
