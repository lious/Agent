import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_downmix_probe/studio_downmix_probe.dart';
import 'package:test/test.dart';

/// Increment 2.93 official I-023 / s4 leftover: input-layout downmix
/// uses an explicit matrix. This file does not invent a channel-mixer
/// or limiter runtime, does not start I-007 PCM remapping, and does
/// not re-qualify I-009 mix, Increment 2.83 varispeed-and-pitch, or
/// Increment 2.85 recording-drift. It does not claim a 20ms A/V
/// achievement or a resolved underrun. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. I-023 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a downmix with an explicit finite matrix is admitted; pass-through does not require a matrix', () {
    final admission = DownmixAdmission();
    final receipt = admission.admit(
      const DownmixRequest(
        downmix: true,
        matrix: [
          [1, 0, 0.707, 0, 0.707, 0],
          [0, 1, 0.707, 0, 0, 0.707],
        ],
      ),
    );
    expect(receipt.explicitMatrix, isTrue);
    final passThrough = admission.admit(const DownmixRequest(downmix: false));
    expect(passThrough.explicitMatrix, isFalse);
  });

  test('an implicit or missing downmix matrix is refused; a malformed matrix is refused', () {
    final admission = DownmixAdmission();
    expect(
      () => admission.admit(
        const DownmixRequest(
          downmix: true,
          implicitDownmix: true,
          matrix: [
            [0.5, 0.5],
          ],
        ),
      ),
      code('DOWNMIX_MATRIX_REQUIRED'),
    );
    expect(
      () => admission.admit(const DownmixRequest(downmix: true)),
      code('DOWNMIX_MATRIX_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const DownmixRequest(
          downmix: true,
          matrix: [
            [1, 0],
            [0],
          ],
        ),
      ),
      code('DOWNMIX_MATRIX_INVALID'),
    );
    expect(
      () => admission.admit(
        const DownmixRequest(
          downmix: true,
          matrix: [
            [double.nan, 0],
          ],
        ),
      ),
      code('DOWNMIX_MATRIX_INVALID'),
    );
  });

  test('a mixer or limiter runtime, I-009 mix, I-007 PCM remap, and I-023 measurements stay closed', () {
    final admission = DownmixAdmission();
    expect(admission.mixerRuntimeInvented, isFalse);
    expect(admission.limiterInvented, isFalse);
    expect(admission.i007PcmRemapStarted, isFalse);
    expect(admission.i009Requalified, isFalse);
    expect(admission.varispeedRequalified, isFalse);
    expect(admission.driftRequalified, isFalse);
    expect(admission.timeStretchInvented, isFalse);
    expect(admission.av20msClaimed, isFalse);
    expect(admission.underrunResolved, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
