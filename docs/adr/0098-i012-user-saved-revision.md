# ADR 0098 — Official I-012 continued head edits do not falsely rewrite userSavedRevision

## Status

Accepted for Increment 1.91 as a bounded slice of the original I-012 remainingAcceptance item “head继续编辑不伪改userSavedRevision”. Official userSavedRevision is the latest explicit save receipt's checkpoint revision (spec s5b): it is a derived join, not a persisted column, and continued head edits must not copy the new head into that receipt. I-012 remains partial. `fullTaskComplete` stays false.

Increment 1.91 first surveyed the still-listed I-011 clause “各崩溃点注入后只开最后好snapshot+tail”. ADR 0003 still records that validated fallback checkpoint+tail reconstruction and missing-revision reports remain unfinished. There is no RecoveryService or `test/storage/crash_points/` suite. The V-005 / `save_crash_test.dart` fifty SIGKILL archive-phase trials are not that reconstruction clause and are not re-qualified. No tightly bounded already-admitted subset of snapshot+tail was genuinely new without inventing reconstruction or rebranding WAL recovery / archive SIGKILL. That I-011 clause is therefore left listed and is not closed.

## Decision

Spec s5b states that userSavedRevision is only the query result of the last explicit save receipt's associated revision, not a writable counter and not headRevision. `PersistenceView.userSavedRevision` already implements that join (`ORDER BY save_receipts.seq DESC LIMIT 1` on explicit receipts). Existing `save_test.dart` officializes other I-012 remainingAcceptance items and related save paths — virtual-clock triggers, identical-request coalescing, and “no successful receipt means the save is not complete” — but it does not officialize this wording: the coalesce test asserts that head and the saved artifact do not move backwards after both saves complete, and Increment 1.90 asserts userSavedRevision only as support for I-011 durableRevision. Those files are not reused, weakened, or rewritten.

This increment adds:

- `packages/studio_store/test/i012_user_saved_revision_test.dart`: after `saveManaged`, a later rename advances head but userSavedRevision stays at the receipt revision; reopen still reports that receipt, not the later head.
- `packages/studio_sdk/test/i012_user_saved_revision_test.dart`: an in-flight explicit archive of a frozen snapshot does not invent or copy userSavedRevision onto a later head mid-flight; when that save completes, the receipt is the frozen revision, not the later head; a further edit still leaves the receipt unchanged.
- `packages/studio_editor_ui/test/i012_user_saved_revision_ui_test.dart`: after an explicit local save-managed, a later title save advances the Durable label but keeps the already-admitted “explicit save” label at the receipt revision, including after reopen.

Existing codes are not retargeted. Official InversePatch kind stays `restoreSnapshot`. Production algebra is unchanged; a genuine in-scope mis-report would have been fixed narrowly and reported, and none was found.

## Consequences

The I-012 remainingAcceptance item “head继续编辑不伪改userSavedRevision” is cleared at this already-admitted derived-receipt bound. The other I-012 clauses are not re-qualified here and remain listed: “虚拟时钟验证全部触发” is already official in `save_test.dart` (`virtual monotonic clock: idle, continuous maximum, 50 commits, lifecycle flush`); “并发save合并” is already official in the identical-request coalesce and two-coordinator tests; “保存完成只在durable receipt之后” is already official in the receipt-INSERT-failure and staging-failure tests (the result Future does not succeed and userSavedRevision stays null until a FULL receipt). I-011 leftover remainingAcceptance stays listed, including “各崩溃点注入后只开最后好snapshot+tail”. I-008 leftover remainingAcceptance is left listed. I-007 is not started. Closed I-005 section-3 rows are not opened. V-005 remainingAcceptance, including “durableRevision零丢失”, is left listed. SQLite schema is not expanded to v10.

## Evidence

`docs/implementation/evidence/i012-user-saved-revision/`.
