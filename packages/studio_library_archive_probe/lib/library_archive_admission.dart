import 'package:studio_contracts/studio_contracts.dart';

const libraryArchiveKinds = {'libraryArchive', 'libraryRestore'};

final class LibraryArchiveRequest {
  const LibraryArchiveRequest({
    required this.kind,
    this.bumpsProjectRevision = false,
    this.deletesCas = false,
    this.mutatesCloudJobs = false,
    this.opensWritable = false,
    this.autoAttachesToArchived = false,
    this.acceptsCandidatesWithoutReview = false,
  });

  /// `libraryArchive` or `libraryRestore`.
  final String kind;
  final bool bumpsProjectRevision;
  final bool deletesCas;
  final bool mutatesCloudJobs;
  final bool opensWritable;
  final bool autoAttachesToArchived;
  final bool acceptsCandidatesWithoutReview;
}

final class LibraryArchiveReceipt {
  const LibraryArchiveReceipt({
    required this.admitted,
    required this.readOnly,
    required this.projectRevisionBumped,
    required this.casDeleted,
    required this.jobsMutated,
    required this.candidateReviewRequired,
  });

  final bool admitted;
  final bool readOnly;
  final bool projectRevisionBumped;
  final bool casDeleted;
  final bool jobsMutated;
  final bool candidateReviewRequired;
}

/// DEV-PURE I-013 / s5d admission: a logical library archive is a
/// list-state change. It must not bump the project revision, delete
/// CAS, undo or resubmit a cloud job, or auto-attach a job to an
/// archived document. An archived library opens read-only. Restoring
/// it to active still requires candidate review.
///
/// This does not re-qualify Increment 3.06 ArtifactKindAdmission,
/// Increment 3.26 HistoryAvailabilityAdmission, Increment 3.25
/// PackageStagingAdmission, Increment 3.24 SessionExportAdmission,
/// or I-029 DeletionBarrier. It does not invent I-013 job archival,
/// an I-014 RestoreService, an ArchiveService runtime, or a
/// Flutter widget tree. Schema v10 is not merged. Project
/// user_version stays 9.
final class LibraryArchiveAdmission {
  bool artifactKindRequalified = false;
  bool historyAvailabilityRequalified = false;
  bool packageStagingRequalified = false;
  bool sessionExportRequalified = false;
  bool deletionBarrierRequalified = false;
  bool jobArchivalInvented = false;
  bool restoreInvented = false;
  bool archiveServiceInvented = false;
  bool flutterWidgetTreeInvented = false;
  bool schemaMigratorInvented = false;
  bool quoteApplyStarted = false;

  LibraryArchiveReceipt admit(LibraryArchiveRequest request) {
    if (!libraryArchiveKinds.contains(request.kind)) {
      throw const StudioException(
        'LIBRARY_ARCHIVE_KIND_UNKNOWN',
        'publication',
      );
    }
    if (request.bumpsProjectRevision) {
      throw const StudioException(
        'LIBRARY_ARCHIVE_NOT_REVISION',
        'publication',
      );
    }
    if (request.deletesCas) {
      throw const StudioException(
        'LIBRARY_ARCHIVE_CAS_DELETE_FORBIDDEN',
        'publication',
      );
    }
    if (request.mutatesCloudJobs) {
      throw const StudioException(
        'LIBRARY_ARCHIVE_JOB_MUTATION_FORBIDDEN',
        'publication',
      );
    }
    if (request.kind == 'libraryArchive' && request.opensWritable) {
      throw const StudioException(
        'ARCHIVED_LIBRARY_NOT_WRITABLE',
        'publication',
      );
    }
    if (request.autoAttachesToArchived) {
      throw const StudioException(
        'AUTO_ATTACH_ARCHIVED_FORBIDDEN',
        'publication',
      );
    }
    if (request.kind == 'libraryRestore' &&
        request.acceptsCandidatesWithoutReview) {
      throw const StudioException('CANDIDATE_REVIEW_REQUIRED', 'publication');
    }
    return LibraryArchiveReceipt(
      admitted: true,
      readOnly: request.kind == 'libraryArchive',
      projectRevisionBumped: false,
      casDeleted: false,
      jobsMutated: false,
      candidateReviewRequired: request.kind == 'libraryRestore',
    );
  }
}
