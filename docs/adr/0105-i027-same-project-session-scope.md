# ADR 0105 — Official I-027 same-project session scope isolation

## Status

Accepted for Increment 1.98 as a bounded slice of the original I-027 remainingAcceptance item “同一项目两个会话作用域隔离”. Official admitted `DocumentRepository.createSession` / `registerHarnessPlan` and `StudioWorkspace.createMetadataComputeSession` keep two sessions bound to the same project in independent scopes. I-027 remains partial. `fullTaskComplete` stays false.

## Decision

I-027 remainingAcceptance is “同一项目两个会话作用域隔离；tool-call/result配对；fork/resume不重放HTTP副作用；删除正文不留可搜索副本.” This increment officializes only the first item, at the already-admitted scoped session metadata and harness-plan bound. Message/branch/project chat mapping, a SessionStore product surface, tool-call/result pairing APIs, and HTTP-replay fork/resume are not invented. Cross-App session sharing is not opened.

The already-admitted bound implements the chosen clause: `sessions` rows are keyed by `(ns, id)`; `harness_plans` / `harness_steps` are keyed by `(ns, session_id, plan_hash)`; `registerHarnessPlan` binds a `SessionRef` to a project id; `ComputeSessionCoordinator` registers a per-session plan against the open project. Two sessions on that project therefore keep independent titles, coordinator boots, plan identities, and step statuses. Running or finishing work in one session does not commit the other, and the project revision is unchanged.

Existing suites do not officialize this wording and are not rewritten: `transactions_test.dart` officializes cross-namespace isolation of the same session id, not two sessions on one project; `workspace_test.dart` officializes cross-App workspace isolation and that two metadata sessions share one local executor slot (`DEVICE_RESOURCE_BUSY`), not that their plans and statuses stay isolated; `harness_transactions_test.dart` officializes one session’s durable DAG and that project revision stays isolated from harness work; `peer_recovery_test.dart` officializes same-id recovery fencing. Those files are not reused, weakened, or rewritten.

The remaining I-027 items stay listed: “tool-call/result配对” still has no message/tool-call pairing API (harness node receipts in the one-session DAG suite are not this wording and are not re-qualified); “fork/resume不重放HTTP副作用” would require inventing session fork and HTTP-replay mapping (`recoverMetadataSession` is not that close and is not re-qualified); “删除正文不留可搜索副本” is not officialized as an I-027 session-body close (the I-013 archive wording is not re-qualified, and a session message-delete API is not invented).

This increment adds:

- `packages/studio_store/test/i027_same_project_session_scope_test.dart`: two sessions on project `p` keep independent titles and coordinator boots; finishing a harness step in session A leaves session B’s step unset; after a store reopen, A remains committed, B is still claimable, and A’s boot cannot administer B.
- `packages/studio_sdk/test/i027_same_project_session_scope_test.dart`: two `createMetadataComputeSession` coordinators on the same open project have different plan hashes; running `digest-0` on the first leaves the second pending, and a later run of the second does not change the first; project revision stays 0.

Existing codes are not retargeted. Official InversePatch kind stays `restoreSnapshot`. Production algebra and the frozen native library are unchanged; a genuine in-scope cross-session leak would have been fixed narrowly and reported, and none was found.

## Consequences

The I-027 remainingAcceptance item “同一项目两个会话作用域隔离” is cleared at this already-admitted same-project session / harness-plan bound. This is not a complete I-027: “tool-call/result配对”, “fork/resume不重放HTTP副作用”, and “删除正文不留可搜索副本” remain listed rather than being silently reduced.

I-025 leftover remainingAcceptance stays listed in full: “恢复最后durable编辑” and “导出通过I-024” already have admitted reopen / local-export suites and are not re-qualified; the Increment 1.97 six-clip files, `local_video_test.dart`, `local_video_ui_test.dart`, and `save_test.dart` are not rewritten. A caption-burn path and a 60s export are not invented. I-022 remainingAcceptance stays listed in full (a RenderGraph / GPU FrameLease is not invented). I-024 remainingAcceptance stays listed in full. I-021 leftover remainingAcceptance stays listed (`source_preview_test.dart` and `frame_proxy_test.dart` are not rewritten). I-015 leftover remainingAcceptance stays listed (`abi_test.cpp` is not rewritten). I-014 leftover remainingAcceptance stays listed in full: “恢复不倒退事件” still cannot be officialized without invention. I-013 leftover remainingAcceptance stays listed in full; job archival and `packMode=linked` are not invented. I-012 leftover remainingAcceptance, I-008 leftover remainingAcceptance, I-011 leftover remainingAcceptance, and V-005 remainingAcceptance including “durableRevision零丢失” stay listed. I-007 is not started. Planned I-026 and I-020 are not started. Closed I-005 section-3 rows are not opened. SQLite schema is not expanded to v10.

## Evidence

`docs/implementation/evidence/i027-same-project-session-scope/`.
