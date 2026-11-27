# ADR 0118 — I-033 approval, budget reservation, and idempotent posting

## Status

Accepted for Increment 2.19 as the first Linux/Web-exercisable slice of I-033. I-033 moves from planned to partial. `fullTaskComplete` stays false. This does not call a paid API, does not represent a permission grant, and does not persist receipts through the I-003 project store.

## Decision

`packages/studio_harness` lands the planned entry points: `ApprovalService` (`lib/approval.dart`), `BudgetLedger` (`lib/budget.dart`), and `SubmissionReconciler` (`lib/reconcile.dart`). Official suite: `test/billing/unknown/i033_reconcile_test.dart` (6).

The same idempotency key causes at most one provider POST (`FakeBillingProvider.postCount` stays 1 on a repeated submit). An `unknown` provider status is not blindly retried; a second submit of that key throws `UNKNOWN_NO_BLIND_RETRY`, and `poll` only reads status. A late cancel of an unknown in-flight submission releases the reservation, marks the receipt cancelled, and does not attach to the timeline; a late cancel after a settled post leaves settlement in place and does not append a timeline event. Fee, upload, and portrait consents are all required; a license warning cannot exempt a missing consent (`WARNING_DOES_NOT_EXEMPT`) and no POST is issued. Prompt/resource/revision binding is checked on submit; a binding change invalidates the approval (`APPROVAL_STALE`) and never auto-increases budget quota. Budget exhaustion throws `BUDGET_EXHAUSTED` and pauses further reservations.

`FakeBillingProvider` is a DEV synthetic vendor. Real money or paid API calls always need a separate approval and are not performed here. An approval is not a permission grant.

This increment does not change the core project store `user_version` (stays 9) and does not write the I-003 SQLite outbox.

## Consequences

87-task counts become 0 complete / 35 partial / 39 planned / 13 blocked. `fullTasksCompleted` stays 0. Official new suite: 6 tests. Frozen studio_harness suites re-run. Analyzer exit 0.

## Evidence

`docs/implementation/evidence/i033-approval-budget/`.

## Follow-up

Persisting receipts through the I-003 outbox, production vendor adapters, and any real-money reconciliation remain open. Next honest Linux/Web increments include I-050 embedding encryption and honest CharacterRepository wiring (clone inference stays unavailable), I-026 template UI / graphics-library store, remaining art/workbench visual language, and further play-protocol software tests without physical two-device E2E or schema v10 / XD-010 claims.
