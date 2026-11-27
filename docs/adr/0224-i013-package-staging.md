# ADR 0224 — Official s5d packages are built from clean staging, must not reuse a previous session directory or casually pack caches, and analysis evidence needs consent (I-013 leftover)

## Status

Accepted for Increment 3.25 as a distinct already-specified s5d leftover on I-013: each package is built from clean staging, must not reuse a previous session-containing directory, must not casually pack a generic cache, and may include analysis evidence only when the user explicitly selects it as a production basis and permission is granted. I-013 stays partial and is not marked complete. Existing I-013 remainingAcceptance wording (运行job归档 still unofficial, Increment 2.50 packMode, 取消无半包发布, 保留策略不删可达blob, Increment 3.06 ArtifactKindAdmission, Increment 3.18 PackageProjectionAdmission, Increment 3.20 ArchiveSpaceAdmission, Increment 3.24 SessionExportAdmission) is not silently rewritten or cleared. Increment 3.24 SessionExportAdmission, Increment 1.92 / ADR 0099 default session and command-journal exclusion, Increment 3.22 AuditJournalAdmission, ADR 0018 no job-resume binding, and I-054 default-diagnostic exclusions are not re-qualified. The “package must not mix in a temporary session database” and “import must not resume side effects” sentences are not officialized here, because they would re-qualify ADR 0099 or ADR 0018. Job archival, an I-014 RestoreService, PatchGroup cherry-pick, workspace SQLite w5, a ZipPlanner, and a Flutter widget tree are not invented. Production FTS/RAG is not claimed. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. I-013, I-011, I-014, I-012, I-020, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5d states that each package is built from clean staging and must not reuse a previous directory that contained sessions; that analysis evidence enters a package only when the user separately selects it as a production basis and permission is granted; and that generic caches are not packed casually. Default session exclusion and import-resume sentences are not taken here.

This increment officializes only those staging and consent bounds as a DEV-PURE compiler at the official entry path `packages/studio_package_staging_probe/lib/package_staging_admission.dart`:

- `packageBuild` from clean staging is admitted (`cleanStaging=true`, `casualCachePacked=false`). Authorized analysis evidence is admitted when it is explicitly selected and permission is granted.
- An unknown kind is `PACKAGE_STAGING_KIND_UNKNOWN`.
- A build that is not from clean staging is `CLEAN_STAGING_REQUIRED`.
- Reusing a previous session-containing directory is `STALE_SESSION_DIRECTORY_FORBIDDEN`.
- Casually packing a generic cache is `CASUAL_CACHE_PACK_FORBIDDEN`.
- Including analysis evidence without both explicit selection and permission is `ANALYSIS_EVIDENCE_CONSENT_REQUIRED`.
- `sessionExportRequalified`, `credentialsDeletedBodyRequalified`, `auditJournalRequalified`, `jobResumeRequalified`, `productionFtsClaimed`, `jobArchivalInvented`, `restoreInvented`, `cherryPickInvented`, `workspaceW5Merged`, and `flutterWidgetTreeInvented` stay false.

`tools/spikes/package_staging/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing Increment 3.24 and ADR 0099 suites are not rewritten.

## Consequences

The s5d clean-staging and analysis-evidence-consent bounds are officialized at this admission. I-013 remainingAcceptance job-archival, packMode, cancel, retention, artifact-kind, projection, archive-space, and session-export wording stay listed, so I-013 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i013-package-staging/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this package-staging admission, Increment 3.24 SessionExportAdmission, Increment 1.92 / ADR 0099, Increment 3.22 AuditJournalAdmission, or ADR 0018 no job-resume binding. Do not invent job archival, an I-014 RestoreService, or PatchGroup cherry-pick. Do not take I-014 “ID重映射” or “旧版本恢复新rev.” Do not re-qualify Increment 3.23 OriginalPlaceholderAdmission, Increment 3.21 ArchiveLimitConsentAdmission, Increment 3.20 ArchiveSpaceAdmission, Increment 3.19 SaveAsNamedVersionAdmission, Increment 3.18 PackageProjectionAdmission, or Increment 3.17 WebPublicationAdmission. Do not claim a 60s WebCodecs/OPFS roundtrip, a V-007 production lock, production FTS/RAG, or an ENOSPC measurement. Do not take s5d “再分发/执行许可分开” if that would re-qualify `FONT_REDISTRIBUTION_FACT` or `MODELS_REFERENCED_NOT_DOWNLOADED`. s5a “未选history时旧引用标unavailable而不是指向当前内容” may be considered only if it can be bounded without re-qualifying ADR 0018 “no imported history.”
