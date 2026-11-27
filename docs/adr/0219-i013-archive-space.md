# ADR 0219 — Official s5d archive progress must not invent a percent when total bytes are unknown, double-count same-hash CAS media, or assume a cross-volume rename (I-013 leftover)

## Status

Accepted for Increment 3.20 as a distinct already-specified s5d leftover on I-013: archive progress must name a real phase (`scan` / `collect` / `write` / `verify` / `publish`), must not invent a percentage when total bytes are unknown, must not double-count same-hash media in CAS accounting, and must not assume a cross-volume rename. I-013 stays partial and is not marked complete. Existing I-013 remainingAcceptance wording (运行job归档固定rev并报告pending still unofficial, Increment 2.50 unpackable-manifest / packMode, 取消无半包发布, 保留策略不删可达blob, Increment 3.06 ArtifactKindAdmission, Increment 3.18 PackageProjectionAdmission) is not silently rewritten or cleared. Increment 2.50 packMode / sourceCompleteness, Increment 3.06 ArtifactKindAdmission, Increment 3.18 PackageProjectionAdmission, `MANIFEST_SNAPSHOT_MISMATCH`, and I-013 “cancel with no half-published package” are not re-qualified. This is planner accounting, not I-004 “同hash多引用仅1blob,” not I-042 `LEASE_DOUBLE_COUNT`, and not V-002 `INCREMENTAL_SHARED_DOUBLE_COUNT`; those bounds are not re-qualified and I-004 remainingAcceptance labels are not cleared. ENOSPC is not claimed and is not a measured qualification. A ZipPlanner / ZIP64 writer, a muxer, job archival, a StoragePort runtime, a Flutter widget tree, and an I-014 RestoreService are not invented. The same s5d row’s “unknown target space, warn and write a new file conservatively,” “cancel before publish does not replace the target,” “safe abort on ENOSPC,” and default `ZIP_STORED` clauses are not officialized here, because they would re-qualify I-011 unique-copy, I-013 cancel-no-half-package, or invent a zip writer. Increment 3.19 SaveAsNamedVersionAdmission, Increment 3.17 WebPublicationAdmission, Increment 2.37 / ADR 0136, a 60s WebCodecs/OPFS roundtrip, and a V-007 production lock are not re-qualified or claimed. I-014 “ID重映射” is not taken. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. I-012, I-013, I-020, I-014, I-011, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5d states that archive space planning aggregates new CAS bytes, a staging upper bound, protection of a necessary good old copy, and a safety margin by volume; that it must not assume a cross-volume rename or double-count same-hash media in CAS; that unknown target space is warned first and written conservatively as a new file; that any ENOSPC step aborts safely; that progress is shown as scan / collect / write / verify / publish; that a percentage is not invented when total bytes are unknown; and that cancel before publish does not replace the target. The ENOSPC, unknown-target conservative new-file, cancel-before-publish, and ZIP writer clauses are not taken here.

This increment officializes only the progress-phase, unknown-percent, same-hash CAS accounting, and cross-volume-rename bounds as a DEV-PURE compiler at the official entry path `packages/studio_archive_space_probe/lib/archive_space_admission.dart`:

- `scan`, `collect`, `write`, `verify`, and `publish` are admitted (`inventsPercent=false`, `sameHashCountedOnce=true`, `crossVolumeRenameAssumed=false`). A known total may report a percent.
- An unknown phase is `ARCHIVE_PROGRESS_KIND_UNKNOWN`.
- Reporting a percent when total bytes are unknown is `UNKNOWN_BYTES_PERCENT_FORBIDDEN`.
- Double-counting same-hash media in CAS accounting is `CAS_HASH_DOUBLE_COUNT_FORBIDDEN`.
- Assuming a cross-volume rename is `CROSS_VOLUME_RENAME_NOT_ASSUMED`.
- `packModeRequalified`, `artifactKindRequalified`, `packageProjectionRequalified`, `cancelHalfPackageRequalified`, `uniqueCopyRequalified`, `i004SameHashRequalified`, `leaseDoubleCountRequalified`, `enospcClaimed`, `zipPlannerInvented`, `muxerInvented`, `jobArchivalInvented`, `storagePortInvented`, `restoreInvented`, and `saveAsRequalified` stay false.

`tools/spikes/archive_space/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing `project_archive.dart`, packMode suites, and I-004 / I-042 suites are not rewritten.

## Consequences

The s5d archive-space accounting bounds are officialized at this admission. I-013 remainingAcceptance job-archival, packMode, cancel, retention, artifact-kind, and projection wording stay listed, so I-013 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i013-archive-space/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this archive-space admission, Increment 2.50 packMode, Increment 3.06 ArtifactKindAdmission, Increment 3.18 PackageProjectionAdmission, I-013 cancel-no-half-package, I-004 same-hash single blob, or I-042 `LEASE_DOUBLE_COUNT`. Do not invent a ZipPlanner, a muxer, job archival, a StoragePort runtime, or an I-014 RestoreService, and do not claim an ENOSPC measurement. Do not re-qualify Increment 3.19 SaveAsNamedVersionAdmission, `CHECKPOINT_NAME_EXISTS`, fork-new-projectId, Increment 3.10 ExplicitSaveAdmission, or Increment 3.11 CheckpointIdentityAdmission. Do not re-qualify Increment 3.17 WebPublicationAdmission or Increment 2.37 / ADR 0136, and do not claim a 60s WebCodecs/OPFS roundtrip or a V-007 production lock. Do not take I-014 “ID重映射” or invent a RestoreService for “旧版本恢复新rev.” Do not take s5d “再分发/执行许可分开” if that would re-qualify `FONT_REDISTRIBUTION_FACT` or `MODELS_REFERENCED_NOT_DOWNLOADED`.
