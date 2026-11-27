# ADR 0228 — Official s5d unknown-extension closures conservatively pin and must not claim a complete archive (I-013 leftover)

## Status

Accepted for Increment 3.29 as a distinct already-specified s5d 增量备份与GC leftover on I-013: when an unknown extension's references cannot be enumerated, those bytes must be pinned conservatively and the archive must not be claimed complete. I-013 stays partial and is not marked complete. Existing I-013 remainingAcceptance wording (运行job归档 still unofficial, Increment 2.50 packMode, 取消无半包发布, 保留策略不删可达blob, Increment 3.06 ArtifactKindAdmission, Increment 3.18 PackageProjectionAdmission, Increment 3.20 ArchiveSpaceAdmission, Increment 3.24 SessionExportAdmission, Increment 3.25 PackageStagingAdmission, Increment 3.26 HistoryAvailabilityAdmission, Increment 3.27 LibraryArchiveAdmission, Increment 3.28 ArchiveCountdownAdmission) is not silently rewritten or cleared. This does not re-qualify I-004 same-hash single blob, Increment 2.50 packMode / sourceCompleteness, ADR 0099 default session and command-journal exclusion, or I-029 DeletionBarrier. I-004 remainingAcceptance labels are not touched. I-029 task-status is not rewritten. The PENDING_MEDIA / RESOURCE_MISSING “do not mislabel a complete archive or final render” sentence was not officialized in Increment 3.18 and is not officialized here, because that would re-qualify Increment 2.50. This bound is only the unknown-extension case: refs cannot be walked, so a conservative pin is required and a complete-archive claim is refused. Incremental blob/chunk dedup, “不备份私有session DB/凭据,” privacy-immediate purge, the 7-day GC grace, and 4MiB chunking are not officialized here. A BackupStore runtime, I-013 job archival, an I-014 RestoreService, PatchGroup cherry-pick, workspace SQLite w5, a ZipPlanner, and a Flutter widget tree are not invented. Increment 3.28 ArchiveCountdownAdmission, Increment 3.27 LibraryArchiveAdmission, and Increment 3.06 ArtifactKindAdmission are not re-qualified. The project-deletion recycle-bin path and the 30-day figure are not officialized or claimed as a measured timer. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. Production FTS/RAG is not claimed. I-013, I-011, I-014, I-012, I-020, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification. I-014 “ID重映射” and “旧版本恢复新rev” are not taken.

## Decision

s5d states that when an unknown extension cannot enumerate its references, those bytes are conservatively pinned and a false-complete archive is refused. The rest of that incremental-backup row is not taken here.

This increment officializes only those unknown-extension pin and false-complete bounds as a DEV-PURE compiler at the official entry path `packages/studio_unknown_extension_pin_probe/lib/unknown_extension_pin_admission.dart`:

- `archiveClosure` is admitted. When an unknown extension is present and its references are not enumerable, admission requires a conservative pin and `completeArchiveClaimed=false`.
- An unknown kind is `UNKNOWN_EXTENSION_PIN_KIND_UNKNOWN`.
- Failing to pin conservatively in that case is `CONSERVATIVE_PIN_REQUIRED`.
- Claiming a complete archive in that case is `UNKNOWN_EXTENSION_FALSE_COMPLETE`.
- `sameHashRequalified`, `credentialsDeletedBodyRequalified`, `deletionBarrierRequalified`, `packModeRequalified`, `pendingMediaCompleteRequalified`, `archiveCountdownRequalified`, `libraryArchiveRequalified`, `artifactKindRequalified`, `backupStoreInvented`, `jobArchivalInvented`, and `productionFtsClaimed` stay false.

`tools/spikes/unknown_extension_pin/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing I-004, ADR 0099, I-029, Increment 2.50, and Increment 3.18 suites are not rewritten.

## Consequences

The s5d unknown-extension conservative-pin and false-complete-archive bounds are officialized at this admission. I-013 remainingAcceptance job-archival, packMode, cancel, retention, artifact-kind, projection, archive-space, session-export, package-staging, history-availability, library-archive, and archive-countdown wording stay listed, so I-013 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i013-unknown-extension-pin/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this unknown-extension pin admission, I-004 same-hash, ADR 0099, I-029 DeletionBarrier, Increment 2.50 packMode / sourceCompleteness, or the unofficialized PENDING_MEDIA complete-archive sentence. Do not invent a BackupStore runtime or officialize incremental blob dedup, private session-DB backup exclusion, or privacy-immediate purge. Do not re-qualify Increment 3.28 ArchiveCountdownAdmission, Increment 3.27 LibraryArchiveAdmission, or Increment 3.06 ArtifactKindAdmission. Do not invent I-013 job archival or an ArchiveService runtime. Do not take I-014 “ID重映射” or “旧版本恢复新rev.” Do not take the same s5a row’s “选history才携带所引用历史快照” sentence or the RevisionMap “scope invalid / 所有旧审批失效” sentences. Do not take s5d “再分发/执行许可分开” if that would re-qualify `FONT_REDISTRIBUTION_FACT` or `MODELS_REFERENCED_NOT_DOWNLOADED`. Do not officialize the project-deletion recycle-bin path. The packing / session / omitted-history cluster remains exhausted of clean slices.
