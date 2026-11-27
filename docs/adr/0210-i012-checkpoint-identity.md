# ADR 0210 — Official s5b recovery checkpoint is not a SQLite WAL checkpoint, and a lagging checkpointRevision does not mean edits are unsaved (I-012 leftover)

## Status

Accepted for Increment 3.11 as a distinct already-specified s5b leftover on I-012: a product recovery checkpoint is not a SQLite WAL checkpoint and must not recopy media; a lagging `checkpointRevision` does not mean those edits are unsaved. I-012 stays partial and is not marked complete. Existing I-012 remainingAcceptance wording is not silently rewritten. ADR 0003 managed checkpoints, Increment 3.07 CloseCheckpointAdmission, Increment 3.10 ExplicitSaveAdmission, Increment 3.05 PackageAutoUpdateAdmission, Increment 3.06 ArtifactKindAdmission, Increment 3.09 WriterFenceAdmission, ADR 0097 durableRevision, ADR 0098 I-012 leftovers, and I-011 crash leftovers are not re-qualified. SQLite WAL recovery remains as already recorded in ADR 0003 and is not disabled here. A WAL-checkpoint runtime, a Flutter widget tree, a StoragePort runtime, a SAF or iCloud adapter, I-013 job archival, a muxer, and an I-014 RestoreService are not invented. A finished V-005 provider qualification is not claimed. The 30s idle / 120s max-attempt figures in s5b remain design defaults and are not claimed as a measured qualification. The s5b close-path draft confirmation widget was not officialized in 3.07 and is not officialized here; ADR 0028 already covers discarding pending ghosts on close and is not re-qualified. The s5b “不能盲重试生成”, “保存中编辑/合并”, and “生成中的资源” rows are not taken. Remaining s3 error-table rows are not taken. The leftover fencing clauses “prepared stage must not hold a long SQLite write transaction” and “different apps do not share a private workspace” are not taken. Increments 2.74–3.10 already-landed slices are not re-qualified. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-012, I-003, I-013, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5b states that an automatic recovery checkpoint is registered on an already-durable transaction, materializes or reuses same-hash document JSON, verifies references, and updates the latest checkpoint pointer; that it is not a SQLite WAL checkpoint and is not a recopy of media; and that `checkpointRevision` is taken from the record the pointer names, may lag head, and does not mean those edits were not written to disk.

This increment officializes that identity bound as a DEV-PURE compiler at the official entry path `packages/studio_checkpoint_identity_probe/lib/checkpoint_identity_admission.dart`:

- A product recovery checkpoint is admitted (`isSqliteWalCheckpoint=false`, `mediaRecopied=false`, `lagMeansUnsaved=false`), including when `checkpointRevision` lags head.
- Treating that checkpoint as a SQLite WAL checkpoint (`PRAGMA wal_checkpoint`) is `CHECKPOINT_IS_NOT_WAL`.
- Recopying media instead of reusing same-hash document JSON is `CHECKPOINT_MEDIA_RECOPY_FORBIDDEN`.
- Claiming that a lagging `checkpointRevision` means the later head edits are unsaved is `CHECKPOINT_LAG_NOT_UNSAVED`.
- This does not change store journal pragmas, does not invent a WAL-checkpoint runtime, and does not retract ADR 0003's record that SQLite WAL recovery is real. ADR 0003 snapshot reuse, Increment 3.07 close-path checkpoint requests, Increment 3.10 explicit-save receipts, and ADR 0097 derived durableRevision are not re-qualified.
- `adr0003Requalified`, `closeCheckpointRequalified`, `explicitSaveRequalified`, `packageAutoUpdateRequalified`, `i011DurableRevisionRequalified`, `i011CrashRequalified`, `walCheckpointRuntimeInvented`, `i014RestoreInvented`, and `flutterWidgetTreeInvented` stay false.

`tools/spikes/checkpoint_identity/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s5b recovery-checkpoint identity bound is officialized at this admission. I-012 product remainingScope stays open, so I-012 stays partial and is not marked complete. Existing I-012 remainingAcceptance wording is left listed and is not silently rewritten. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i012-checkpoint-identity/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this checkpoint-identity admission, ADR 0003, Increment 3.07 CloseCheckpointAdmission, Increment 3.10 ExplicitSaveAdmission, Increment 3.05 PackageAutoUpdateAdmission, Increment 3.06 ArtifactKindAdmission, ADR 0097, ADR 0098, or Increment 3.09 WriterFenceAdmission. Do not invent a WAL-checkpoint runtime, a Flutter widget tree, a StoragePort runtime, a SAF/iCloud adapter, I-013 job archival, or an I-014 RestoreService. Do not take s5b “不能盲重试生成”, “保存中编辑/合并”, or “生成中的资源” if that would re-qualify I-033, I-040, I-011, ADR 0098, I-004 attach, I-013 archival, or I-024. The leftover fencing clauses “prepared stage must not hold a long SQLite write transaction” and “different apps do not share a private workspace” may be considered only if they can be bounded without inventing an OS lock runtime or officializing crash takeover / pending-publication reconciliation.
