# ADR 0150 — Official I-014 same-project restore does not roll back event seq

## Status

Accepted for Increment 2.51 as the leftover I-014 clause 「恢复不倒退事件」. I-014 stays partial. I-013 stays partial (job archival remains unopened). I-037, I-038, and V-007 stay partial and are not marked complete. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. This increment does not invent a product RestoreService that commits a lifecycle transaction to the project store, and does not replace SQLite or restore old approvals.

## Decision

s5d says a same-project version restore first produces an exact before/after diff and a protected-field list, pinning the source checkpoint/hash, current `expectedRevision`, epochs, and consent. After user confirmation, a single lifecycle transaction would create `head+1`, reuse still-existing immutable entity definition versions, and leave later edits on `max(version)+1`. It must not roll back event seq, replace the entire SQLite database, or restore old approvals. The before snapshot is pinned so the new revision can undo with `restoreSnapshot`. Locked manual fields default-block; the user may explicitly confirm overwrite or switch to fork. AI cannot issue `restoreVersion`.

This increment officializes that bound as a DEV-PURE planner in `packages/studio_document/lib/restore_version.dart`:

- `RestoreVersionPlanner.plan` returns a `RestoreVersionPlan` with `proposedRevision = currentRevision + 1` and `plannedEventSeq = currentEventSeq + 1`. `eventSeqRolledBack`, `sqliteReplaced`, and `approvalsRestored` stay false. `inversePatchKind` stays `restoreSnapshot`. The plan does not submit or write a document.
- A request to roll back event seq is `EVENT_SEQ_REGRESSION`. Replacing SQLite or restoring approvals is `UNSUPPORTED_EDIT_TECHNIQUE`. An `expectedRevision` mismatch is `REVISION_CONFLICT`. Missing consent is `APPROVAL_REQUIRED`.
- Locked manual fields are `FIELD_LOCKED` unless the user confirms overwrite or chooses fork. An AI actor is `TOOL_NOT_ALLOWED`.

The Increment 1.93 I-014 auto-external-link official suites were re-run, not rewritten. zip slip / bomb / symlink refusals, `fork` new projectId, interrupted migration, and unsupported-feature read-only retention are not re-qualified.

## Consequences

The leftover I-014 remainingAcceptance item 「恢复不倒退事件」 is officialized at this planner bound. A product RestoreService that commits `head+1` into the project store remains unopened. I-014 stays partial. 87-task counts stay 0 complete / 42 partial / 32 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i014-restore-event-seq/`.

## Follow-up

Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial work from the four planning documents. Do not invent I-013 job archival unless that slice is already specified and can be officialized without a paid-job coordinator. Do not claim a 60s WebCodecs/OPFS roundtrip or pin a V-007 production lock. Do not start quote/apply, paid generation, or SQL `vertical.v1` unless a narrowly specified protocol slice is already written. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, or V-007 complete.
