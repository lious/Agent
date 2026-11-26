# ADR 0106 — Official I-032 fan-out and iteration limits are refused at plan construction

## Status

Accepted for Increment 1.99 as a bounded slice of the original I-032 remainingAcceptance item “fanout/迭代不越上限”. Official admitted `HarnessPlan` 1.0 safe-subset construction refuses a graph whose fan-out exceeds `maxFanout`, and refuses `maxFanout` / `maxModelIterations` / `maxNodes` values outside the admitted bounds. I-032 remains partial. `fullTaskComplete` stays false.

## Decision

I-032 remainingAcceptance is “图环/越namespace拒绝；fanout/迭代不越上限；过期fence不提交；100重启无重复副作用；手动锁始终有效.” This increment officializes only “fanout/迭代不越上限”, at the already-admitted PlanGraph constructor bound. Dynamic replan, model-loop execution, mapreduce expansion, unpaid model/API work, and a new PlanCompiler / DurableScheduler product surface are not invented.

The already-admitted bound implements the chosen clause: `HarnessPlan` counts, for each node, how many others list it as a dependency, and throws `PLAN_FANOUT` when that exceeds `limits.maxFanout`. `maxFanout` must be in 1..8, `maxModelIterations` in 1..64, and `maxNodes` must be at least the node count and at most 64; violations throw `PLAN_LIMIT`. No new planner types are added.

Existing suites do not officialize this wording and are not rewritten: `device_scheduler_test.dart` officializes DAG cycle refusal (`PLAN_CYCLE`), paid-execution subset refusal, protocol version, closed schema, placement, and in-memory expiry/cancel/late-result fences, but it never asserts `PLAN_FANOUT` or `PLAN_LIMIT`. `harness_transactions_test.dart` and `harness_takeover_test.dart` officialize durable dispatch, late fences, and takeover idempotency, not fan-out or iteration caps. Those files are not reused, weakened, or rewritten.

The other I-032 items stay listed: “图环/越namespace拒绝” is only partly already official (`PLAN_CYCLE` in `device_scheduler_test.dart`) and is not re-qualified; PlanGraph `NAMESPACE_MISMATCH` (inputRef / session / registerHarnessPlan) is not officialized in this increment. “过期fence不提交” is already official in the lease-fence suites and is not re-qualified. “100重启无重复副作用” remains unfinished (implementedScope already records no complete 100-restart proof; a new restart product surface is not invented). “手动锁始终有效” has no admitted PlanGraph manual-lock API and is not invented.

I-027 leftover remainingAcceptance was reconfirmed and stays listed in full: there is still no message/tool-call pairing API, no session fork / HTTP-replay mapping (`recoverMetadataSession` is not that close), and no session message-delete API (the I-013 archive wording is not this close). The Increment 1.98 I-027 files, `transactions_test.dart`, `workspace_test.dart`, `harness_transactions_test.dart`, and `peer_recovery_test.dart` are not rewritten.

This increment adds:

- `packages/studio_harness/test/i032_fanout_iteration_limits_test.dart`: a four-node graph in which two nodes depend on `a` is `PLAN_FANOUT` when `maxFanout` is 1 and is accepted when `maxFanout` is 2; `maxModelIterations` 0 and 65 are `PLAN_LIMIT` while 1 and 64 are accepted; `maxFanout` 0 and 9, and `maxNodes` below the node count, are `PLAN_LIMIT`.

Existing codes are not retargeted. Official InversePatch kind stays `restoreSnapshot`. Production algebra and the frozen native library are unchanged; a genuine in-scope limit leak would have been fixed narrowly and reported, and none was found.

## Consequences

The I-032 remainingAcceptance item “fanout/迭代不越上限” is cleared at this already-admitted HarnessPlan constructor bound. This is not a complete I-032: “图环/越namespace拒绝”, “过期fence不提交”, “100重启无重复副作用”, and “手动锁始终有效” remain listed rather than being silently reduced.

I-027 leftover remainingAcceptance stays listed in full. I-025 leftover remainingAcceptance stays listed in full. I-022 remainingAcceptance stays listed in full (a RenderGraph / GPU FrameLease is not invented). I-024 remainingAcceptance stays listed in full. I-021 leftover remainingAcceptance stays listed. I-015 leftover remainingAcceptance stays listed (`abi_test.cpp` is not rewritten). I-014 leftover remainingAcceptance stays listed in full: “恢复不倒退事件” still cannot be officialized without invention. I-013 leftover remainingAcceptance stays listed in full; job archival and `packMode=linked` are not invented. I-012 leftover remainingAcceptance, I-008 leftover remainingAcceptance, I-011 leftover remainingAcceptance, and V-005 remainingAcceptance including “durableRevision零丢失” stay listed. I-007 is not started. Planned I-026 and I-020 are not started. Closed I-005 section-3 rows are not opened. SQLite schema is not expanded to v10.

## Evidence

`docs/implementation/evidence/i032-fanout-iteration-limits/`.
