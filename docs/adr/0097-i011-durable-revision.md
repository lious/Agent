# ADR 0097 — Official I-011 durableRevision is the derived ACK'd head and is not falsely reported

## Status

Accepted for Increment 1.90 as a bounded slice of the original I-011 remainingAcceptance item “durableRevision不虚报”. Official durableRevision is the derived `PersistenceView.headRevision` (spec s5b): it equals the last successfully committed and ACK'd `project_heads.revision`, is a display projection, and is not a persisted column. I-011 remains partial. `fullTaskComplete` stays false.

## Decision

Spec s5b states that durableRevision is not another content revision: `headRevision` comes only from a successfully committed, synchronously ACK'd `project_heads.revision`; on a normal open, durableRevision equals `headRevision` and is not stored as its own column. The already-admitted `PersistenceView` implements that projection (`headRevision` is `read(projectId).revision`; checkpoint and save receipts are joined separately). Existing `save_test.dart` and `save_crash_test.dart` already inspect `headRevision` and `userSavedRevision` on related save paths, but they were not an official I-011 remainingAcceptance close for “durableRevision不虚报” and are not reused, weakened, or rewritten.

This increment adds:

- `packages/studio_store/test/i011_durable_revision_test.dart`: the workspace SQLite schema has no `durableRevision`, `dirty`, `userSavedRevision`, or `snapshotRevision` columns; official durableRevision equals `PersistenceView.headRevision` and the document revision; after a committed rename and reopen, the durable display still equals the ACK'd `project_heads.revision` and does not invent a later value.
- `packages/studio_sdk/test/i011_durable_revision_test.dart`: a failed, unacked save leaves durableRevision at the acknowledged head, does not invent a `userSavedRevision`, and a later committed edit advances durableRevision to the new ACK'd head without rewriting the last receipt into a false durable value (`packageBehind` stays true).

Existing codes are not retargeted. Official InversePatch kind stays `restoreSnapshot`. Production algebra is unchanged; a genuine in-scope mis-report would have been fixed narrowly and reported, and none was found.

## Consequences

The I-011 remainingAcceptance item “durableRevision不虚报” is cleared at this already-admitted derived-head bound. The other I-011 clauses are not re-qualified here: “损坏唯一好副本不覆盖” is already official in `save_test.dart` / `files_test.dart`; “Schema完整往返” already has official empty-document, archive, and semantic-closure roundtrips; “各崩溃点注入后只开最后好snapshot+tail” is not closed because ADR 0003 still records that validated fallback checkpoint+tail reconstruction and missing-revision reports remain unfinished (the V-005 / `save_crash_test.dart` fifty SIGKILL archive-phase trials are not this reconstruction clause). Those three remain listed rather than being silently reduced. I-007 is not started. Closed I-005 section-3 rows are not opened. I-008 leftover remainingAcceptance is left listed and is not silently cleared. SQLite schema is not expanded to v10.

## Evidence

`docs/implementation/evidence/i011-durable-revision/`.
