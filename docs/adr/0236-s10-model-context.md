# ADR 0236 — Official s10 provider ports do not own the session database, a model switch must not migrate KV or vendor reasoning, and agents must not share implicit context

## Status

Accepted for Increment 3.37 as a distinct already-specified s10 leftover, looked up more broadly after I-013 packing / archive slices, I-002 measurement claims, Increments 3.32 / 3.35 license leftovers, and Increment 3.36 session-navigation: a provider port accepts only CanonicalContext and must not own the session database; after a model switch, system/tool formats and token counts must be re-rendered and KV cache or vendor-proprietary reasoning blocks must not be migrated; and two agents may run different models but must not share implicit context even when both are online. This is not an I-013 packing or archive slice, not an I-002 measurement claim, not a license leftover already officialized in Increments 3.32 or 3.35, and not a session-navigation leftover already officialized in Increment 3.36. Existing I-034 remainingAcceptance wording (`两个不同modelId/权重包在同案例有真实记录（仅同底模改温度/量化不算）。`) is kept at the start and is not silently rewritten or cleared; a harness-context note is appended only. The I-034 two-model measurement label stays listed and unclaimed; this increment does not claim a real two-model handoff and does not invent a durable mailbox schema or a ContextCompiler runtime. I-030 StreamAssembler (half tool-call never executed) and I-031 private-reasoning journal omission are not re-qualified; “不搬供应商专有reasoning块” is a model-switch migration bound, not a journal-persistence re-qualification. I-013, I-002, and I-027 remainingAcceptance wording is not rewritten. I-033, I-058, I-053, I-004, I-005, I-029, and I-040 task-status are not rewritten. Increments 3.31–3.36 already-landed slices are not re-qualified. Quote/apply is not started. No paid API is called. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. I-002, I-013, I-027, I-011, I-014, I-012, I-020, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, I-034, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s10 states that a Provider Port accepts only CanonicalContext and does not own the Session database; that after a model switch the system/tool format and token counts are re-rendered and KV or vendor-proprietary reasoning blocks are not migrated; and that two agents may run different models and must not share implicit context even when both are online. Nearby s10 sentences already officialized elsewhere (half JSON is not ToolReady / I-030, untrusted data is not a system instruction, private reasoning is not journaled / I-031) are not re-qualified. “不能把预设脚本伪装成真实LLM” and “离线不支持云视频生成必须明确显示” are not officialized here.

This increment officializes only those harness-context bounds as a DEV-PURE compiler at the official entry path `packages/studio_model_context_probe/lib/model_context_admission.dart`:

- `harnessContext` is admitted (`providerOwnsSessionDatabase=false`, `kvMigrated=false`, `vendorReasoningMigrated=false`, `implicitContextShared=false`, `formatsRerendered=true`).
- An unknown kind is `MODEL_CONTEXT_KIND_UNKNOWN`.
- A provider port that owns the session database is `PROVIDER_PORT_NOT_SESSION_DB`.
- Skipping format/token re-render after a model switch is `FORMATS_NOT_RERENDERED`.
- Migrating a KV cache is `KV_CACHE_NOT_MIGRATED`.
- Migrating vendor-proprietary reasoning blocks is `VENDOR_REASONING_NOT_MIGRATED`.
- Sharing implicit context across agents is `IMPLICIT_CONTEXT_NOT_SHARED`.
- `i034HandoffClaimed`, `mailboxInvented`, `contextCompilerInvented`, `i030Requalified`, `i031Requalified`, `licenseExecutionRequalified`, `licenseProvenanceRequalified`, `sessionNavigationRequalified`, `quoteApplyStarted`, and `paidApiCalled` stay false.

`tools/spikes/model_context/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing I-030, I-031, and I-034 AgentMailbox suites are not rewritten.

## Consequences

The s10 harness-context independence bounds are officialized at this admission. I-034 remains partial; this increment does not mark I-034 complete and does not claim a real two-model handoff. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i034-model-context/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this model-context admission, I-030, I-031, or the already-official I-034 AgentMailbox protocol. Do not claim a real two-model I-034 handoff or invent a durable mailbox or ContextCompiler runtime. Do not re-qualify Increments 3.32 or 3.35 license admissions, or Increment 3.36 SessionNavigationAdmission. Do not claim the remaining I-002 measurement labels. Do not return to the exhausted I-013 packing / session / omitted-history cluster or Increments 3.27–3.30 archive-bound slices. Do not invent I-013 job archival. Do not start quote/apply or paid APIs. Remaining s10 sentences such as “不能把预设脚本伪装成真实LLM” and “离线不支持云视频生成必须明确显示，不假装能用1.7B文本模型生成视频” stay unofficial and should be taken only if they can be bounded without inventing a real LLM or video-generation runtime.
