# ADR 0133 — I-027 session rename, archive, and title search

## Status

Accepted for Increment 2.34 as a leftover I-027 remainingScope slice. I-027 stays partial. `fullTaskComplete` stays false. This is still a DEV-PURE in-memory `SessionStore`. It does not merge workspace SQLite w5, does not change Project `user_version` (stays 9), and does not claim production FTS/RAG. Explicit PatchGroup cherry-pick and the chat workbench UI stay unopened. A shared cross-app session is not stolen. InversePatch kind stays `restoreSnapshot`. `fullTasksCompleted` stays 0.

## Decision

The I-027 scope already names 新建/命名/归档/搜索. `createSession` and body `search` were already official. This increment adds:

- `renameSession` — a non-empty title updates the record; an empty title is `INVALID_SESSION_TITLE` and leaves the title unchanged.
- `archiveSession` — the record stays in this namespace, is omitted from the default `listSessions` / `searchSessions`, and can still be opened in the same namespace. Later `append`, `forkBranch`, `registerWaitingCall`, and `executeHttpTool` are `SESSION_ARCHIVED`. Archive is idempotent.
- `searchSessions` / `listSessions` — title and list queries in this namespace only; archived sessions require `includeArchived`. This is not production FTS.

A session cannot be listed, renamed, or archived from another app namespace (`SESSION_NOT_FOUND` / `NAMESPACE_MISMATCH`).

## Consequences

I-027 remains partial. Official new suite: 3 tests. Frozen 2.28 leftover acceptance (6) and the full `studio_harness` package (23 including the new suite) were re-run, not rewritten. Analyzer exit 0. 87-task counts stay 0 complete / 37 partial / 37 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i027-session-sidebar/`.

## Follow-up

Explicit PatchGroup cherry-pick and the chat workbench UI stay open. Next honest Linux/Web increment: another still-doable planned or remaining-partial slice from the four planning documents. Do not start bus Effect, limiter, or I-007 PCM remapping unless a narrowly specified interface already exists; do not invent a TrimPlanner or open video muted/solo.
