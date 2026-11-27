import 'package:studio_contracts/studio_contracts.dart';

const archiveLimitConsentKinds = {'raiseArchiveLimit'};

final class ArchiveLimitConsentRequest {
  const ArchiveLimitConsentRequest({
    required this.kind,
    this.consentGiven = false,
    this.disablesPathChecks = false,
    this.disablesPermissionChecks = false,
    this.disablesHashChecks = false,
  });

  /// `raiseArchiveLimit`.
  final String kind;
  final bool consentGiven;
  final bool disablesPathChecks;
  final bool disablesPermissionChecks;
  final bool disablesHashChecks;
}

final class ArchiveLimitConsentReceipt {
  const ArchiveLimitConsentReceipt({
    required this.admitted,
    required this.consentOnce,
    required this.pathChecksEnabled,
    required this.permissionChecksEnabled,
    required this.hashChecksEnabled,
  });

  final bool admitted;
  final bool consentOnce;
  final bool pathChecksEnabled;
  final bool permissionChecksEnabled;
  final bool hashChecksEnabled;
}

/// DEV-PURE I-014 / s5c admission: raising an archive size limit
/// requires one-time explicit consent and must not disable path,
/// permission, or hash checks.
///
/// This does not re-qualify `files_test` zip-slip, zip-bomb
/// `ARCHIVE_LIMIT`, or symlink refusal, Increment 3.16
/// FutureMajorAdmission, “不支持feature只读保留”, Increment 3.15
/// IdentityCollisionAdmission, Increment 2.51, or fork-new-projectId.
/// The same s5c row’s “future or unknown objects stay read-only or
/// keep the original package” and “dangerous paths are isolated”
/// sentences are not officialized here. A schema migrator, an
/// I-014 RestoreService, and a Flutter widget tree are not
/// invented. Default `ProjectArchive` limits are not changed.
final class ArchiveLimitConsentAdmission {
  bool zipSlipRequalified = false;
  bool zipBombRequalified = false;
  bool symlinkRequalified = false;
  bool futureMajorRequalified = false;
  bool identityCollisionRequalified = false;
  bool forkNewProjectIdRequalified = false;
  bool archiveSpaceRequalified = false;
  bool restoreInvented = false;
  bool schemaMigratorInvented = false;
  bool flutterWidgetTreeInvented = false;
  bool filesTestRewritten = false;

  ArchiveLimitConsentReceipt admit(ArchiveLimitConsentRequest request) {
    if (!archiveLimitConsentKinds.contains(request.kind)) {
      throw const StudioException('ARCHIVE_LIMIT_KIND_UNKNOWN', 'publication');
    }
    if (!request.consentGiven) {
      throw const StudioException(
        'ARCHIVE_LIMIT_CONSENT_REQUIRED',
        'publication',
      );
    }
    if (request.disablesPathChecks) {
      throw const StudioException(
        'ARCHIVE_PATH_CHECKS_REQUIRED',
        'publication',
      );
    }
    if (request.disablesPermissionChecks) {
      throw const StudioException(
        'ARCHIVE_PERMISSION_CHECKS_REQUIRED',
        'publication',
      );
    }
    if (request.disablesHashChecks) {
      throw const StudioException(
        'ARCHIVE_HASH_CHECKS_REQUIRED',
        'publication',
      );
    }
    return const ArchiveLimitConsentReceipt(
      admitted: true,
      consentOnce: true,
      pathChecksEnabled: true,
      permissionChecksEnabled: true,
      hashChecksEnabled: true,
    );
  }
}
