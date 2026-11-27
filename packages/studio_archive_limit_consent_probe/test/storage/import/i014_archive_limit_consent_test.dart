import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_archive_limit_consent_probe/studio_archive_limit_consent_probe.dart';
import 'package:test/test.dart';

/// Increment 3.21 official I-014 / s5c leftover: raising an archive
/// size limit requires one-time explicit consent and must not
/// disable path, permission, or hash checks.
///
/// This file does not re-qualify `files_test` zip-slip, zip-bomb
/// `ARCHIVE_LIMIT`, or symlink refusal, Increment 3.16
/// FutureMajorAdmission, “不支持feature只读保留”, Increment 3.15
/// IdentityCollisionAdmission, Increment 2.51, or
/// fork-new-projectId. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9. I-014 stays partial. Existing
/// I-014 remainingAcceptance wording is not silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('raising an archive size limit requires one-time explicit consent and must not disable path, permission, or hash checks', () {
    final admission = ArchiveLimitConsentAdmission();
    final receipt = admission.admit(
      const ArchiveLimitConsentRequest(
        kind: 'raiseArchiveLimit',
        consentGiven: true,
      ),
    );
    expect(receipt.admitted, isTrue);
    expect(receipt.consentOnce, isTrue);
    expect(receipt.pathChecksEnabled, isTrue);
    expect(receipt.permissionChecksEnabled, isTrue);
    expect(receipt.hashChecksEnabled, isTrue);
    expect(
      () => admission.admit(const ArchiveLimitConsentRequest(kind: 'unknown')),
      code('ARCHIVE_LIMIT_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const ArchiveLimitConsentRequest(kind: 'raiseArchiveLimit'),
      ),
      code('ARCHIVE_LIMIT_CONSENT_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const ArchiveLimitConsentRequest(
          kind: 'raiseArchiveLimit',
          consentGiven: true,
          disablesPathChecks: true,
        ),
      ),
      code('ARCHIVE_PATH_CHECKS_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const ArchiveLimitConsentRequest(
          kind: 'raiseArchiveLimit',
          consentGiven: true,
          disablesPermissionChecks: true,
        ),
      ),
      code('ARCHIVE_PERMISSION_CHECKS_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const ArchiveLimitConsentRequest(
          kind: 'raiseArchiveLimit',
          consentGiven: true,
          disablesHashChecks: true,
        ),
      ),
      code('ARCHIVE_HASH_CHECKS_REQUIRED'),
    );
  });

  test('files_test zip bomb ARCHIVE_LIMIT, FutureMajorAdmission, and zip slip or symlink refusal stay closed', () {
    final admission = ArchiveLimitConsentAdmission();
    expect(admission.zipSlipRequalified, isFalse);
    expect(admission.zipBombRequalified, isFalse);
    expect(admission.symlinkRequalified, isFalse);
    expect(admission.futureMajorRequalified, isFalse);
    expect(admission.identityCollisionRequalified, isFalse);
    expect(admission.forkNewProjectIdRequalified, isFalse);
    expect(admission.archiveSpaceRequalified, isFalse);
    expect(admission.restoreInvented, isFalse);
    expect(admission.schemaMigratorInvented, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
    expect(admission.filesTestRewritten, isFalse);
  });
}
