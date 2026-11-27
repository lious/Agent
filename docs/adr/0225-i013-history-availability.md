# ADR 0225 — Official s5a packages that omit history keep only the current snapshot and mark old refs unavailable, not retargeted at current content (I-013 leftover)

## Status

Accepted for Increment 3.26 as a distinct already-specified s5a leftover on I-013: when history is not selected, the package keeps only the current revision snapshot, and old references are marked unavailable rather than retargeted at the current content. I-013 stays partial and is not marked complete. Existing I-013 remainingAcceptance wording (运行job归档 still unofficial, Increment 2.50 packMode, 取消无半包发布, 保留策略不删可达blob, Increment 3.06 ArtifactKindAdmission, Increment 3.18 PackageProjectionAdmission, Increment 3.20 ArchiveSpaceAdmission, Increment 3.24 SessionExportAdmission, Increment 3.25 PackageStagingAdmission) is not silently rewritten or cleared. This does not re-qualify ADR 0018 ImportMap, “no imported history,” no historical-revision / session / job-resume binding, or fork-new-projectId. It does not invent a history-selected packer that carries referenced historical snapshots and their pinned blobs. Increment 3.25 PackageStagingAdmission, Increment 3.24 SessionExportAdmission, Increment 1.92 / ADR 0099 default session and command-journal exclusion, Increment 3.22 AuditJournalAdmission, and I-054 default-diagnostic exclusions are not re-qualified. The “package must not mix in a temporary session database” and “import must not resume side effects” sentences are not officialized here, because they would re-qualify ADR 0099 or ADR 0018. The s5a RevisionMap sentences “片段不在导入集合则scope invalid” and “所有旧审批失效” are not officialized here, because they would re-qualify ADR 0018 “不恢复旧审批.” Job archival, an I-014 RestoreService, PatchGroup cherry-pick, workspace SQLite w5, a ZipPlanner, and a Flutter widget tree are not invented. Production FTS/RAG is not claimed. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. I-013, I-011, I-014, I-012, I-020, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification. I-014 “ID重映射” and “旧版本恢复新rev” are not taken.

## Decision

s5a states that when history is not selected, only the current revision snapshot is kept, and old references are marked unavailable rather than pointed at the current content. The history-selected packing sentence, ImportMap persistence, and approval-invalidation sentences are not taken here.

This increment officializes only those omitted-history labeling bounds as a DEV-PURE compiler at the official entry path `packages/studio_history_availability_probe/lib/history_availability_admission.dart`:

- `historyOmitted` is admitted (`currentSnapshotOnly=true`, `oldRefsUnavailable=true`, `retargetedToCurrent=false`).
- An unknown kind is `HISTORY_AVAILABILITY_KIND_UNKNOWN`.
- Including historical snapshots when history is omitted is `HISTORICAL_SNAPSHOT_NOT_INCLUDED`.
- Retargeting old references at the current content is `OLD_REF_NOT_CURRENT`.
- Leaving old references unmarked as unavailable is `OLD_REF_NOT_UNAVAILABLE`.
- `importMapRequalified`, `historicalRevisionBindingRequalified`, `jobResumeRequalified`, `forkNewProjectIdRequalified`, `packageStagingRequalified`, `sessionExportRequalified`, `credentialsDeletedBodyRequalified`, `auditJournalRequalified`, `historyPackerInvented`, `restoreInvented`, `cherryPickInvented`, and `productionFtsClaimed` stay false.

`tools/spikes/history_availability/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing Increment 3.25, Increment 3.24, ADR 0099, and ADR 0018 suites are not rewritten.

## Consequences

The s5a omitted-history snapshot and old-ref availability bounds are officialized at this admission. I-013 remainingAcceptance job-archival, packMode, cancel, retention, artifact-kind, projection, archive-space, session-export, and package-staging wording stay listed, so I-013 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i013-history-availability/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this history-availability admission, Increment 3.25 PackageStagingAdmission, Increment 3.24 SessionExportAdmission, Increment 1.92 / ADR 0099, Increment 3.22 AuditJournalAdmission, or ADR 0018 ImportMap / no historical-revision binding / fork-new-projectId. Do not invent a history-selected packer, job archival, an I-014 RestoreService, or PatchGroup cherry-pick. Do not take I-014 “ID重映射” or “旧版本恢复新rev.” Do not officialize “片段不在导入集合则scope invalid” or “所有旧审批失效.” Do not take s5d “再分发/执行许可分开” if that would re-qualify `FONT_REDISTRIBUTION_FACT` or `MODELS_REFERENCED_NOT_DOWNLOADED`. Do not claim a 60s WebCodecs/OPFS roundtrip, a V-007 production lock, production FTS/RAG, or an ENOSPC measurement.
