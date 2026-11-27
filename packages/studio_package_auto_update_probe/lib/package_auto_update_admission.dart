import 'package:studio_contracts/studio_contracts.dart';

const authorizedLocalPackageTarget = 'authorizedLocal';

const providerLikePackageTargets = {
  'providerNetwork',
  'osSyncHosted',
  'unknown',
};

const packageAutoUpdateTargets = {
  authorizedLocalPackageTarget,
  ...providerLikePackageTargets,
};

final class PackageAutoUpdateRequest {
  const PackageAutoUpdateRequest({
    required this.targetKind,
    this.externalPackageAuto = false,
    this.localSaveDisclosed = false,
    this.pendingExternalUpdateDisclosed = false,
    this.backgroundAutoOverwrite = false,
    this.recopiesCasOriginals = false,
    this.assumedFilePathMeansNoUpload = false,
  });

  /// `authorizedLocal`, `providerNetwork`, `osSyncHosted`, or `unknown`.
  final String targetKind;
  final bool externalPackageAuto;
  final bool localSaveDisclosed;
  final bool pendingExternalUpdateDisclosed;
  final bool backgroundAutoOverwrite;
  final bool recopiesCasOriginals;
  final bool assumedFilePathMeansNoUpload;
}

final class PackageAutoUpdateReceipt {
  const PackageAutoUpdateReceipt({
    required this.externalPackageAuto,
    required this.recopiedCasOriginals,
  });

  final bool externalPackageAuto;
  final bool recopiedCasOriginals;
}

/// DEV-PURE I-012 / s5b admission: package auto-update defaults to
/// off and must disclose that the project is auto-saved locally
/// while the external package is still pending. Provider, network,
/// or OS-sync-hosted targets must not background auto-overwrite,
/// and a path must not be assumed to be a plain file with no upload.
/// An authorized local auto-update must not re-copy CAS originals.
///
/// This is not a re-qualification of ADR 0098 I-012 userSavedRevision
/// leftovers, Increment 2.73 V-005 provider-restriction admission,
/// AtomicFilePublisher, or official I-024 export suites. A SAF or
/// iCloud adapter is not invented, and a finished V-005 provider
/// qualification is not claimed.
final class PackageAutoUpdateAdmission {
  bool i012UserSavedRevisionRequalified = false;
  bool v005ProviderRestrictionRequalified = false;
  bool safIcloudInvented = false;
  bool v005QualificationClaimed = false;
  bool atomicFileRewritten = false;
  bool jobCancelRequalified = false;
  bool flutterWidgetTreeInvented = false;
  bool i014RestoreInvented = false;
  bool i011CrashRequalified = false;

  PackageAutoUpdateReceipt admit(PackageAutoUpdateRequest request) {
    if (!packageAutoUpdateTargets.contains(request.targetKind)) {
      throw const StudioException('PACKAGE_TARGET_UNKNOWN', 'package');
    }
    if (request.assumedFilePathMeansNoUpload &&
        request.targetKind != authorizedLocalPackageTarget) {
      throw const StudioException('TARGET_NOT_PLAIN_FILE', 'package');
    }
    final autoRequested =
        request.externalPackageAuto || request.backgroundAutoOverwrite;
    if (autoRequested &&
        providerLikePackageTargets.contains(request.targetKind)) {
      throw const StudioException(
        'PROVIDER_AUTO_OVERWRITE_FORBIDDEN',
        'package',
      );
    }
    if (!request.externalPackageAuto &&
        !(request.localSaveDisclosed &&
            request.pendingExternalUpdateDisclosed)) {
      throw const StudioException(
        'PACKAGE_UPDATE_DISCLOSURE_REQUIRED',
        'package',
      );
    }
    if (request.externalPackageAuto && request.recopiesCasOriginals) {
      throw const StudioException('CAS_ORIGINAL_RECOPY_FORBIDDEN', 'package');
    }
    return PackageAutoUpdateReceipt(
      externalPackageAuto: request.externalPackageAuto,
      recopiedCasOriginals: false,
    );
  }
}
