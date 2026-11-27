I-013 / s5d archive-space admission (Increment 3.20) lives in
`packages/studio_archive_space_probe` as `ArchiveSpaceAdmission`.

Archive progress must name a real phase, must not invent a
percentage when total bytes are unknown, must not double-count
same-hash media in CAS accounting, and must not assume a
cross-volume rename.

This directory does not host a ZipPlanner / ZIP64 writer, a muxer,
job archival, a StoragePort runtime, or an I-014 RestoreService.
ENOSPC is not claimed. Increment 2.50 packMode, Increment 3.18
PackageProjectionAdmission, I-013 “cancel with no half-published
package,” I-004 same-hash single blob, and I-042
`LEASE_DOUBLE_COUNT` are not re-qualified. I-013 stays partial.
Existing I-013 remainingAcceptance wording is not cleared.
