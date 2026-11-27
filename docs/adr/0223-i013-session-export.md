# ADR 0223 — Official s5a/s5d omitted session content stays redacted, command bodies are not exported, and runs are historical (I-013 leftover)

## Status

Accepted for Increment 3.24 as a distinct already-specified s5a / s5d leftover on I-013: when session content is not included, `contentRef`s are redacted placeholder IDs and body blobs are not retained; command bodies are not exported; and runs are historical or `interruptedOnExport`, not live. I-013 stays partial and is not marked complete. Existing I-013 remainingAcceptance wording (运行job归档 still unofficial, Increment 2.50 packMode, 取消无半包发布, 保留策略不删可达blob, Increment 3.06 ArtifactKindAdmission, Increment 3.18 PackageProjectionAdmission, Increment 3.20 ArchiveSpaceAdmission) is not silently rewritten or cleared. Increment 1.92 / ADR 0099 default exclusion of sessions and the command journal from an embedded package is not re-qualified. Increment 3.22 AuditJournalAdmission, ADR 0018 no job-resume binding, and I-054 default-diagnostic exclusions are not re-qualified. Production FTS/RAG is not claimed. Job archival, an I-014 RestoreService, PatchGroup cherry-pick, workspace SQLite w5, and a Flutter widget tree are not invented. The same s5a / s5d “a package must not mix in a temporary session database” and “import must not resume side effects” sentences are not officialized here, because they would re-qualify ADR 0099 or ADR 0018. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. I-011, I-014, I-013, I-012, I-020, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5a states that sessions are exported only when the user explicitly selects them; that when `contentIncluded=false`, every `contentRef` is a redacted placeholder ID and body blobs are not retained; that runs are historical records and in-progress tasks are written as `interruptedOnExport`; and that approvals, remote task bindings, credentials, and executable tool bodies are not exported. s5d states that `headersOnly` or `selectedContent` exports use SessionArchive 2.0 with `commandBodiesIncluded=false`, and that all old runs are `historical` / `interruptedOnExport`. Default session exclusion and “do not resume side effects on import” are not taken here.

This increment officializes only the omitted-content redaction, no-command-body, and historical-run bounds as a DEV-PURE compiler at the official entry path `packages/studio_session_export_probe/lib/session_export_admission.dart`:

- `sessionExport` with content omitted is admitted as redacted (`contentRedacted=true`, `bodyBlobsIncluded=false`, `commandBodiesIncluded=false`, `runsHistorical=true`). `historical` and `interruptedOnExport` run states are admitted.
- An unknown kind is `SESSION_EXPORT_KIND_UNKNOWN`.
- Body blobs when content is omitted are `SESSION_BODY_BLOB_FORBIDDEN`.
- Unredacted contentRefs when content is omitted are `SESSION_CONTENT_NOT_REDACTED`.
- Exporting command bodies is `COMMAND_BODY_NOT_EXPORTED`.
- A live run state is `RUN_MUST_BE_HISTORICAL`.
- `credentialsDeletedBodyRequalified`, `auditJournalRequalified`, `jobResumeRequalified`, `i054Requalified`, `productionFtsClaimed`, `jobArchivalInvented`, `restoreInvented`, `cherryPickInvented`, `workspaceW5Merged`, and `flutterWidgetTreeInvented` stay false.

`tools/spikes/session_export/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing `i013_credentials_deleted_body_test.dart` and Increment 3.22 suites are not rewritten.

## Consequences

The s5a / s5d omitted-session-content bound is officialized at this admission. I-013 remainingAcceptance job-archival, packMode, cancel, retention, artifact-kind, projection, and archive-space wording stay listed, so I-013 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i013-session-export/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this session-export admission, Increment 1.92 / ADR 0099, Increment 3.22 AuditJournalAdmission, or ADR 0018 no job-resume binding. Do not invent job archival, an I-014 RestoreService, or PatchGroup cherry-pick. Do not take I-014 “ID重映射” or “旧版本恢复新rev.” Do not re-qualify Increment 3.23 OriginalPlaceholderAdmission, Increment 3.21 ArchiveLimitConsentAdmission, Increment 3.20 ArchiveSpaceAdmission, Increment 3.19 SaveAsNamedVersionAdmission, Increment 3.18 PackageProjectionAdmission, or Increment 3.17 WebPublicationAdmission. Do not claim a 60s WebCodecs/OPFS roundtrip, a V-007 production lock, production FTS/RAG, or an ENOSPC measurement. Do not take s5d “再分发/执行许可分开” if that would re-qualify `FONT_REDISTRIBUTION_FACT` or `MODELS_REFERENCED_NOT_DOWNLOADED`.
