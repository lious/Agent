import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_license_provenance_probe/studio_license_provenance_probe.dart';
import 'package:test/test.dart';

/// Increment 3.35 official s1a leftover: quantize, LoRA, merge, or
/// rename must not wash away upstream license conditions; a model
/// name must not substitute for a file hash; and an operator role
/// must be issued by trusted configuration, not by a request that
/// self-selects a personal exemption.
///
/// This file does not re-qualify I-033, I-058,
/// FONT_REDISTRIBUTION_FACT, MODELS_REFERENCED_NOT_DOWNLOADED, or
/// Increment 3.32 LicenseExecutionAdmission. Quote/apply and paid
/// APIs are not started. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9. This is not an I-013 packing or
/// archive slice, not an I-002 measurement claim, and not a
/// license-execution leftover already officialized in 3.32.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('quantize, LoRA, merge, or rename must not wash upstream conditions; a model name is not a hash; a request must not self-select a personal exemption', () {
    final admission = LicenseProvenanceAdmission();
    final receipt = admission.admit(
      const LicenseProvenanceRequest(kind: 'licenseProvenance'),
    );
    expect(receipt.admitted, isTrue);
    expect(receipt.upstreamConditionsPreserved, isTrue);
    expect(receipt.modelNameUsedAsHash, isFalse);
    expect(receipt.roleIssuedByTrustedConfig, isTrue);
    expect(receipt.personalExemptionSelfSelected, isFalse);

    expect(
      () => admission.admit(const LicenseProvenanceRequest(kind: 'unknown')),
      code('LICENSE_PROVENANCE_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const LicenseProvenanceRequest(
          kind: 'licenseProvenance',
          washesUpstreamConditions: true,
        ),
      ),
      code('UPSTREAM_CONDITIONS_WASHED'),
    );
    expect(
      () => admission.admit(
        const LicenseProvenanceRequest(
          kind: 'licenseProvenance',
          modelNameSubstitutesHash: true,
        ),
      ),
      code('MODEL_NAME_NOT_HASH'),
    );
    expect(
      () => admission.admit(
        const LicenseProvenanceRequest(
          kind: 'licenseProvenance',
          roleIssuedByTrustedConfig: false,
        ),
      ),
      code('ROLE_NOT_TRUSTED_CONFIG'),
    );
    expect(
      () => admission.admit(
        const LicenseProvenanceRequest(
          kind: 'licenseProvenance',
          requestSelectsPersonalExemption: true,
        ),
      ),
      code('PERSONAL_EXEMPTION_SELF_SELECTED'),
    );
  });

  test('I-033, I-058, FONT_REDISTRIBUTION_FACT, MODELS_REFERENCED_NOT_DOWNLOADED, and license-execution stay closed', () {
    final admission = LicenseProvenanceAdmission();
    expect(admission.i033Requalified, isFalse);
    expect(admission.i058Requalified, isFalse);
    expect(admission.i053WarningExemptRequalified, isFalse);
    expect(admission.fontRedistributionRequalified, isFalse);
    expect(admission.modelsReferencedRequalified, isFalse);
    expect(admission.licenseExecutionRequalified, isFalse);
    expect(admission.quoteApplyStarted, isFalse);
    expect(admission.paidApiCalled, isFalse);
    expect(admission.allowWithWarningRestated, isFalse);
    expect(admission.jobArchivalInvented, isFalse);
    expect(admission.loraRuntimeInvented, isFalse);
    expect(admission.llmPathRequalified, isFalse);
    expect(admission.dropFrameRequalified, isFalse);
    expect(admission.errorClassRequalified, isFalse);
  });
}
