# ADR 0226 — Official s5d logical library archive is a list-state change: no revision bump, no CAS delete, read-only, and restore still needs review (I-013 leftover)

## Status

Accepted for Increment 3.27 as a distinct already-specified s5d leftover on I-013, outside the packing / session / omitted-history cluster: a logical library archive is a list-state change. It must not bump the project revision, delete CAS, undo or resubmit a cloud job, or auto-attach a job to an archived document. An archived library opens read-only. Restoring it to active still requires candidate review. I-013 stays partial and is not marked complete. Existing I-013 remainingAcceptance wording (运行job归档 still unofficial, Increment 2.50 packMode, 取消无半包发布, 保留策略不删可达blob, Increment 3.06 ArtifactKindAdmission, Increment 3.18 PackageProjectionAdmission, Increment 3.20 ArchiveSpaceAdmission, Increment 3.24 SessionExportAdmission, Increment 3.25 PackageStagingAdmission, Increment 3.26 HistoryAvailabilityAdmission) is not silently rewritten or cleared. Increment 3.06 ArtifactKindAdmission is not re-qualified: this slice does not restate that backup, logical archive, portable archive, finished export, and sync are different artifact kinds. Increment 3.26 HistoryAvailabilityAdmission, Increment 3.25 PackageStagingAdmission, Increment 3.24 SessionExportAdmission, Increment 1.92 / ADR 0099, Increment 3.22 AuditJournalAdmission, ADR 0018, and I-029 DeletionBarrier are not re-qualified. The s5e sentences that candidates are accepted by latest-revision diff, that missing media/font/effect or an unfinished placeholder blocks final render, and that a finished `.mp4` must not be confused with an editable package, are not officialized here. I-013 job archival, an I-014 RestoreService, an ArchiveService / queue-drainer runtime, PatchGroup cherry-pick, workspace SQLite w5, a ZipPlanner, and a Flutter widget tree are not invented. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. Production FTS/RAG is not claimed. I-013, I-011, I-014, I-012, I-020, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification. I-014 “ID重映射” and “旧版本恢复新rev” are not taken.

## Decision

s5d states that `setLibraryArchived` records `library_state=archived` as a list-state change: the project revision must not increase; the archived library opens read-only and may later be restored to active; CAS is not deleted; cloud jobs are not undone or resubmitted; existing jobs may still record candidates or bills but must not auto-attach to an archived document; and restoring to active still requires candidate review. The matching s5e “移入归档库” sentences that the project becomes read-only/hidden, originals are not deleted, running jobs are not stopped, and restore does not auto-accept candidates, are the same bound. Queue draining, CAS expectedHead fetches, and UI hiding are not implemented here.

This increment officializes only those list-state bounds as a DEV-PURE compiler at the official entry path `packages/studio_library_archive_probe/lib/library_archive_admission.dart`:

- `libraryArchive` is admitted (`readOnly=true`, `projectRevisionBumped=false`, `casDeleted=false`, `jobsMutated=false`).
- `libraryRestore` is admitted (`readOnly=false`, `projectRevisionBumped=false`, `candidateReviewRequired=true`).
- An unknown kind is `LIBRARY_ARCHIVE_KIND_UNKNOWN`.
- Bumping the project revision is `LIBRARY_ARCHIVE_NOT_REVISION`.
- Deleting CAS is `LIBRARY_ARCHIVE_CAS_DELETE_FORBIDDEN`.
- Undoing or resubmitting a cloud job is `LIBRARY_ARCHIVE_JOB_MUTATION_FORBIDDEN`.
- Opening an archived library as writable is `ARCHIVED_LIBRARY_NOT_WRITABLE`.
- Auto-attaching a job to an archived document is `AUTO_ATTACH_ARCHIVED_FORBIDDEN`.
- Restoring to active and accepting candidates without review is `CANDIDATE_REVIEW_REQUIRED`.
- `artifactKindRequalified`, `historyAvailabilityRequalified`, `packageStagingRequalified`, `sessionExportRequalified`, `deletionBarrierRequalified`, `jobArchivalInvented`, `restoreInvented`, `archiveServiceInvented`, `flutterWidgetTreeInvented`, `schemaMigratorInvented`, and `quoteApplyStarted` stay false.

`tools/spikes/library_archive/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing Increment 3.06 and I-029 suites are not rewritten.

## Consequences

The s5d logical-library-archive list-state bounds are officialized at this admission. I-013 remainingAcceptance job-archival, packMode, cancel, retention, artifact-kind, projection, archive-space, session-export, package-staging, and history-availability wording stay listed, so I-013 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i013-library-archive/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this library-archive admission, Increment 3.06 ArtifactKindAdmission, Increment 3.26 HistoryAvailabilityAdmission, Increment 3.25 PackageStagingAdmission, Increment 3.24 SessionExportAdmission, or I-029 DeletionBarrier. Do not invent I-013 job archival, an I-014 RestoreService, or an ArchiveService runtime. Do not take I-014 “ID重映射” or “旧版本恢复新rev.” Do not take the same s5a row’s “选history才携带所引用历史快照” sentence or the RevisionMap “scope invalid / 所有旧审批失效” sentences. Do not take s5d “再分发/执行许可分开” if that would re-qualify `FONT_REDISTRIBUTION_FACT` or `MODELS_REFERENCED_NOT_DOWNLOADED`. Do not officialize the s5e missing-media / finished-export sentences that would re-qualify I-004, I-024, or Increment 3.06. s5d 保留策略 “归档从不启动回收站倒计时” may be considered only if it can be bounded without re-qualifying I-029 DeletionBarrier.
