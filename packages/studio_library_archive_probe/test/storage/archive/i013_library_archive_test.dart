import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_library_archive_probe/studio_library_archive_probe.dart';
import 'package:test/test.dart';

/// Increment 3.27 official I-013 / s5d leftover: a logical library
/// archive is a list-state change and must not bump the project
/// revision, delete CAS, or mutate cloud jobs. An archived library
/// opens read-only. Jobs must not auto-attach to an archived
/// document. Restoring to active still requires candidate review.
///
/// This file does not re-qualify Increment 3.06
/// ArtifactKindAdmission, Increment 3.26
/// HistoryAvailabilityAdmission, or I-029 DeletionBarrier. I-013
/// job archival and an I-014 RestoreService are not invented.
/// InversePatch kind stays restoreSnapshot. Project user_version
/// stays 9. I-013 stays partial. Existing I-013 remainingAcceptance
/// wording is not silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a library archive is a list-state change: no revision bump, no CAS delete, read-only, and restore still needs review', () {
    final admission = LibraryArchiveAdmission();
    final archived = admission.admit(
      const LibraryArchiveRequest(kind: 'libraryArchive'),
    );
    expect(archived.admitted, isTrue);
    expect(archived.readOnly, isTrue);
    expect(archived.projectRevisionBumped, isFalse);
    expect(archived.casDeleted, isFalse);
    expect(archived.jobsMutated, isFalse);
    expect(archived.candidateReviewRequired, isFalse);

    final restored = admission.admit(
      const LibraryArchiveRequest(kind: 'libraryRestore', opensWritable: true),
    );
    expect(restored.admitted, isTrue);
    expect(restored.readOnly, isFalse);
    expect(restored.projectRevisionBumped, isFalse);
    expect(restored.candidateReviewRequired, isTrue);

    expect(
      () => admission.admit(const LibraryArchiveRequest(kind: 'unknown')),
      code('LIBRARY_ARCHIVE_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const LibraryArchiveRequest(
          kind: 'libraryArchive',
          bumpsProjectRevision: true,
        ),
      ),
      code('LIBRARY_ARCHIVE_NOT_REVISION'),
    );
    expect(
      () => admission.admit(
        const LibraryArchiveRequest(kind: 'libraryArchive', deletesCas: true),
      ),
      code('LIBRARY_ARCHIVE_CAS_DELETE_FORBIDDEN'),
    );
    expect(
      () => admission.admit(
        const LibraryArchiveRequest(
          kind: 'libraryArchive',
          mutatesCloudJobs: true,
        ),
      ),
      code('LIBRARY_ARCHIVE_JOB_MUTATION_FORBIDDEN'),
    );
    expect(
      () => admission.admit(
        const LibraryArchiveRequest(
          kind: 'libraryArchive',
          opensWritable: true,
        ),
      ),
      code('ARCHIVED_LIBRARY_NOT_WRITABLE'),
    );
    expect(
      () => admission.admit(
        const LibraryArchiveRequest(
          kind: 'libraryArchive',
          autoAttachesToArchived: true,
        ),
      ),
      code('AUTO_ATTACH_ARCHIVED_FORBIDDEN'),
    );
    expect(
      () => admission.admit(
        const LibraryArchiveRequest(
          kind: 'libraryRestore',
          acceptsCandidatesWithoutReview: true,
        ),
      ),
      code('CANDIDATE_REVIEW_REQUIRED'),
    );
  });

  test('Increment 3.06 ArtifactKindAdmission, Increment 3.26, I-029, and job archival stay closed', () {
    final admission = LibraryArchiveAdmission();
    expect(admission.artifactKindRequalified, isFalse);
    expect(admission.historyAvailabilityRequalified, isFalse);
    expect(admission.packageStagingRequalified, isFalse);
    expect(admission.sessionExportRequalified, isFalse);
    expect(admission.deletionBarrierRequalified, isFalse);
    expect(admission.jobArchivalInvented, isFalse);
    expect(admission.restoreInvented, isFalse);
    expect(admission.archiveServiceInvented, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
    expect(admission.schemaMigratorInvented, isFalse);
    expect(admission.quoteApplyStarted, isFalse);
  });
}
