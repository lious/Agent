# ADR 0229 — Official s5d fixed-revision portable archives exclude future outputs, stay immutable after publish, must not cancel a paid job, and disclose pending jobs (I-013 leftover)

## Status

Accepted for Increment 3.30 as a distinct already-specified s5d 固定revision可移植归档 leftover on I-013: a fixed-revision portable archive must not include pending-job future outputs, must not be mutated when a later job completes, must not cancel a paid job on the user's behalf, must disclose pending jobs when they exist, and edits during the archive only affect a new revision. I-013 stays partial and is not marked complete. Existing I-013 remainingAcceptance wording (运行job归档 still unofficial, Increment 2.50 packMode, 取消无半包发布, 保留策略不删可达blob, Increment 3.06 ArtifactKindAdmission, Increment 3.18 PackageProjectionAdmission, Increment 3.20 ArchiveSpaceAdmission, Increment 3.24 SessionExportAdmission, Increment 3.25 PackageStagingAdmission, Increment 3.26 HistoryAvailabilityAdmission, Increment 3.27 LibraryArchiveAdmission, Increment 3.28 ArchiveCountdownAdmission, Increment 3.29 UnknownExtensionPinAdmission) is not silently rewritten or cleared. This does not invent I-013 job archival (运行job归档固定rev并报告pending stays unofficial). It does not re-qualify Increment 3.06 ArtifactKindAdmission: the “exportPackage与逻辑归档是两个独立按钮” sentence is not officialized here, and no Flutter widget tree is invented. It does not re-qualify Increment 3.04 JobCancelAdmission (canceling an export or cloud generation must not undo already-completed user edits). The unofficialized PENDING_MEDIA / RESOURCE_MISSING “do not mislabel a complete archive or final render” sentence is not taken, because that would re-qualify Increment 2.50. I-040 generated output, I-004 attach, and official I-024 export suites are not re-qualified. Quote/apply is not started. No paid API is called. Increment 3.29 UnknownExtensionPinAdmission, Increment 3.28 ArchiveCountdownAdmission, and Increment 3.27 LibraryArchiveAdmission are not re-qualified. An I-014 RestoreService, an ArchiveService / queue-drainer runtime, a WorkflowCoordinator, PatchGroup cherry-pick, workspace SQLite w5, and a ZipPlanner are not invented. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. Production FTS/RAG is not claimed. I-013, I-011, I-014, I-012, I-020, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification. I-014 “ID重映射” and “旧版本恢复新rev” are not taken. I-005 remainingAcceptance is not rewritten.

## Decision

s5d states that a portable archive is planned at a fixed revision and document hash; that archiving with pending jobs may proceed only with an explicit disclosure that the current version is archived, generation is unfinished, and the package does not contain future outputs; that later job completion must not change an already-published package and requires a new plan; that archiving must not cancel a paid job on the user's behalf; and that edits during the archive only affect a new revision. The “two independent buttons” sentence and job-archival packing of running jobs are not taken here.

This increment officializes only those fixed-revision publication bounds as a DEV-PURE compiler at the official entry path `packages/studio_fixed_revision_archive_probe/lib/fixed_revision_archive_admission.dart`:

- `portableArchive` is admitted (`futureOutputsIncluded=false`, `publishedPackageMutable=false`, `paidJobCancelled=false`). Pending jobs are admitted only when disclosed.
- An unknown kind is `FIXED_REVISION_ARCHIVE_KIND_UNKNOWN`.
- Including pending-job future outputs is `FUTURE_OUTPUT_NOT_INCLUDED`.
- Mutating a published package when a later job completes is `PUBLISHED_PACKAGE_IMMUTABLE`.
- Canceling a paid job as a side effect of archive is `ARCHIVE_PAID_JOB_CANCEL_FORBIDDEN`.
- Archiving with pending jobs and no disclosure is `PENDING_JOB_DISCLOSURE_REQUIRED`.
- Letting in-flight edits affect the archived revision is `ARCHIVE_EDIT_NEW_REVISION_ONLY`.
- `jobArchivalInvented`, `artifactKindRequalified`, `jobCancelRequalified`, `unknownExtensionPinRequalified`, `pendingMediaCompleteRequalified`, `generatedOutputRequalified`, `attachRequalified`, `quoteApplyStarted`, `paidApiCalled`, `flutterWidgetTreeInvented`, and `restoreInvented` stay false.

`tools/spikes/fixed_revision_archive/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing Increment 3.06, Increment 3.04, Increment 2.50, and I-005 suites are not rewritten.

## Consequences

The s5d fixed-revision portable-archive immutability, pending-job disclosure, and no-paid-job-cancel bounds are officialized at this admission. I-013 remainingAcceptance job-archival, packMode, cancel, retention, and Increments 3.06–3.29 wording stay listed, so I-013 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i013-fixed-revision-archive/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this fixed-revision archive admission, Increment 3.06 ArtifactKindAdmission, Increment 3.04 JobCancelAdmission, Increment 3.29 UnknownExtensionPinAdmission, or Increment 2.50 packMode. Do not invent I-013 job archival or officialize the rest of the s5d incremental-backup row. Do not take the PENDING_MEDIA complete-archive sentence. Do not take s5d “再分发/执行许可分开” if that would re-qualify `FONT_REDISTRIBUTION_FACT` or `MODELS_REFERENCED_NOT_DOWNLOADED`. Do not officialize the project-deletion recycle-bin path. The packing / session / omitted-history cluster remains exhausted of clean slices.
