# ADR 0221 — Official s5a audit journal is metadata only, must not be replayed on import, and a new undo stack starts empty (I-014 leftover)

## Status

Accepted for Increment 3.22 as a distinct already-specified s5a leftover on I-014: an optional audit journal is CommandArchive metadata only, must not carry original payload, a `newFileToken`, or an executable body, must not be replayed on import, must not execute an old Undo as-is, and a new project's undo stack starts empty. I-014 stays partial and is not marked complete. Existing I-014 remainingAcceptance wording (zip slip / bomb / symlink, fork-new-projectId, migration keeps a good copy, 不支持feature只读保留, Increment 2.51, Increment 3.15 IdentityCollisionAdmission, Increment 3.16 FutureMajorAdmission, Increment 3.21 ArchiveLimitConsentAdmission) is not silently rewritten or cleared. Increment 1.92 / ADR 0099 default exclusion of the command journal from an embedded package is not re-qualified. Increment 3.21 ArchiveLimitConsentAdmission, `files_test` zip-slip / zip-bomb `ARCHIVE_LIMIT` / symlink refusal, Increment 3.16 FutureMajorAdmission, “不支持feature只读保留”, Increment 3.15 IdentityCollisionAdmission, Increment 2.51, and fork-new-projectId are not re-qualified. An I-014 RestoreService, PatchGroup cherry-pick, workspace SQLite w5, a schema migrator, and a Flutter widget tree are not invented. The same s5a row’s “a package must not mix in a temporary session database” sentence is not officialized here, because it would re-qualify ADR 0099. Lifecycle `RestoreVersion` remains a local command-store concern and is not invented as a product RestoreService. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. I-014, I-013, I-012, I-020, I-011, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5a states that `journal/commands.jsonl` is only a `CommandArchive` of `commandId`, `origin`, `revisionBefore`, `revisionAfter`, `payloadHash`, `changedEntityIds`, `eventIds`, and `redactedSummary`, and must not export original payload or `newFileToken`; that if history is selected, inverse snapshots may be read but must not execute an old Undo as-is; that a new project's undo stack starts empty; that a package must not mix in a temporary session database; and that exported audit journals still carry no executable body and must not be replayed on import. The default command-journal exclusion and session-database sentence are not taken here.

This increment officializes only the metadata-only, no-replay, no-execute-old-undo, and empty-undo-stack bounds as a DEV-PURE compiler at the official entry path `packages/studio_audit_journal_probe/lib/audit_journal_admission.dart`:

- `auditJournalExport` is admitted as metadata only (`metadataOnly=true`, `executableBody=false`). Including original payload or a `newFileToken` is `AUDIT_JOURNAL_PAYLOAD_FORBIDDEN`. Including an executable body is `AUDIT_JOURNAL_EXECUTABLE_FORBIDDEN`.
- `auditJournalImport` is admitted with `replayed=false`, `oldUndoExecuted=false`, and `undoStackEmpty=true`. Replaying the journal is `AUDIT_JOURNAL_REPLAY_FORBIDDEN`. Executing an old Undo as-is is `OLD_UNDO_NOT_EXECUTABLE`. Claiming an inherited undo stack is `UNDO_STACK_STARTS_EMPTY`.
- An unknown kind is `AUDIT_JOURNAL_KIND_UNKNOWN`.
- `credentialsDeletedBodyRequalified`, `archiveLimitConsentRequalified`, `futureMajorRequalified`, `identityCollisionRequalified`, `forkNewProjectIdRequalified`, `restoreInvented`, `cherryPickInvented`, `workspaceW5Merged`, `schemaMigratorInvented`, and `flutterWidgetTreeInvented` stay false.

`tools/spikes/audit_journal/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing `project_archive.dart`, `files_test.dart`, and `i013_credentials_deleted_body_test.dart` are not rewritten.

## Consequences

The s5a audit-journal bound is officialized at this admission. I-014 remainingAcceptance zip-slip / bomb / symlink, fork, migration, unsupported-feature, Increment 2.51, Increment 3.15, Increment 3.16, and Increment 3.21 wording stay listed, so I-014 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i014-audit-journal/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this audit-journal admission, Increment 1.92 / ADR 0099, Increment 3.21 ArchiveLimitConsentAdmission, `files_test` zip-slip / zip-bomb `ARCHIVE_LIMIT` / symlink refusal, Increment 3.16 FutureMajorAdmission, “不支持feature只读保留”, Increment 3.15 IdentityCollisionAdmission, Increment 2.51, or fork-new-projectId. Do not invent an I-014 RestoreService, PatchGroup cherry-pick, or a schema migrator. Do not take I-014 “ID重映射” or “旧版本恢复新rev.” Do not re-qualify Increment 3.20 ArchiveSpaceAdmission, Increment 3.19 SaveAsNamedVersionAdmission, Increment 3.18 PackageProjectionAdmission, or Increment 3.17 WebPublicationAdmission. Do not claim a 60s WebCodecs/OPFS roundtrip, a V-007 production lock, or an ENOSPC measurement. Do not take s5d “再分发/执行许可分开” if that would re-qualify `FONT_REDISTRIBUTION_FACT` or `MODELS_REFERENCED_NOT_DOWNLOADED`.
