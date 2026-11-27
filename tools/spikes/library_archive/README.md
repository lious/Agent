I-013 / s5d library-archive admission (Increment 3.27) lives in
`packages/studio_library_archive_probe` as `LibraryArchiveAdmission`.

A logical library archive is a list-state change. It must not bump
the project revision, delete CAS, undo or resubmit a cloud job, or
auto-attach a job to an archived document. An archived library
opens read-only. Restoring it to active still requires candidate
review.

This directory does not host an ArchiveService runtime, I-013 job
archival, or an I-014 RestoreService. Increment 3.06
ArtifactKindAdmission, Increment 3.26 HistoryAvailabilityAdmission,
and I-029 DeletionBarrier are not re-qualified. Schema v10 is not
merged. Project user_version stays 9. I-013 stays partial. Existing
I-013 remainingAcceptance wording is not cleared.
