import 'package:studio_contracts/studio_contracts.dart';

const archiveCountdownKinds = {'libraryArchive', 'portableArchive'};

final class ArchiveCountdownRequest {
  const ArchiveCountdownRequest({
    required this.kind,
    this.startsRecycleCountdown = false,
  });

  /// `libraryArchive` or `portableArchive`.
  final String kind;
  final bool startsRecycleCountdown;
}

final class ArchiveCountdownReceipt {
  const ArchiveCountdownReceipt({
    required this.admitted,
    required this.countdownStarted,
  });

  final bool admitted;
  final bool countdownStarted;
}

/// DEV-PURE I-013 / s5d admission: an archive must not start the
/// project-deletion recycle-bin countdown.
///
/// This does not re-qualify I-029 DeletionBarrier, Increment 3.27
/// LibraryArchiveAdmission, Increment 3.06 ArtifactKindAdmission,
/// ADR 0016 checkpoint-index retention, or the already-official
/// “保留策略不删可达blob” bound. It does not invent a recycle-bin
/// runtime or claim the 30-day design default as a measured timer.
/// The “删除项目另走明确回收站30天” sentence is not officialized
/// here. I-013 job archival and an ArchiveService runtime are not
/// invented.
final class ArchiveCountdownAdmission {
  bool deletionBarrierRequalified = false;
  bool libraryArchiveRequalified = false;
  bool artifactKindRequalified = false;
  bool checkpointRetentionRequalified = false;
  bool reachableBlobRetentionRequalified = false;
  bool recycleBinInvented = false;
  bool countdownTimerClaimed = false;
  bool jobArchivalInvented = false;
  bool restoreInvented = false;
  bool archiveServiceInvented = false;

  ArchiveCountdownReceipt admit(ArchiveCountdownRequest request) {
    if (!archiveCountdownKinds.contains(request.kind)) {
      throw const StudioException(
        'ARCHIVE_COUNTDOWN_KIND_UNKNOWN',
        'publication',
      );
    }
    if (request.startsRecycleCountdown) {
      throw const StudioException('ARCHIVE_COUNTDOWN_FORBIDDEN', 'publication');
    }
    return const ArchiveCountdownReceipt(
      admitted: true,
      countdownStarted: false,
    );
  }
}
