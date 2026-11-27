# ADR 0211 — Official s5b save prepared stage must not hold a long SQLite write transaction (I-003 leftover)

## Status

Accepted for Increment 3.12 as a distinct already-specified s5b leftover on I-003: the save prepared stage must not hold a long SQLite write transaction. This is a leftover fencing clause after Increment 3.09, not a re-qualification of WriterFenceAdmission. I-003 stays partial and is not marked complete. I-003 revision tests are not rewritten. Existing I-003 remainingAcceptance labels (100 concurrent same-baseRevision, undo creates a new revision, no half-write, namespace isolation) are not silently cleared. Increment 3.09 WriterFenceAdmission, Increment 3.08 SqlCloudSideEffectAdmission, Increment 3.11 CheckpointIdentityAdmission, Increment 3.10 ExplicitSaveAdmission, Increment 3.07 CloseCheckpointAdmission, Increment 3.05 PackageAutoUpdateAdmission, Increment 3.06 ArtifactKindAdmission, ADR 0003, ADR 0097, ADR 0098, I-032 PlanGraph fencing, and I-011 crash leftovers are not re-qualified. An OS lock runtime, a PlanGraph manual-lock API, crash takeover, pending-publication reconciliation, and a publish-path serial coordinator are not invented. The leftover fencing clause “different apps do not share a private workspace” / explicit App Group shared library is not officialized here. SQLite WAL recovery remains as already recorded in ADR 0003 and is not disabled. Store journal pragmas are not changed. A WAL-checkpoint runtime, a Flutter widget tree, a StoragePort runtime, a SAF or iCloud adapter, I-013 job archival, a muxer, and an I-014 RestoreService are not invented. The s5b “不能盲重试生成”, “保存中编辑/合并”, and “生成中的资源” rows are not taken. Remaining s3 error-table rows are not taken. Increments 2.74–3.11 already-landed slices are not re-qualified. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-012, I-003, I-013, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5b states that the save prepared stage must not hold a long SQLite write transaction. The adjacent “publish short critical section shares a serial coordinator with the current policy-epoch check” clause would invent a coordinator and is not taken. Crash takeover after the OS releases a lock, pending-publication reconciliation, and taking a live lock by expiry were already bounded or excluded by Increment 3.09 and are not re-opened.

This increment officializes only the prepared-stage write-hold bound as a DEV-PURE compiler at the official entry path `packages/studio_prepared_stage_probe/lib/prepared_stage_admission.dart`:

- A save prepared stage that does not hold a long SQLite write transaction is admitted (`admitted=true`, `sqliteWriteHeldLong=false`).
- A path that is not in the prepared stage is `PREPARED_STAGE_REQUIRED`.
- Holding a long SQLite write transaction during that prepared stage is `PREPARED_STAGE_LONG_WRITE_FORBIDDEN`.
- `writerFenceRequalified`, `sqlCloudSideEffectRequalified`, `checkpointIdentityRequalified`, `i003RevisionTestsRewritten`, `i011CrashRequalified`, `osLockRuntimeInvented`, `crashTakeoverOfficialized`, `coordinatorInvented`, `appGroupShareOfficialized`, and `i032PlanGraphFenceRequalified` stay false.

`tools/spikes/prepared_stage/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s5b prepared-stage write-hold bound is officialized at this admission. I-003 remainingAcceptance measurement and isolation labels stay listed, so I-003 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i003-prepared-stage/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this prepared-stage admission, Increment 3.09 WriterFenceAdmission, Increment 3.08 SqlCloudSideEffectAdmission, Increment 3.11 CheckpointIdentityAdmission, I-003 revision tests, I-032 PlanGraph fencing, or I-011 crash leftovers. Do not invent an OS lock runtime, a PlanGraph manual-lock API, crash takeover, pending-publication reconciliation, or a publish-path serial coordinator. The leftover fencing clause “different apps do not share a private workspace” / explicit App Group shared library may be considered only if it can be bounded without inventing an OS lock runtime or silently clearing I-003 namespace-isolation labels. Do not take s5b “不能盲重试生成”, “保存中编辑/合并”, or “生成中的资源” if that would re-qualify I-033, I-040, I-011, ADR 0098, I-004 attach, I-013 archival, or I-024.
