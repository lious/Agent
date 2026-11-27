import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_llm_path_probe/studio_llm_path_probe.dart';
import 'package:test/test.dart';

/// Increment 3.34 official s2 leftover: a document path must not
/// come from an LLM.
///
/// This file does not re-qualify Increment 3.33 DropFrameAdmission,
/// Increment 3.31 ErrorClassAdmission, Increment 3.32
/// LicenseExecutionAdmission, the remaining I-002 measurement
/// labels, or the already-official wall-clock clock ADRs.
/// InversePatch kind stays restoreSnapshot. Project user_version
/// stays 9. This is not an I-013 packing or archive slice, not a
/// drop-frame leftover from the same s2 paragraph, and not a
/// license-execution leftover.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a document path must not come from an LLM', () {
    final admission = LlmPathAdmission();
    final app = admission.admit(const LlmPathRequest(kind: 'documentPath'));
    expect(app.admitted, isTrue);
    expect(app.pathFromLlm, isFalse);

    final user = admission.admit(
      const LlmPathRequest(kind: 'documentPath', origin: 'user'),
    );
    expect(user.admitted, isTrue);
    expect(user.pathFromLlm, isFalse);

    expect(
      () => admission.admit(const LlmPathRequest(kind: 'unknown')),
      code('PATH_ORIGIN_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const LlmPathRequest(kind: 'documentPath', origin: 'llm'),
      ),
      code('PATH_FROM_LLM'),
    );
    expect(
      () => admission.admit(
        const LlmPathRequest(kind: 'documentPath', origin: 'unknown'),
      ),
      code('PATH_ORIGIN_KIND_UNKNOWN'),
    );
  });

  test('I-002 measurement labels, drop-frame, error-class, license-execution, and wall-clock ADRs stay closed', () {
    final admission = LlmPathAdmission();
    expect(admission.rationalOpsRequalified, isFalse);
    expect(admission.fkOverlapOverflowRequalified, isFalse);
    expect(admission.syntheticProjectRequalified, isFalse);
    expect(admission.errorClassRequalified, isFalse);
    expect(admission.dropFrameRequalified, isFalse);
    expect(admission.licenseExecutionRequalified, isFalse);
    expect(admission.wallClockRequalified, isFalse);
    expect(admission.closedRootExtended, isFalse);
    expect(admission.unknownFieldsSwallowed, isFalse);
    expect(admission.pathTrackerInvented, isFalse);
  });
}
