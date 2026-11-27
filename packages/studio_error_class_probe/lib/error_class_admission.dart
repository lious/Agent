import 'package:studio_contracts/studio_contracts.dart';

const errorClassKinds = {'errorReport'};
const errorClasses = {'structural', 'business'};

final class ErrorClassRequest {
  const ErrorClassRequest({
    required this.kind,
    required this.actualClass,
    required this.reportedClass,
  });

  /// `errorReport`.
  final String kind;

  /// `structural` or `business`.
  final String actualClass;

  /// `structural` or `business`.
  final String reportedClass;
}

final class ErrorClassReceipt {
  const ErrorClassReceipt({required this.admitted, required this.errorClass});

  final bool admitted;
  final String errorClass;
}

/// DEV-PURE I-002 admission: structural errors and business errors
/// must be reported as separate classes. A structural failure must
/// not be reported as a business error, and a business failure must
/// not be reported as a structural error.
///
/// This does not claim the remaining I-002 labels (10k rational
/// roundtrips, illegal FK/overlap/overflow refusal, existing
/// synthetic projects). Schema v10 is not merged. Project
/// user_version stays 9. The closed root is not extended with new
/// fields. Unknown fields are not swallowed. I-013 packing and
/// archive admissions are not re-qualified.
final class ErrorClassAdmission {
  bool rationalOpsRequalified = false;
  bool fkOverlapOverflowRequalified = false;
  bool syntheticProjectRequalified = false;
  bool schemaMigratorInvented = false;
  bool userVersionChanged = false;
  bool closedRootFieldsAdded = false;
  bool unknownFieldsSwallowed = false;
  bool packingAdmissionRequalified = false;

  ErrorClassReceipt admit(ErrorClassRequest request) {
    if (!errorClassKinds.contains(request.kind)) {
      throw const StudioException('ERROR_CLASS_KIND_UNKNOWN', 'validator');
    }
    if (!errorClasses.contains(request.actualClass) ||
        !errorClasses.contains(request.reportedClass)) {
      throw const StudioException('ERROR_CLASS_UNKNOWN', 'validator');
    }
    if (request.actualClass != request.reportedClass) {
      throw const StudioException('ERROR_CLASS_MISMATCH', 'validator');
    }
    return ErrorClassReceipt(admitted: true, errorClass: request.actualClass);
  }
}
