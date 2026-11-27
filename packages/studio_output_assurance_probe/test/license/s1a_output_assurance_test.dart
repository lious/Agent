import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_output_assurance_probe/studio_output_assurance_probe.dart';
import 'package:test/test.dart';

void main() {
  const admission = OutputAssuranceAdmission();
  OutputAssuranceRequest request(int mask, {String kind = 'outputAssurance'}) =>
      OutputAssuranceRequest(
        kind: kind,
        exclusivity: mask & 1 == 0
            ? OutputAssurance.notGuaranteed
            : OutputAssurance.guaranteed,
        copyrightability: mask & 2 == 0
            ? OutputAssurance.notGuaranteed
            : OutputAssurance.guaranteed,
        nonInfringement: mask & 4 == 0
            ? OutputAssurance.notGuaranteed
            : OutputAssurance.guaranteed,
      );
  test('disclosure makes no exclusivity, copyrightability or non-infringement guarantee', () {
    expect(admission.admit(request(0)).text, '输出不保证独占、可版权或不侵权。');
  });
  for (var mask = 1; mask < 8; mask++) {
    test('reject guarantee combination $mask', () {
      final expected = mask & 1 != 0
          ? 'OUTPUT_EXCLUSIVITY_NOT_GUARANTEED'
          : mask & 2 != 0
          ? 'OUTPUT_COPYRIGHTABILITY_NOT_GUARANTEED'
          : 'OUTPUT_NONINFRINGEMENT_NOT_GUARANTEED';
      expect(
        () => admission.admit(request(mask)),
        throwsA(isA<StudioException>().having((e) => e.code, 'code', expected)),
      );
    });
  }
  test('unknown kind rejected before interpreting assurances', () {
    for (var mask = 0; mask < 8; mask++) {
      expect(
        () => admission.admit(request(mask, kind: 'unknown')),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'OUTPUT_ASSURANCE_KIND_UNKNOWN',
          ),
        ),
      );
    }
  });
}
