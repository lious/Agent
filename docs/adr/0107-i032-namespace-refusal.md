# ADR 0107 — Official I-032 cross-namespace PlanGraph placement is refused

## Status

Accepted for Increment 2.00 as a bounded slice of the original I-032 remainingAcceptance item “越namespace拒绝”. Official admitted PlanGraph construction, placement, and plan registration refuse a crossing of plan, inputRef, session, or repository namespace as `NAMESPACE_MISMATCH`. I-032 remains partial. `fullTaskComplete` stays false.

## Decision

I-032 remainingAcceptance after Increment 1.99 is “图环/越namespace拒绝；过期fence不提交；100重启无重复副作用；手动锁始终有效.” This increment officializes only “越namespace拒绝”, at the already-admitted PlanGraph bounds ADR 0106 recorded as not officialized in 1.99: `HarnessPlan` inputRef namespace, `placeTask` session namespace, and `registerHarnessPlan` repository namespace. Dynamic replan, model-loop execution, mapreduce expansion, unpaid model/API work, and a new PlanCompiler / DurableScheduler product surface are not invented.

The already-admitted bound implements the chosen clause: `HarnessPlan` throws `NAMESPACE_MISMATCH` when a node `inputRef.ns` is not the plan `ns`; `placeTask` throws `NAMESPACE_MISMATCH` when the plan `ns` is not `harnessNamespace(session.namespace)`; `registerHarnessPlan` throws `NAMESPACE_MISMATCH` when the plan `ns` is not `harnessNamespace` of the repository namespace. No new planner types are added.

Existing suites do not officialize this wording and are not rewritten: `device_scheduler_test.dart` mentions “namespace” in a test name, but the body officializes only DAG cycle refusal (`PLAN_CYCLE`), paid-execution subset refusal, protocol version, and closed schema, and never asserts `NAMESPACE_MISMATCH`. `harness_transactions_test.dart` and `harness_takeover_test.dart` officialize same-namespace durable dispatch and takeover, not a cross-namespace plan refusal. `transactions_test.dart` officializes project/document `NAMESPACE_MISMATCH`, not PlanGraph inputRef / session / `registerHarnessPlan`. Increment 1.99 `i032_fanout_iteration_limits_test.dart` officializes fan-out and iteration caps, not this wording. Those files are not reused, weakened, or rewritten.

The slash-joined leftover “图环/越namespace拒绝” is split honestly so only the officialized namespace half is cleared. “图环” remains listed (already official as `PLAN_CYCLE` in `device_scheduler_test.dart` and not re-qualified). The combined item is not dropped as a whole, which would have silently cleared the already-official cycle half. After this increment, I-032 remainingAcceptance is “图环；过期fence不提交；100重启无重复副作用；手动锁始终有效.”

The other I-032 items stay listed: “过期fence不提交” is already official in the lease-fence suites and is not re-qualified. “100重启无重复副作用” remains unfinished (implementedScope already records no complete 100-restart proof; a new restart product surface is not invented). “手动锁始终有效” has no admitted PlanGraph manual-lock API and is not invented.

I-027 leftover remainingAcceptance was reconfirmed and stays listed in full. The Increment 1.98 I-027 files, `transactions_test.dart`, `workspace_test.dart`, `harness_transactions_test.dart`, and `peer_recovery_test.dart` are not rewritten.

This increment adds:

- `packages/studio_harness/test/i032_namespace_refusal_test.dart`: an `inputRef` whose `ns` is not the plan namespace is `NAMESPACE_MISMATCH` while a same-namespace plan is accepted; `placeTask` is `NAMESPACE_MISMATCH` when the plan namespace is not the session namespace, and accepts a matching session.
- `packages/studio_store/test/i032_namespace_refusal_test.dart`: `registerHarnessPlan` is `NAMESPACE_MISMATCH` when the plan namespace is not the repository harness namespace, even if the session itself is in scope; a same-namespace plan registers.

Existing codes are not retargeted, including `PLAN_FANOUT`, `PLAN_LIMIT`, and `PLAN_CYCLE`. Official InversePatch kind stays `restoreSnapshot`. Production algebra and the frozen native library are unchanged; a genuine in-scope namespace leak would have been fixed narrowly and reported, and none was found.

## Consequences

The I-032 remainingAcceptance item “越namespace拒绝” is cleared at this already-admitted PlanGraph bound. “图环” remains listed rather than being silently reduced. “过期fence不提交”, “100重启无重复副作用”, and “手动锁始终有效” remain listed rather than being silently reduced.

I-027 leftover remainingAcceptance stays listed in full. I-025 leftover remainingAcceptance stays listed in full. I-022 remainingAcceptance stays listed in full (a RenderGraph / GPU FrameLease is not invented). I-024 remainingAcceptance stays listed in full. I-021 leftover remainingAcceptance stays listed. I-015 leftover remainingAcceptance stays listed (`abi_test.cpp` is not rewritten). I-014 leftover remainingAcceptance stays listed in full: “恢复不倒退事件” still cannot be officialized without invention. I-013 leftover remainingAcceptance stays listed in full; job archival and `packMode=linked` are not invented. I-012 leftover remainingAcceptance, I-008 leftover remainingAcceptance, I-011 leftover remainingAcceptance, and V-005 remainingAcceptance including “durableRevision零丢失” stay listed. I-007 is not started. Planned I-026 and I-020 are not started. Closed I-005 section-3 rows are not opened. SQLite schema is not expanded to v10.

## Evidence

`docs/implementation/evidence/i032-namespace-refusal/`.
