# ADR 0239 — Official s11 cancelling one shot must not cancel the others

## Status

Accepted for Increment 3.40 as a distinct already-specified s11 leftover, looked up more broadly after I-013 packing / archive slices, I-002 measurement claims, Increments 3.32 / 3.35 license leftovers, Increment 3.36 session-navigation, Increment 3.39 delete-kind, and Increments 3.37 / 3.38 s10 leftovers: cancelling one shot's generation job must not cancel the other shots' jobs. This sentence sits in the s11 三镜异步生成 row, not in the session-navigation sentences officialized in Increment 3.36 and not in the delete-kind sentences officialized in Increment 3.39. This is not an I-013 packing or archive slice, not an I-002 measurement claim, not a license leftover already officialized in Increments 3.32 or 3.35, not a session-navigation leftover already officialized in Increment 3.36, not a delete-kind leftover already officialized in Increment 3.39, and not a model-context or offline-capability leftover already officialized in Increments 3.37 or 3.38. I-031 remainingAcceptance was previously empty (timeout / steer / queue already officialized into remainingScope) and now records only this officialization. Existing I-031 remainingScope wording (turn/run/step/job, steer/排队/取消, middleware fail-closed, 不保存私密推理链, timeout and steer/queue/job interfaces officialized, I-029 / I-003 / durable outbox wiring still open) is kept at the start and is only appended. I-031 private-reasoning journal omission is not re-qualified. Increment 3.04 JobCancelAdmission is not re-qualified: that bound is that cancelling an export or cloud generation must not undo already-completed user edits, which is distinct from cancelling one sibling job not cancelling the others. Increment 3.36 SessionNavigationAdmission, Increment 3.39 DeleteKindAdmission, and ADR 0028 are not re-qualified. I-005 and I-040 task-status are not rewritten. “usage独立对账,” “先完成jB不自动替换画面,” and “generation完成只发布candidate.ready，不执行accept” are not officialized here. A WorkflowCoordinator is not invented, and no paid API is called. I-013, I-002, I-027, I-030, and I-034 remainingAcceptance wording is not rewritten. I-033, I-058, I-053, I-004, I-005, I-029, and I-040 task-status are not rewritten. Increments 3.31–3.39 already-landed slices are not re-qualified. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. I-002, I-013, I-027, I-034, I-030, I-011, I-014, I-012, I-020, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. I-031 stays partial and is not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s11 states that cancelling one of three asynchronous generation jobs must not cancel the other two. Nearby sentences about independent usage accounting, a finished job not automatically replacing the picture, and generation complete only publishing `candidate.ready` are not taken here.

This increment officializes only that sibling-job cancel isolation as a DEV-PURE compiler at the official entry path `packages/studio_sibling_job_cancel_probe/lib/sibling_job_cancel_admission.dart`:

- `siblingJobCancel` with `cancelledJobs` equal to exactly the `cancelTarget` is admitted (`siblingJobsCancelled=false`).
- An unknown kind or empty cancel target is `SIBLING_JOB_CANCEL_KIND_UNKNOWN`.
- Cancelling any job other than the target, including cancelling the target together with a sibling, is `CANCEL_SIBLING_JOB`.
- A request that does not cancel the target and cancels no sibling is also `SIBLING_JOB_CANCEL_KIND_UNKNOWN`.
- `jobCancelRequalified`, `sessionNavigationRequalified`, `deleteKindRequalified`, `adr0028Requalified`, `i040Requalified`, `i005Rewritten`, `usageAccountingOfficialized`, `candidateReadyOfficialized`, `workflowCoordinatorInvented`, `paidApiCalled`, `privateReasoningRequalified`, `offlineCapabilityRequalified`, and `modelContextRequalified` stay false.

`tools/spikes/sibling_job_cancel/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing I-031 timeout / steer / queue suites, Increment 3.04, Increment 3.36, and Increment 3.39 suites are not rewritten.

## Consequences

The s11 sibling-job cancel isolation bound is officialized at this admission. I-031 remains partial; this increment does not mark I-031 complete and does not invent a WorkflowCoordinator, quote/apply, or a paid API path. Wiring to I-029 and a production PlanGraph, and a durable cross-device outbox, stay unopened. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i031-sibling-job-cancel/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this sibling-job-cancel admission, Increment 3.04 JobCancelAdmission, Increment 3.36 SessionNavigationAdmission, Increment 3.39 DeleteKindAdmission, or ADR 0028. Do not officialize “usage独立对账” if that would re-qualify I-033, I-042, or I-053. Do not officialize “generation完成只发布candidate.ready，不执行accept” or “先完成jB不自动替换画面” if that would re-qualify I-040. Do not re-qualify I-031 private-reasoning journal omission. Do not invent a WorkflowCoordinator or start quote/apply or paid APIs. Do not re-qualify Increments 3.32 or 3.35 license admissions, Increment 3.37 ModelContextAdmission, or Increment 3.38 OfflineCapabilityAdmission. Do not claim the remaining I-002 measurement labels. Do not return to the exhausted I-013 packing / session / omitted-history cluster or Increments 3.27–3.30 archive-bound slices. Do not invent I-013 job archival.
