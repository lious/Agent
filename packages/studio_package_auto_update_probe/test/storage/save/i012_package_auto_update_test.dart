import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_package_auto_update_probe/studio_package_auto_update_probe.dart';
import 'package:test/test.dart';

/// Increment 3.05 official I-012 / s5b leftover: package auto-update
/// defaults to off and must disclose that the project is auto-saved
/// locally while the external package is still pending. Provider,
/// network, or OS-sync-hosted targets must not background
/// auto-overwrite, and a path must not be assumed to be a plain file
/// with no upload. An authorized local auto-update must not re-copy
/// CAS originals.
///
/// This file does not re-qualify ADR 0098 I-012 userSavedRevision
/// leftovers, Increment 2.73 V-005 provider-restriction admission,
/// AtomicFilePublisher, or official I-024 export suites. A SAF or
/// iCloud adapter is not invented, and a finished V-005 provider
/// qualification is not claimed. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. I-012 stays
/// partial. Existing I-012 remainingAcceptance wording is not
/// silently rewritten.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('the default off auto-update is admitted when local save and pending external update are disclosed; an authorized local auto-update must not re-copy CAS originals', () {
    final admission = PackageAutoUpdateAdmission();
    final off = admission.admit(
      const PackageAutoUpdateRequest(
        targetKind: authorizedLocalPackageTarget,
        localSaveDisclosed: true,
        pendingExternalUpdateDisclosed: true,
      ),
    );
    expect(off.externalPackageAuto, isFalse);
    expect(off.recopiedCasOriginals, isFalse);
    final localAuto = admission.admit(
      const PackageAutoUpdateRequest(
        targetKind: authorizedLocalPackageTarget,
        externalPackageAuto: true,
      ),
    );
    expect(localAuto.externalPackageAuto, isTrue);
    expect(localAuto.recopiedCasOriginals, isFalse);
    expect(
      () => admission.admit(
        const PackageAutoUpdateRequest(
          targetKind: authorizedLocalPackageTarget,
          externalPackageAuto: true,
          recopiesCasOriginals: true,
        ),
      ),
      code('CAS_ORIGINAL_RECOPY_FORBIDDEN'),
    );
  });

  test('a provider or OS-sync target must not auto-overwrite; a non-local path must not be treated as a plain file; a missing default disclosure is refused', () {
    final admission = PackageAutoUpdateAdmission();
    expect(
      () => admission.admit(
        const PackageAutoUpdateRequest(
          targetKind: 'providerNetwork',
          externalPackageAuto: true,
        ),
      ),
      code('PROVIDER_AUTO_OVERWRITE_FORBIDDEN'),
    );
    expect(
      () => admission.admit(
        const PackageAutoUpdateRequest(
          targetKind: 'osSyncHosted',
          assumedFilePathMeansNoUpload: true,
          localSaveDisclosed: true,
          pendingExternalUpdateDisclosed: true,
        ),
      ),
      code('TARGET_NOT_PLAIN_FILE'),
    );
    expect(
      () => admission.admit(
        const PackageAutoUpdateRequest(
          targetKind: authorizedLocalPackageTarget,
        ),
      ),
      code('PACKAGE_UPDATE_DISCLOSURE_REQUIRED'),
    );
  });

  test('ADR 0098 I-012 leftovers, Increment 2.73 provider restriction, a SAF/iCloud adapter, and a V-005 qualification claim stay closed', () {
    final admission = PackageAutoUpdateAdmission();
    expect(admission.i012UserSavedRevisionRequalified, isFalse);
    expect(admission.v005ProviderRestrictionRequalified, isFalse);
    expect(admission.safIcloudInvented, isFalse);
    expect(admission.v005QualificationClaimed, isFalse);
    expect(admission.atomicFileRewritten, isFalse);
    expect(admission.jobCancelRequalified, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
    expect(admission.i014RestoreInvented, isFalse);
    expect(admission.i011CrashRequalified, isFalse);
  });
}
