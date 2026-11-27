# ADR 0227 — Official s5d archives must not start the project-deletion recycle-bin countdown (I-013 leftover)

## Status

Accepted for Increment 3.28 as a distinct already-specified s5d 保留策略 leftover on I-013: a library or portable archive must not start the project-deletion recycle-bin countdown. I-013 stays partial and is not marked complete. Existing I-013 remainingAcceptance wording (运行job归档 still unofficial, Increment 2.50 packMode, 取消无半包发布, 保留策略不删可达blob, Increment 3.06 ArtifactKindAdmission, Increment 3.18 PackageProjectionAdmission, Increment 3.20 ArchiveSpaceAdmission, Increment 3.24 SessionExportAdmission, Increment 3.25 PackageStagingAdmission, Increment 3.26 HistoryAvailabilityAdmission, Increment 3.27 LibraryArchiveAdmission) is not silently rewritten or cleared. This does not re-qualify I-029 DeletionBarrier (intent Declare/Supersede/Retract/purge, watermark/privacy-epoch rebuild, and related forgetting bounds). It does not re-qualify Increment 3.27 LibraryArchiveAdmission (list-state change, no revision bump, no CAS delete, read-only, no auto-attach, restore still needs review). It does not re-qualify Increment 3.06 ArtifactKindAdmission, ADR 0016 checkpoint-index retention, or the already-official “保留策略不删可达blob” bound. The same s5d row’s checkpoint-window, backup-interval, and 2GiB soft-budget design defaults are not re-stated here. The “删除项目另走明确回收站30天” sentence is not officialized here, because that would invent a recycle-bin runtime. The 30-day figure remains a design default and is not claimed as a measured timer or a system wake guarantee. I-013 job archival, an I-014 RestoreService, an ArchiveService / queue-drainer runtime, PatchGroup cherry-pick, workspace SQLite w5, a ZipPlanner, and a Flutter widget tree are not invented. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. Production FTS/RAG is not claimed. I-013, I-011, I-014, I-012, I-020, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification. I-014 “ID重映射” and “旧版本恢复新rev” are not taken. I-029 stays partial and is not marked complete.

## Decision

s5d states that deleting a project takes a separate explicit recycle-bin path, and that archiving must never start that countdown. Only the second sentence is officialized here, as a DEV-PURE compiler at the official entry path `packages/studio_archive_countdown_probe/lib/archive_countdown_admission.dart`:

- `libraryArchive` and `portableArchive` are admitted (`countdownStarted=false`).
- An unknown kind is `ARCHIVE_COUNTDOWN_KIND_UNKNOWN`.
- Starting a recycle-bin countdown from an archive is `ARCHIVE_COUNTDOWN_FORBIDDEN`.
- `deletionBarrierRequalified`, `libraryArchiveRequalified`, `artifactKindRequalified`, `checkpointRetentionRequalified`, `reachableBlobRetentionRequalified`, `recycleBinInvented`, `countdownTimerClaimed`, `jobArchivalInvented`, `restoreInvented`, and `archiveServiceInvented` stay false.

`tools/spikes/archive_countdown/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing I-029, Increment 3.27, Increment 3.06, and ADR 0016 suites are not rewritten.

## Consequences

The s5d “归档从不启动回收站倒计时” bound is officialized at this admission. I-013 remainingAcceptance job-archival, packMode, cancel, retention, artifact-kind, projection, archive-space, session-export, package-staging, history-availability, and library-archive wording stay listed, so I-013 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i013-archive-countdown/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this archive-countdown admission, I-029 DeletionBarrier, Increment 3.27 LibraryArchiveAdmission, Increment 3.06 ArtifactKindAdmission, or ADR 0016. Do not invent a recycle-bin runtime or claim the 30-day figure as a measured timer. Do not invent I-013 job archival or an ArchiveService runtime. Do not take I-014 “ID重映射” or “旧版本恢复新rev.” Do not take the same s5a row’s “选history才携带所引用历史快照” sentence or the RevisionMap “scope invalid / 所有旧审批失效” sentences. Do not take s5d “再分发/执行许可分开” if that would re-qualify `FONT_REDISTRIBUTION_FACT` or `MODELS_REFERENCED_NOT_DOWNLOADED`. Do not officialize the s5e missing-media / finished-export sentences that would re-qualify I-004, I-024, or Increment 3.06. The packing / session / omitted-history cluster remains exhausted of clean slices.
