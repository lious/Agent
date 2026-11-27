import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_rotation_once_probe/studio_rotation_once_probe.dart';
import 'package:test/test.dart';

/// Increment 2.89 official s4 leftover: source orientation is applied
/// once. This file does not invent an HDR or LUT runtime, does not
/// claim V-006 numeric or appearance qualification, does not start
/// I-059, and does not rewrite ColorPipelineAdmission or Increment
/// 2.88 ProxySourceSeekAdmission. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. V-006 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('display-matrix orientation is applied once; applying it again to already-rotated pixels is refused', () {
    final admission = RotationOnceAdmission();
    final once = admission.admit(
      const RotationOnceRequest(
        applyDisplayMatrix: true,
        applyBakedPixelRotation: false,
      ),
    );
    expect(once.containerRotationAppliedOnce, isTrue);
    expect(
      () => admission.admit(
        const RotationOnceRequest(
          applyDisplayMatrix: true,
          applyBakedPixelRotation: true,
        ),
      ),
      code('ROTATION_APPLIED_TWICE'),
    );
  });

  test('a user transform2d rotation is not a second container orientation; upright pixels with no display-matrix apply are admitted', () {
    final admission = RotationOnceAdmission();
    final upright = admission.admit(
      const RotationOnceRequest(
        applyDisplayMatrix: false,
        applyBakedPixelRotation: false,
        userTransformRotationDeg: 15,
      ),
    );
    expect(upright.containerRotationAppliedOnce, isFalse);
    expect(upright.userTransformRotationDeg, 15);
    final bakedOnly = admission.admit(
      const RotationOnceRequest(
        applyDisplayMatrix: false,
        applyBakedPixelRotation: true,
      ),
    );
    expect(bakedOnly.containerRotationAppliedOnce, isTrue);
  });

  test('an HDR/LUT runtime, V-006 numeric or appearance qualification, and I-059 stay closed', () {
    final admission = RotationOnceAdmission();
    expect(admission.hdrRuntimeInvented, isFalse);
    expect(admission.lutRuntimeInvented, isFalse);
    expect(admission.v006NumericClaimed, isFalse);
    expect(admission.v006AppearanceClaimed, isFalse);
    expect(admission.colorPipelineRequalified, isFalse);
    expect(admission.i059Started, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
