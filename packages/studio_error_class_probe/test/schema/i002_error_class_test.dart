import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_error_class_probe/studio_error_class_probe.dart';
import 'package:test/test.dart';

/// Increment 3.31 official I-002 leftover: structural errors and
/// business errors must be reported as separate classes.
///
/// This file does not claim 10k rational roundtrips, illegal
/// FK/overlap/overflow refusal, or existing synthetic-project
/// passage. Schema v10 is not merged. Project user_version stays
/// 9. InversePatch kind stays restoreSnapshot. I-002 stays
/// partial. Existing I-002 remainingAcceptance wording is not
/// silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test(
    'structural and business errors must be reported as separate classes',
    () {
      final admission = ErrorClassAdmission();
      final structural = admission.admit(
        const ErrorClassRequest(
          kind: 'errorReport',
          actualClass: 'structural',
          reportedClass: 'structural',
        ),
      );
      expect(structural.admitted, isTrue);
      expect(structural.errorClass, 'structural');

      final business = admission.admit(
        const ErrorClassRequest(
          kind: 'errorReport',
          actualClass: 'business',
          reportedClass: 'business',
        ),
      );
      expect(business.admitted, isTrue);
      expect(business.errorClass, 'business');

      expect(
        () => admission.admit(
          const ErrorClassRequest(
            kind: 'unknown',
            actualClass: 'structural',
            reportedClass: 'structural',
          ),
        ),
        code('ERROR_CLASS_KIND_UNKNOWN'),
      );
      expect(
        () => admission.admit(
          const ErrorClassRequest(
            kind: 'errorReport',
            actualClass: 'unknown',
            reportedClass: 'structural',
          ),
        ),
        code('ERROR_CLASS_UNKNOWN'),
      );
      expect(
        () => admission.admit(
          const ErrorClassRequest(
            kind: 'errorReport',
            actualClass: 'structural',
            reportedClass: 'business',
          ),
        ),
        code('ERROR_CLASS_MISMATCH'),
      );
      expect(
        () => admission.admit(
          const ErrorClassRequest(
            kind: 'errorReport',
            actualClass: 'business',
            reportedClass: 'structural',
          ),
        ),
        code('ERROR_CLASS_MISMATCH'),
      );
    },
  );

  test('I-002 rational-roundtrip, FK/overlap/overflow, and synthetic-project labels stay unclaimed', () {
    final admission = ErrorClassAdmission();
    expect(admission.rationalOpsRequalified, isFalse);
    expect(admission.fkOverlapOverflowRequalified, isFalse);
    expect(admission.syntheticProjectRequalified, isFalse);
    expect(admission.schemaMigratorInvented, isFalse);
    expect(admission.userVersionChanged, isFalse);
    expect(admission.closedRootFieldsAdded, isFalse);
    expect(admission.unknownFieldsSwallowed, isFalse);
    expect(admission.packingAdmissionRequalified, isFalse);
  });
}
