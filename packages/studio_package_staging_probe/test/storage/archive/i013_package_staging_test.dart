import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_package_staging_probe/studio_package_staging_probe.dart';
import 'package:test/test.dart';

/// Increment 3.25 official I-013 / s5d leftover: each package is
/// built from clean staging, must not reuse a previous
/// session-containing directory, must not casually pack a generic
/// cache, and may include analysis evidence only when the user
/// explicitly selects it as a production basis and permission is
/// granted.
///
/// This file does not re-qualify Increment 3.24
/// SessionExportAdmission, Increment 1.92 / ADR 0099, Increment
/// 3.22 AuditJournalAdmission, or ADR 0018 no job-resume binding.
/// Job archival and an I-014 RestoreService are not invented.
/// InversePatch kind stays restoreSnapshot. Project user_version
/// stays 9. I-013 stays partial. Existing I-013 remainingAcceptance
/// wording is not silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a package must be built from clean staging, must not reuse a session directory or pack a generic cache, and analysis evidence needs consent', () {
    final admission = PackageStagingAdmission();
    final clean = admission.admit(
      const PackageStagingRequest(kind: 'packageBuild'),
    );
    expect(clean.admitted, isTrue);
    expect(clean.cleanStaging, isTrue);
    expect(clean.casualCachePacked, isFalse);
    expect(clean.analysisAuthorized, isFalse);

    final authorized = admission.admit(
      const PackageStagingRequest(
        kind: 'packageBuild',
        includesAnalysisEvidence: true,
        analysisExplicitlySelected: true,
        analysisPermissionGranted: true,
      ),
    );
    expect(authorized.admitted, isTrue);
    expect(authorized.analysisAuthorized, isTrue);

    expect(
      () => admission.admit(const PackageStagingRequest(kind: 'unknown')),
      code('PACKAGE_STAGING_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const PackageStagingRequest(kind: 'packageBuild', cleanStaging: false),
      ),
      code('CLEAN_STAGING_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const PackageStagingRequest(
          kind: 'packageBuild',
          reusesPreviousSessionDirectory: true,
        ),
      ),
      code('STALE_SESSION_DIRECTORY_FORBIDDEN'),
    );
    expect(
      () => admission.admit(
        const PackageStagingRequest(
          kind: 'packageBuild',
          packsGenericCache: true,
        ),
      ),
      code('CASUAL_CACHE_PACK_FORBIDDEN'),
    );
    expect(
      () => admission.admit(
        const PackageStagingRequest(
          kind: 'packageBuild',
          includesAnalysisEvidence: true,
        ),
      ),
      code('ANALYSIS_EVIDENCE_CONSENT_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const PackageStagingRequest(
          kind: 'packageBuild',
          includesAnalysisEvidence: true,
          analysisExplicitlySelected: true,
        ),
      ),
      code('ANALYSIS_EVIDENCE_CONSENT_REQUIRED'),
    );
  });

  test('Increment 3.24 SessionExportAdmission, ADR 0099, AuditJournalAdmission, and job archival stay closed', () {
    final admission = PackageStagingAdmission();
    expect(admission.sessionExportRequalified, isFalse);
    expect(admission.credentialsDeletedBodyRequalified, isFalse);
    expect(admission.auditJournalRequalified, isFalse);
    expect(admission.jobResumeRequalified, isFalse);
    expect(admission.productionFtsClaimed, isFalse);
    expect(admission.jobArchivalInvented, isFalse);
    expect(admission.restoreInvented, isFalse);
    expect(admission.cherryPickInvented, isFalse);
    expect(admission.workspaceW5Merged, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
  });
}
