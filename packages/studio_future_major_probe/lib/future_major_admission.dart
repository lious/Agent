import 'package:studio_contracts/studio_contracts.dart';

final class FutureMajorRequest {
  const FutureMajorRequest({
    this.futureMajorSchema = false,
    this.limitedOuterScan = false,
    this.readOnlyMetadata = false,
    this.keepsOriginalPackage = false,
    this.interpretsAndExecutesUnknownCore = false,
  });

  /// The import is a future / unknown major schema.
  final bool futureMajorSchema;
  final bool limitedOuterScan;
  final bool readOnlyMetadata;
  final bool keepsOriginalPackage;
  final bool interpretsAndExecutesUnknownCore;
}

final class FutureMajorReceipt {
  const FutureMajorReceipt({
    required this.admitted,
    required this.readOnly,
    required this.executed,
    required this.originalPackageKept,
  });

  final bool admitted;
  final bool readOnly;
  final bool executed;
  final bool originalPackageKept;
}

/// DEV-PURE I-014 / s5d admission: a future major schema may be
/// scanned only at the recognizable outer layer; the unknown core is
/// read-only metadata, the original package is kept, and the core
/// must not be interpreted or executed.
///
/// This is not a re-qualification of the already-official I-014
/// “不支持feature只读保留” bound (unsupported feature in a known
/// schema). Increment 3.15 IdentityCollisionAdmission, Increment
/// 2.51 restore event-seq, and an I-014 RestoreService are not
/// re-qualified or invented. A schema migrator is not invented.
/// ID remapping is not officialized here.
final class FutureMajorAdmission {
  bool identityCollisionRequalified = false;
  bool unsupportedFeatureReadonlyRequalified = false;
  bool i014RestoreInvented = false;
  bool migrationCopyRequalified = false;
  bool restoreEventSeqRequalified = false;
  bool schemaMigratorInvented = false;
  bool flutterWidgetTreeInvented = false;
  bool idRemapOfficialized = false;
  bool casDbGapRequalified = false;

  FutureMajorReceipt admit(FutureMajorRequest request) {
    if (!request.futureMajorSchema) {
      throw const StudioException('FUTURE_MAJOR_REQUIRED', 'import');
    }
    if (request.interpretsAndExecutesUnknownCore) {
      throw const StudioException('FUTURE_MAJOR_MUST_NOT_EXECUTE', 'import');
    }
    if (!request.readOnlyMetadata) {
      throw const StudioException('FUTURE_MAJOR_READ_ONLY', 'import');
    }
    if (!request.keepsOriginalPackage) {
      throw const StudioException('FUTURE_MAJOR_ORIGINAL_REQUIRED', 'import');
    }
    if (!request.limitedOuterScan) {
      throw const StudioException('FUTURE_MAJOR_SCAN_BOUNDED', 'import');
    }
    return const FutureMajorReceipt(
      admitted: true,
      readOnly: true,
      executed: false,
      originalPackageKept: true,
    );
  }
}
