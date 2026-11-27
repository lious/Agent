import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_drop_frame_probe/studio_drop_frame_probe.dart';
import 'package:test/test.dart';

/// Increment 3.33 official s2 leftover: drop-frame timecode only
/// changes display numbering and must not delete media frames.
///
/// This file does not re-qualify Increment 3.31 ErrorClassAdmission,
/// the remaining I-002 measurement labels, Increment 3.32
/// LicenseExecutionAdmission, or I-010 sidecar timecode work.
/// InversePatch kind stays restoreSnapshot. Project user_version
/// stays 9. This is not an I-013 packing or archive slice and not a
/// license-execution leftover.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('drop-frame timecode only changes display numbering and must not delete media frames', () {
    final admission = DropFrameAdmission();
    final receipt = admission.admit(
      const DropFrameRequest(kind: 'dropFrameDisplay'),
    );
    expect(receipt.admitted, isTrue);
    expect(receipt.displayNumberingOnly, isTrue);
    expect(receipt.mediaFramesDeleted, isFalse);

    expect(
      () => admission.admit(const DropFrameRequest(kind: 'unknown')),
      code('DROP_FRAME_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const DropFrameRequest(
          kind: 'dropFrameDisplay',
          deletesMediaFrames: true,
        ),
      ),
      code('DROP_FRAME_DELETES_MEDIA'),
    );
  });

  test('I-002 measurement labels, error-class admission, license-execution, and I-010 sidecar stay closed', () {
    final admission = DropFrameAdmission();
    expect(admission.rationalOpsRequalified, isFalse);
    expect(admission.fkOverlapOverflowRequalified, isFalse);
    expect(admission.syntheticProjectRequalified, isFalse);
    expect(admission.errorClassRequalified, isFalse);
    expect(admission.licenseExecutionRequalified, isFalse);
    expect(admission.captionTimecodeRequalified, isFalse);
    expect(admission.closedRootExtended, isFalse);
    expect(admission.unknownFieldsSwallowed, isFalse);
    expect(admission.dropFrameRuntimeInvented, isFalse);
    expect(admission.shaperInvented, isFalse);
  });
}
