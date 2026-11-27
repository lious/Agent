# ADR 0125 — I-029 effective intent, forgetting, and compaction watermarks

## Status

Accepted for Increment 2.26 as the first Linux/Web DEV-PURE slice of I-029. This is an in-memory workspace ledger, not a workspace schema w5 merge and not a Project `user_version` change. `fullTasksCompleted` stays 0. I-027 leftover remainingAcceptance is not closed.

## Decision

`EffectiveIntentReducer` officializes Declare, Supersede, Retract, and explicit `RestoreIntentAsNew`. Supersede atomically retires the old record and activates the new one. Retract does not revive an earlier value. A purged body cannot be restored. `expectedHeadSeq` conflicts are `INTENT_HEAD_CONFLICT` and do not half-write. Duplicate commands with the same idempotency key are idempotent.

`CompactionStore` issues a watermarked snapshot of the current intent digest. A privacy-epoch or head-digest change makes a draft `SNAPSHOT_STALE` and requires a rebuild. `ContextCompiler` (via `compile`) serializes current constraints from the reducer ledger, not from a chat summary. Legacy or free-text claims are dropped and cannot revive a retired value.

`DeletionBarrier` purges a turn body, marks solely-sourced intents purged, leaves Project revision unchanged, and reports already-uploaded provider copies as `notSupported` / not globally erased. Ambiguous references such as “删掉她” with multiple asset candidates are `REFERENCE_AMBIGUOUS` and do not delete files.

## Consequences

I-029 becomes partial. Official new suite: 6 tests, including the s10a mood trajectory and 1000 events with zero revival of retired constraints. Frozen I-028 ingest/projection suite (6) is re-run, not rewritten. Analyzer exit 0. 87-task counts become 0 complete / 37 partial / 37 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i029-intent-forgetting/`.

## Follow-up

Workspace SQLite w5 persist, real FTS/embedding GC, I-027 session/branch/HTTP-replay wiring, I-031 harness / I-003 outbox connection, and production RAG remain open. Next honest Linux/Web increments include a follow-up I-007 MakeCompound persist that first handles I-006 external-link inclusion / unlink, or leftover I-027 remainingAcceptance.
