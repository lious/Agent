import 'package:studio_contracts/studio_contracts.dart';

final class IdentityCollisionRequest {
  const IdentityCollisionRequest({
    this.sameProjectId = false,
    this.sameRevision = false,
    this.sameHash = false,
    this.overwriteExisting = false,
  });

  final bool sameProjectId;
  final bool sameRevision;
  final bool sameHash;
  final bool overwriteExisting;
}

final class IdentityCollisionReceipt {
  const IdentityCollisionReceipt({
    required this.admitted,
    required this.duplicateImport,
    required this.overwritten,
  });

  final bool admitted;
  final bool duplicateImport;
  final bool overwritten;
}

/// DEV-PURE I-014 / s5d admission: a same projectId+revision+hash
/// import is a duplicate and must not overwrite the existing project.
/// The same projectId and revision with a different hash is
/// `IDENTITY_COLLISION` and must not overwrite.
///
/// This does not invent an I-014 RestoreService or a Flutter
/// open-or-fork widget. Already-official I-014 conclusions (zip slip,
/// fork new projectId, migration keeps a good copy, unsupported
/// feature stays read-only) and Increment 2.51 restore event-seq are
/// not re-qualified. Future-major read-only is not officialized here.
final class IdentityCollisionAdmission {
  bool casDbGapRequalified = false;
  bool i011CrashRequalified = false;
  bool i014RestoreInvented = false;
  bool forkNewIdRequalified = false;
  bool migrationCopyRequalified = false;
  bool unsupportedFeatureReadonlyRequalified = false;
  bool restoreEventSeqRequalified = false;
  bool flutterWidgetTreeInvented = false;
  bool zipSlipRequalified = false;

  IdentityCollisionReceipt admit(IdentityCollisionRequest request) {
    final sameIdentity = request.sameProjectId && request.sameRevision;
    if (sameIdentity && !request.sameHash) {
      throw const StudioException('IDENTITY_COLLISION', 'import');
    }
    if (sameIdentity && request.sameHash && request.overwriteExisting) {
      throw const StudioException('DUPLICATE_IMPORT_NO_OVERWRITE', 'import');
    }
    return IdentityCollisionReceipt(
      admitted: true,
      duplicateImport: sameIdentity && request.sameHash,
      overwritten: false,
    );
  }
}
