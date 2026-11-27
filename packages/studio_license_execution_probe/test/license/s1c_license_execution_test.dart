import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_license_execution_probe/studio_license_execution_probe.dart';
import 'package:test/test.dart';

/// Increment 3.32 official s1c leftover: a license gap must not
/// auto-switch models, an HTTP 403 must not be relabeled as a
/// license warning and retried, and a license-fact-only change
/// must not cancel a running job, drop candidates, or trigger a
/// paid retry.
///
/// This file does not re-qualify I-033, I-058,
/// FONT_REDISTRIBUTION_FACT, or
/// MODELS_REFERENCED_NOT_DOWNLOADED. Quote/apply and paid APIs
/// are not started. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9. This is not an I-013 packing
/// or archive slice and not an I-002 measurement claim.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a license gap must not auto-switch models, relabel HTTP 403 as a warning, or let a fact-only change cancel jobs or trigger a paid retry', () {
    final admission = LicenseExecutionAdmission();
    final receipt = admission.admit(
      const LicenseExecutionRequest(kind: 'licenseExecution'),
    );
    expect(receipt.admitted, isTrue);
    expect(receipt.autoSwitchedModel, isFalse);
    expect(receipt.http403Relabeled, isFalse);
    expect(receipt.jobCancelled, isFalse);
    expect(receipt.candidatesDropped, isFalse);
    expect(receipt.paidRetryTriggered, isFalse);

    expect(
      () => admission.admit(const LicenseExecutionRequest(kind: 'unknown')),
      code('LICENSE_EXECUTION_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const LicenseExecutionRequest(
          kind: 'licenseExecution',
          autoSwitchesModel: true,
        ),
      ),
      code('LICENSE_GAP_NO_AUTO_SWITCH'),
    );
    expect(
      () => admission.admit(
        const LicenseExecutionRequest(
          kind: 'licenseExecution',
          relabelsHttp403AsLicenseWarning: true,
        ),
      ),
      code('HTTP_403_NOT_LICENSE_WARNING'),
    );
    expect(
      () => admission.admit(
        const LicenseExecutionRequest(
          kind: 'licenseExecution',
          licenseFactChangeCancelsRunningJob: true,
        ),
      ),
      code('LICENSE_FACT_NO_JOB_CANCEL'),
    );
    expect(
      () => admission.admit(
        const LicenseExecutionRequest(
          kind: 'licenseExecution',
          licenseFactChangeDropsCandidates: true,
        ),
      ),
      code('LICENSE_FACT_NO_DROP_CANDIDATE'),
    );
    expect(
      () => admission.admit(
        const LicenseExecutionRequest(
          kind: 'licenseExecution',
          licenseFactChangeTriggersPaidRetry: true,
        ),
      ),
      code('LICENSE_FACT_NO_PAID_RETRY'),
    );
  });

  test('I-033, I-058, FONT_REDISTRIBUTION_FACT, MODELS_REFERENCED_NOT_DOWNLOADED, and paid APIs stay closed', () {
    final admission = LicenseExecutionAdmission();
    expect(admission.i033Requalified, isFalse);
    expect(admission.i058Requalified, isFalse);
    expect(admission.i053WarningExemptRequalified, isFalse);
    expect(admission.fontRedistributionRequalified, isFalse);
    expect(admission.modelsReferencedRequalified, isFalse);
    expect(admission.quoteApplyStarted, isFalse);
    expect(admission.paidApiCalled, isFalse);
    expect(admission.jobArchivalInvented, isFalse);
    expect(admission.fixedRevisionArchiveRequalified, isFalse);
    expect(admission.errorClassRequalified, isFalse);
  });
}
