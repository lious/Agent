import 'package:studio_contracts/studio_contracts.dart';

const packageStagingKinds = {'packageBuild'};

final class PackageStagingRequest {
  const PackageStagingRequest({
    required this.kind,
    this.cleanStaging = true,
    this.reusesPreviousSessionDirectory = false,
    this.packsGenericCache = false,
    this.includesAnalysisEvidence = false,
    this.analysisExplicitlySelected = false,
    this.analysisPermissionGranted = false,
  });

  /// `packageBuild`.
  final String kind;
  final bool cleanStaging;
  final bool reusesPreviousSessionDirectory;
  final bool packsGenericCache;
  final bool includesAnalysisEvidence;
  final bool analysisExplicitlySelected;
  final bool analysisPermissionGranted;
}

final class PackageStagingReceipt {
  const PackageStagingReceipt({
    required this.admitted,
    required this.cleanStaging,
    required this.casualCachePacked,
    required this.analysisAuthorized,
  });

  final bool admitted;
  final bool cleanStaging;
  final bool casualCachePacked;
  final bool analysisAuthorized;
}

/// DEV-PURE I-013 / s5d admission: each package is built from
/// clean staging, must not reuse a previous session-containing
/// directory, must not casually pack a generic cache, and may
/// include analysis evidence only when the user explicitly
/// selects it as a production basis and permission is granted.
///
/// This does not re-qualify Increment 3.24 SessionExportAdmission,
/// Increment 1.92 / ADR 0099 default session exclusion, Increment
/// 3.22 AuditJournalAdmission, or ADR 0018 no job-resume binding.
/// The “package must not mix in a temporary session database” and
/// “import must not resume side effects” sentences are not
/// officialized here. Job archival, an I-014 RestoreService, and
/// production FTS/RAG are not invented or claimed.
final class PackageStagingAdmission {
  bool sessionExportRequalified = false;
  bool credentialsDeletedBodyRequalified = false;
  bool auditJournalRequalified = false;
  bool jobResumeRequalified = false;
  bool productionFtsClaimed = false;
  bool jobArchivalInvented = false;
  bool restoreInvented = false;
  bool cherryPickInvented = false;
  bool workspaceW5Merged = false;
  bool flutterWidgetTreeInvented = false;

  PackageStagingReceipt admit(PackageStagingRequest request) {
    if (!packageStagingKinds.contains(request.kind)) {
      throw const StudioException(
        'PACKAGE_STAGING_KIND_UNKNOWN',
        'publication',
      );
    }
    if (!request.cleanStaging) {
      throw const StudioException('CLEAN_STAGING_REQUIRED', 'publication');
    }
    if (request.reusesPreviousSessionDirectory) {
      throw const StudioException(
        'STALE_SESSION_DIRECTORY_FORBIDDEN',
        'publication',
      );
    }
    if (request.packsGenericCache) {
      throw const StudioException('CASUAL_CACHE_PACK_FORBIDDEN', 'publication');
    }
    if (request.includesAnalysisEvidence &&
        !(request.analysisExplicitlySelected &&
            request.analysisPermissionGranted)) {
      throw const StudioException(
        'ANALYSIS_EVIDENCE_CONSENT_REQUIRED',
        'publication',
      );
    }
    return PackageStagingReceipt(
      admitted: true,
      cleanStaging: true,
      casualCachePacked: false,
      analysisAuthorized: request.includesAnalysisEvidence,
    );
  }
}
