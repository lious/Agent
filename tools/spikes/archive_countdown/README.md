I-013 / s5d archive-countdown admission (Increment 3.28) lives in
`packages/studio_archive_countdown_probe` as
`ArchiveCountdownAdmission`.

A library or portable archive must not start the project-deletion
recycle-bin countdown.

This directory does not host a recycle-bin runtime, a 30-day
timer, I-013 job archival, or an ArchiveService. I-029
DeletionBarrier, Increment 3.27 LibraryArchiveAdmission,
Increment 3.06 ArtifactKindAdmission, and ADR 0016 are not
re-qualified. The 30-day figure remains a design default and is
not claimed as a measured timer. The “删除项目另走明确回收站30天”
sentence is not officialized here. I-013 stays partial. Existing
I-013 remainingAcceptance wording is not cleared.
