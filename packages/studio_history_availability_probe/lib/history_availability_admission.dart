import 'package:studio_contracts/studio_contracts.dart';

const historyAvailabilityKinds = {'historyOmitted'};

final class HistoryAvailabilityRequest {
  const HistoryAvailabilityRequest({
    required this.kind,
    this.includesHistoricalSnapshots = false,
    this.retargetsOldRefsToCurrent = false,
    this.oldRefsMarkedUnavailable = true,
  });

  /// `historyOmitted`.
  final String kind;
  final bool includesHistoricalSnapshots;
  final bool retargetsOldRefsToCurrent;
  final bool oldRefsMarkedUnavailable;
}

final class HistoryAvailabilityReceipt {
  const HistoryAvailabilityReceipt({
    required this.admitted,
    required this.currentSnapshotOnly,
    required this.oldRefsUnavailable,
    required this.retargetedToCurrent,
  });

  final bool admitted;
  final bool currentSnapshotOnly;
  final bool oldRefsUnavailable;
  final bool retargetedToCurrent;
}

/// DEV-PURE I-013 / s5a admission: when history is not selected,
/// the package keeps only the current revision snapshot, and old
/// references are marked unavailable rather than retargeted at
/// the current content.
///
/// This does not re-qualify ADR 0018 ImportMap, “no imported
/// history,” no historical-revision / session / job-resume
/// binding, or fork-new-projectId. It does not invent a
/// history-selected packer, an I-014 RestoreService, or
/// PatchGroup cherry-pick. Increment 3.25 PackageStagingAdmission,
/// Increment 3.24 SessionExportAdmission, Increment 1.92 /
/// ADR 0099, and Increment 3.22 AuditJournalAdmission are not
/// re-qualified. The “package must not mix in a temporary
/// session database” and “import must not resume side effects”
/// sentences are not officialized here.
final class HistoryAvailabilityAdmission {
  bool importMapRequalified = false;
  bool historicalRevisionBindingRequalified = false;
  bool jobResumeRequalified = false;
  bool forkNewProjectIdRequalified = false;
  bool packageStagingRequalified = false;
  bool sessionExportRequalified = false;
  bool credentialsDeletedBodyRequalified = false;
  bool auditJournalRequalified = false;
  bool historyPackerInvented = false;
  bool restoreInvented = false;
  bool cherryPickInvented = false;
  bool productionFtsClaimed = false;

  HistoryAvailabilityReceipt admit(HistoryAvailabilityRequest request) {
    if (!historyAvailabilityKinds.contains(request.kind)) {
      throw const StudioException(
        'HISTORY_AVAILABILITY_KIND_UNKNOWN',
        'publication',
      );
    }
    if (request.includesHistoricalSnapshots) {
      throw const StudioException(
        'HISTORICAL_SNAPSHOT_NOT_INCLUDED',
        'publication',
      );
    }
    if (request.retargetsOldRefsToCurrent) {
      throw const StudioException('OLD_REF_NOT_CURRENT', 'publication');
    }
    if (!request.oldRefsMarkedUnavailable) {
      throw const StudioException('OLD_REF_NOT_UNAVAILABLE', 'publication');
    }
    return const HistoryAvailabilityReceipt(
      admitted: true,
      currentSnapshotOnly: true,
      oldRefsUnavailable: true,
      retargetedToCurrent: false,
    );
  }
}
