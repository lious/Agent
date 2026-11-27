import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_icc_first_probe/studio_icc_first_probe.dart';
import 'package:test/test.dart';

/// Increment 2.91 official s4 leftover: image ICC is applied first.
/// This file does not invent an ICC, HDR, or LUT runtime, does not
/// claim V-006 numeric or appearance qualification, does not start
/// I-059, and does not rewrite ColorPipelineAdmission,
/// RotationOnceAdmission, or RenderRecipeAdmission. InversePatch
/// kind stays restoreSnapshot. Project user_version stays 9. V-006
/// stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('an image with an ICC profile applies ICC first, before working-space color operations', () {
    final admission = IccFirstAdmission();
    final receipt = admission.admit(
      const IccFirstRequest(iccProfilePresent: true, iccApplied: true),
    );
    expect(receipt.iccAppliedFirst, isTrue);
    expect(
      () => admission.admit(
        const IccFirstRequest(
          iccProfilePresent: true,
          iccApplied: true,
          colorOpsBeforeIcc: true,
        ),
      ),
      code('ICC_MUST_BE_FIRST'),
    );
  });

  test('a present ICC profile cannot be skipped; an untagged image does not require an ICC transform', () {
    final admission = IccFirstAdmission();
    expect(
      () => admission.admit(
        const IccFirstRequest(iccProfilePresent: true, iccApplied: false),
      ),
      code('ICC_TRANSFORM_SKIPPED'),
    );
    final untagged = admission.admit(
      const IccFirstRequest(iccProfilePresent: false, iccApplied: false),
    );
    expect(untagged.iccAppliedFirst, isFalse);
  });

  test('an ICC/HDR/LUT runtime, V-006 numeric or appearance qualification, and I-059 stay closed', () {
    final admission = IccFirstAdmission();
    expect(admission.iccRuntimeInvented, isFalse);
    expect(admission.hdrRuntimeInvented, isFalse);
    expect(admission.lutRuntimeInvented, isFalse);
    expect(admission.v006NumericClaimed, isFalse);
    expect(admission.v006AppearanceClaimed, isFalse);
    expect(admission.colorPipelineRequalified, isFalse);
    expect(admission.rotationOnceRequalified, isFalse);
    expect(admission.renderRecipeRequalified, isFalse);
    expect(admission.i059Started, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
