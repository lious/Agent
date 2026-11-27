# ADR 0237 — Official s10 a preset script is not a real LLM, and offline mode must disclose that cloud video generation is unsupported

## Status

Accepted for Increment 3.38 as a distinct already-specified s10 leftover, preferred after Increment 3.37 harness-context work: a preset script must not be disguised as a real LLM; if a model is not installed, manual editing must still be possible; offline mode must clearly show that cloud video generation is unsupported; and a 1.7B text model must not be pretended to generate video. These sentences sit in the s10 纯离线Profile paragraph, not in the Provider Port / KV-migration / implicit-context sentences officialized in Increment 3.37. This is not an I-013 packing or archive slice, not an I-002 measurement claim, not a license leftover already officialized in Increments 3.32 or 3.35, not a session-navigation leftover already officialized in Increment 3.36, and not a model-context leftover already officialized in Increment 3.37. I-030 remainingAcceptance had no prior officialization note in that field and is not used to rewrite the already-official StreamAssembler / half-tool-call / ToolReady bound in remainingScope; an offline-capability note is added only. I-034 remainingAcceptance wording (including the Increment 3.37 append and the unclaimed two-model measurement label) is not rewritten. I-040 task-status is not rewritten. Increment 3.37 ModelContextAdmission, I-030 StreamAssembler, I-031 private-reasoning journal omission, the already-official untrusted-data-is-not-a-system-instruction bound, the already-official I-034 AgentMailbox protocol, Increment 3.00 GeneratedOutputAdmission, and Increment 2.57 VideoGenerationProvider are not re-qualified. A real LLM, video-generation runtime, I2V runtime, executable-script privilege path, durable mailbox, or ContextCompiler is not invented. A real two-model I-034 handoff is not claimed. V-019 is not claimed. Quote/apply is not started. No paid API is called. I-013, I-002, and I-027 remainingAcceptance wording is not rewritten. I-033, I-058, I-053, I-004, I-005, I-029, and I-040 task-status are not rewritten. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. I-002, I-013, I-027, I-034, I-030, I-011, I-014, I-012, I-020, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s10 states that a preset script must not be disguised as a real LLM, that manual editing must still be possible when a model is not installed, that offline mode must clearly show cloud video generation is unsupported, and that a 1.7B text model must not be pretended to generate video. Increment 3.37’s provider-port / KV / implicit-context bounds are not re-qualified.

This increment officializes only those offline-capability disclosure bounds as a DEV-PURE compiler at the official entry path `packages/studio_offline_capability_probe/lib/offline_capability_admission.dart`:

- `offlineCapability` is admitted (`presetScriptDisguisedAsLlm=false`, `manualEditBlocked=false`, `cloudVideoDisclosedUnavailable=true`, `textModelClaimedAsVideo=false`).
- An unknown kind is `OFFLINE_CAPABILITY_KIND_UNKNOWN`.
- Disguising a preset script as a real LLM is `PRESET_SCRIPT_NOT_LLM`.
- Blocking manual editing because a model is missing is `MODEL_MISSING_BLOCKS_MANUAL_EDIT`.
- Failing to disclose that cloud video generation is unsupported offline is `OFFLINE_CLOUD_VIDEO_UNDISCLOSED`.
- Pretending a text model generates video is `TEXT_MODEL_NOT_VIDEO`.
- `realLlmInvented`, `videoGenerationInvented`, `modelContextRequalified`, `streamAssemblerRequalified`, `generatedOutputRequalified`, `videoProviderRequalified`, `i034HandoffClaimed`, `v019Claimed`, `quoteApplyStarted`, `paidApiCalled`, and `executableScriptPathInvented` stay false.

`tools/spikes/offline_capability/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing I-030 StreamAssembler, Increment 3.37, Increment 3.00, and Increment 2.57 suites are not rewritten.

## Consequences

The s10 offline-capability disclosure bounds are officialized at this admission. I-030 remains partial; this increment does not mark I-030 complete and does not invent a real llama.cpp runtime or a video-generation runtime. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i030-offline-capability/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this offline-capability admission, Increment 3.37 ModelContextAdmission, I-030 StreamAssembler, Increment 3.00 GeneratedOutputAdmission, or Increment 2.57 VideoGenerationProvider. Do not invent a real LLM or video-generation runtime. Do not claim V-019 or a real two-model I-034 handoff. Do not re-qualify Increments 3.32 or 3.35 license admissions, or Increment 3.36 SessionNavigationAdmission. Do not claim the remaining I-002 measurement labels. Do not return to the exhausted I-013 packing / session / omitted-history cluster or Increments 3.27–3.30 archive-bound slices. Do not invent I-013 job archival. Do not start quote/apply or paid APIs. Remaining s9 sentences such as “删除聊天不删除时间线已引用的素材,” “project删除与session删除不同,” and “generation完成只发布candidate.ready，不执行accept” stay unofficial and should be taken only if they can be bounded without re-qualifying I-004, I-029, I-040, ADR 0018, or the recycle-bin path.
