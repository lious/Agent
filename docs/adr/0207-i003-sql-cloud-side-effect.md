# ADR 0207 — Official s5b SQL commit must not start a cloud side effect (I-003 leftover)

## Status

Accepted for Increment 3.08 as a distinct already-specified s5b leftover on I-003: a workspace SQLite commit transaction must not start a cloud side effect. I-003 stays partial and is not marked complete. I-003 revision tests are not rewritten. Existing I-003 remainingAcceptance labels (100 concurrent same-baseRevision, undo creates a new revision, no half-write, namespace isolation) are not silently cleared. Increment 3.07 CloseCheckpointAdmission, Increment 3.05 PackageAutoUpdateAdmission, Increment 3.06 ArtifactKindAdmission, ADR 0098 I-012 leftovers, official I-024 export suites, I-033 quote/apply, I-040 generated output, and I-011 crash leftovers are not re-qualified and are not rewritten. Quote/apply, paid generation, and a WorkflowCoordinator are not started. No paid API is called. The s5b “不能盲重试生成” clause is not taken. The s5b “保存中编辑/合并” row, s5b “生成中的资源”, and remaining s3 error-table rows are not taken. Increments 2.74–3.07 already-landed slices are not re-qualified. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-012, I-013, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, I-003, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5b states that a completed edit gesture or command freezes the after-document and inverse patch, lands required CAS files, then writes `commands` / `revisions` / `events` / `receipts` / `project_heads` in one workspace SQLite transaction, and that this SQL transaction must not start a cloud side effect.

This increment officializes only that last bound as a DEV-PURE compiler at the official entry path `packages/studio_sql_cloud_side_effect_probe/lib/sql_cloud_side_effect_admission.dart`:

- A local SQL commit that starts no cloud side effect is acknowledged (`acknowledged=true`, `cloudSideEffectStarted=false`).
- Starting a cloud side effect inside that SQL commit is `SQL_CLOUD_SIDE_EFFECT_FORBIDDEN`.
- This is not a cloud client, not quote/apply, not a generation submit, and not a rewrite of I-003 concurrency or revision tests.
- `closeCheckpointRequalified`, `packageAutoUpdateRequalified`, `artifactKindRequalified`, `i003RevisionTestsRewritten`, `i033Requalified`, `i040Requalified`, `i011CrashRequalified`, `quoteApplyStarted`, `paidGenerationStarted`, `workflowCoordinatorInvented`, and `paidApiCalled` stay false.

`tools/spikes/sql_cloud_side_effect/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s5b “禁止SQL内启动云副作用” bound is officialized at this admission. I-003 remainingAcceptance measurement and isolation labels stay listed, so I-003 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i003-sql-cloud-side-effect/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this SQL cloud-side-effect admission, Increment 3.07 CloseCheckpointAdmission, Increment 3.05 PackageAutoUpdateAdmission, Increment 3.06 ArtifactKindAdmission, ADR 0098 I-012 leftovers, I-003 revision tests, I-033, I-040, or I-011 crash leftovers. Do not start quote/apply or paid generation. Do not take s5b “不能盲重试生成” if that would re-qualify I-033, I-040, or I-011. Do not take s5b “保存中编辑/合并” or s5b “生成中的资源” if that would re-qualify ADR 0098, I-004 attach, I-013 archival, I-024, or I-040.
