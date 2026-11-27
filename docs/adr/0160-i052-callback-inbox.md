# ADR 0160 — Official I-052 callback de-duplication and unknown-no-repost

## Status

Accepted for Increment 2.61 as the first I-052 slice. I-052 moves planned → partial and is not marked complete. The V-021=serverless gate is not met and is not claimed; V-021 stays blocked. This increment does not invent a WorkflowCoordinator, a real GPU worker, a FastAPI/PostgreSQL deployment, or a durable persistence schema. Device-disconnect durability and multi-tenant fairness stay later. It is not a rewrite of I-040 VideoGenerationProvider (submit/poll/insert clips) or I-033 SubmissionReconciler (harness posting and budget reconcile). I-051 leftover real-gateway deployment is not opened. I-032 leftover `PLAN_CYCLE` / manual-lock is not re-qualified. I-057 and I-037 leftovers are not re-qualified. I-056, I-054 default-diagnostic exclusions, and I-029 DeletionBarrier are not re-qualified. I-053 and I-033 leftovers are not re-qualified. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-055 is not started. I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, and I-057 stay partial and are not marked complete. V-009, V-016, V-017, V-018, V-019, and V-022 stay blocked. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called.

## Decision

s10h defines `POST /v1/provider-webhooks/{profile}` as signature verification, tenant/job binding, and inbox de-duplication. Delivery is at-least-once; intent/receipt/outbox provide idempotent business effects, and HTTP is not claimed to be exactly-once. A paid submit that times out becomes `submit_unknown` and must not be re-POSTed as an ordinary retry; the reservation stays reserved and is not treated as spent or reusable. s10d requires de-duplication on both `providerEventId` inbox identity and `logicalCallId` terminal receipt: different event IDs for the same job must not ingest another candidate or bill again; the same event ID with a different hash is `IMMUTABLE_ID_CONFLICT`; a conflicting bill amount opens an accounting discrepancy and must not be silently overwritten. Signature and tenant/job binding are checked before settle. After cancel, already-incurred fees still settle, but a stale-epoch payload is quarantined and must not hang on the current project. An original callback from an old plan generation must not publish directly onto the new plan, and a candidate is not auto-attached to the timeline. The work-item acceptance further requires that 100 out-of-order or duplicate callbacks settle once.

This increment officializes that bound as a DEV-PURE compiler in `packages/studio_gateway/lib/callback_inbox.dart`, exported alongside the existing I-051 GatewayPorts surface (which is not rewritten):

- `submit` POSTs at most once per idempotency key. `markUnknown` then `repostUnknown` is `UNKNOWN_NO_BLIND_RETRY`. `poll` is allowed and does not increment `postCount`. The reservation is not spent and is not reusable.
- `ingest` of 100 shuffled duplicate or sibling events for one job yields `settleCount=1`, `candidateCount=1`, and a single settlement amount. A repeated `providerEventId` with a different payload hash is `IMMUTABLE_ID_CONFLICT`. A later event with a conflicting amount is `ACCOUNTING_MISMATCH` and does not overwrite the settled amount.
- An invalid webhook signature is `SIGNATURE_INVALID`. A tenant or job-binding mismatch is `TENANT_DENIED`, checked before settle. A stale `cancelEpoch` or an old plan-generation callback still settles an incurred fee once, increments `quarantinedCount`, does not publish onto the current plan, does not attach to the timeline, and does not promise a refund.
- `realGpuWorker`, `workflowCoordinatorInvented`, `v021Claimed`, and `paidApiCalled` stay false. Compile does not write a project document.

A real worker process, GPU executor, phone-disconnect takeover, fair multi-tenant scheduler, and V-021 qualification remain unopened.

## Consequences

The first I-052 leftover acceptance items (100 out-of-order or duplicate callbacks settle and ingest once, and unknown status does not re-POST) are officialized at this callback-inbox bound. Device-disconnect durability, multi-tenant fairness, and the V-021 serverless gate remain unopened, so I-052 stays partial and is not marked complete. 87-task counts become 0 complete / 52 partial / 22 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i052-callback-inbox/`.

## Follow-up

Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial work from the four planning documents. Do not invent a WorkflowCoordinator or a real GPU worker. Do not claim V-021. Do not re-qualify I-052, I-040, I-033, I-051, I-032, I-057, or I-037 leftovers. Do not start I-055 unless a narrow already-specified LocaleCatalog/semantics slice is required. Do not start I-035 or claim a V-020 precision/recall achievement. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not invent skill training or claim a model improvement. Do not invent a payment vendor or claim V-022. Do not claim a 60s WebCodecs/OPFS roundtrip or pin a V-007 production lock. Do not start quote/apply, paid generation, or SQL `vertical.v1` unless a narrowly specified protocol slice is already written. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, or I-052 complete.
