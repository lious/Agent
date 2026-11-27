# ADR 0127 — I-027 leftover tool-call pairing, fork/resume HTTP, and body purge

## Status

Accepted for Increment 2.28 as a leftover acceptance slice of I-027. I-027 stays partial. Product remainingScope (新建/命名/归档/搜索/fork/resume/显式挑patch and the chat workbench UI) is not closed. This increment does not merge workspace SQLite w5, does not change Project `user_version` (stays 9), and does not claim production FTS/RAG. A shared cross-app session is not stolen. `fullTasksCompleted` stays 0. InversePatch kind is unchanged (`restoreSnapshot`). I-006 remainingScope is not closed.

## Decision

`packages/studio_harness/lib/session_store.dart` is a DEV-PURE in-memory `SessionStore` / branch / message ledger, not the project store and not a production MessageStore SQLite.

- A `tool` message must carry `runId`, `toolCallId`, and `agentId` that match one waiting call on the same session and branch; a second result, a missing call, or a `user` message with `toolCallId` is `TOOL_CALL_MISMATCH` and does not append. An untrusted `system` role is `UNTRUSTED_SYSTEM`.
- `forkBranch` inherits the parent prefix at `atEventSeq`, leaves the parent unchanged, and does not copy or resend HTTP tool posts. `resumeBranch` restores the projection and reconciles unfinished calls without posting. A second resume still does not post.
- `purgeBody` redacts the event, clears the body, advances `privacyEpoch`, and removes the text from the searchable index. A late append with a stale epoch is `STALE_PRIVACY_EPOCH` and does not restore the phrase.
- A session id is not readable from another app namespace (`NAMESPACE_MISMATCH` or `SESSION_NOT_FOUND`). The store is not a shared cross-app session pool.

## Consequences

I-027 remains partial. Official new suite: 6 tests. Existing `studio_harness` package tests (20 including the new suite) were re-run, not rewritten. Analyzer exit 0. 87-task counts stay 0 complete / 37 partial / 37 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i027-session-leftover-acceptance/`.

## Follow-up

Product-level New/Rename/Archive/Search, explicit PatchGroup cherry-pick, and the chat workbench UI stay open. Workspace schema w5 and production RAG stay unclaimed. Next honest Linux/Web increment: leftover I-006 remainingScope (track lock / syncLock / multi-track bounds, and field-aware invert of Slip / Roll / Slide), without silently closing anything not implemented.
