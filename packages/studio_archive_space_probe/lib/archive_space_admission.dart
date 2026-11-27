import 'package:studio_contracts/studio_contracts.dart';

const archiveProgressPhases = {'scan', 'collect', 'write', 'verify', 'publish'};

final class ArchiveSpaceRequest {
  const ArchiveSpaceRequest({
    required this.phase,
    this.totalBytesKnown = true,
    this.reportsPercent = false,
    this.doubleCountsSameHashCas = false,
    this.assumesCrossVolumeRename = false,
  });

  /// `scan`, `collect`, `write`, `verify`, or `publish`.
  final String phase;
  final bool totalBytesKnown;
  final bool reportsPercent;
  final bool doubleCountsSameHashCas;
  final bool assumesCrossVolumeRename;
}

final class ArchiveSpaceReceipt {
  const ArchiveSpaceReceipt({
    required this.admitted,
    required this.inventsPercent,
    required this.sameHashCountedOnce,
    required this.crossVolumeRenameAssumed,
  });

  final bool admitted;
  final bool inventsPercent;
  final bool sameHashCountedOnce;
  final bool crossVolumeRenameAssumed;
}

/// DEV-PURE I-013 / s5d admission: archive progress must name a
/// real phase, must not invent a percentage when total bytes are
/// unknown, must not double-count same-hash media in CAS
/// accounting, and must not assume a cross-volume rename.
///
/// This is planner accounting, not I-004 “same hash is a single
/// blob,” not I-042 `LEASE_DOUBLE_COUNT`, and not V-002
/// `INCREMENTAL_SHARED_DOUBLE_COUNT`. This does not re-qualify
/// Increment 2.50 packMode, Increment 3.06 ArtifactKindAdmission,
/// Increment 3.18 PackageProjectionAdmission, or I-013 “cancel
/// with no half-published package.” ENOSPC is not claimed. A
/// ZipPlanner / ZIP64 writer, a muxer, job archival, a
/// StoragePort runtime, and an I-014 RestoreService are not
/// invented. The “unknown target space, warn and write a new
/// file conservatively” and “cancel before publish does not
/// replace the target” clauses of the same s5d row are not
/// officialized here.
final class ArchiveSpaceAdmission {
  bool packModeRequalified = false;
  bool artifactKindRequalified = false;
  bool packageProjectionRequalified = false;
  bool cancelHalfPackageRequalified = false;
  bool uniqueCopyRequalified = false;
  bool i004SameHashRequalified = false;
  bool leaseDoubleCountRequalified = false;
  bool enospcClaimed = false;
  bool zipPlannerInvented = false;
  bool muxerInvented = false;
  bool jobArchivalInvented = false;
  bool storagePortInvented = false;
  bool restoreInvented = false;
  bool saveAsRequalified = false;

  ArchiveSpaceReceipt admit(ArchiveSpaceRequest request) {
    if (!archiveProgressPhases.contains(request.phase)) {
      throw const StudioException(
        'ARCHIVE_PROGRESS_KIND_UNKNOWN',
        'publication',
      );
    }
    if (!request.totalBytesKnown && request.reportsPercent) {
      throw const StudioException(
        'UNKNOWN_BYTES_PERCENT_FORBIDDEN',
        'publication',
      );
    }
    if (request.doubleCountsSameHashCas) {
      throw const StudioException(
        'CAS_HASH_DOUBLE_COUNT_FORBIDDEN',
        'publication',
      );
    }
    if (request.assumesCrossVolumeRename) {
      throw const StudioException(
        'CROSS_VOLUME_RENAME_NOT_ASSUMED',
        'publication',
      );
    }
    return const ArchiveSpaceReceipt(
      admitted: true,
      inventsPercent: false,
      sameHashCountedOnce: true,
      crossVolumeRenameAssumed: false,
    );
  }
}
