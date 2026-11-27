# ADR 0168 — Official V-006 color-pipeline admission and no-auto-accept protocol

## Status

Accepted for Increment 2.69 as the first V-006 slice. V-006 moves planned → partial and is not marked complete. The V-006=advanced-color numeric (CPU/GPU normalized error ≤0.002) and appearance qualifications are not met and are not claimed. This increment does not invent a real HDR/LUT runtime. I-059 stays planned until V-006=advanced-color is honestly met; `startI059` without the gate is `V006_GATE_UNMET`. I-049 leftovers are not re-qualified (sentence split, phoneme correction, 24k concat, invalidation, and locks were already officialized; real TTS inference stays unopened). No TTS or clone engine is invented. V-014 and V-015 stay unclaimed / blocked as before. I-048, I-047, I-046, I-026, and I-025 leftovers are not re-qualified. I-061 stays planned; V-026=gltf-preview and preview consistency are not claimed. I-035 stays planned. I-055 is not started. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, and I-048 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. V-003 stays unclaimed. Optical-flow stays unclaimed.

## Decision

s4 and the V-006 work item require that HLG/PQ/BT.2020 inputs keep their color metadata and sample range. A missing transfer or primaries interpretation must be requested before work continues. HDR→SDR must not silently tonemap or clip to 8-bit; a tone-map operator needs user confirmation and a pinned LUT version. P1 does not promise HDR delivery. Without an HDR display, only numeric verification is allowed; appearance must not be marked qualified. Untested HDR publish is refused. A failed or unqualified path keeps the SDR main line and the original intact. Missing capability keeps original parameters read-only. The ≤0.002 linear CPU/GPU error target is a gate, not a default accept. I-059 starts only after V-006=advanced-color is honestly met.

This increment officializes that bound as a DEV-PURE compiler in a new workspace package `packages/studio_color_probe`, entry file `lib/color_pipeline_admission.dart`. `tools/spikes/hdr/README.md` points at this admission. `run_probe.py` is not opened. I-059's native color pipeline is not started.

- `preview` reports PQ / BT.2020 / limited metadata and range preserved, the original hash unchanged, appearance not qualified, and numeric-only when no HDR display is present. Missing metadata is `METADATA_INTERPRETATION_REQUIRED`.
- Dropping metadata is `METADATA_NOT_PRESERVED`. Dropping range is `RANGE_NOT_PRESERVED`. Silently clipping HDR to 8-bit is `UNSUPPORTED_EDIT_TECHNIQUE`.
- Claiming appearance qualified is `APPEARANCE_UNQUALIFIED`. Untested HDR publish is `HDR_PUBLISH_UNTESTED`.
- Silent tonemap to SDR is `TONEMAP_CONFIRMATION_REQUIRED`. Mutating original params while the capability is missing is `FIELD_LOCKED`.
- `autoAcceptNumericGate`, claiming a PQ card is not grey-washed, and starting I-059 without `v006Met` are `V006_GATE_UNMET`. `hdrRuntimeInvented`, `lutRuntimeInvented`, `v006Claimed`, and `i059Started` stay false.

A real HDR/LUT runtime, a measured ≤0.002 error qualification, an appearance qualification, and I-059 remain unopened.

## Consequences

The first V-006 leftover acceptance items (metadata and range are preserved; without an HDR display, verification is numeric only and appearance is not claimed; untested HDR publish is refused; silent tonemap is refused) are officialized at this ColorPipelineAdmission bound. The V-006=advanced-color numeric and appearance gates remain unmet, so V-006 stays partial and is not marked complete. I-059 stays planned. 87-task counts become 0 complete / 60 partial / 14 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/v006-color-pipeline/`.

## Follow-up

Do not start I-059 until V-006=advanced-color numeric and appearance qualifications are honestly met. Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial work from the four planning documents that is not already officialized and does not invent a deferred runtime. Do not re-qualify I-049, I-050, I-028, I-042, or V-006 leftovers. Do not invent a real TTS, clone, SR/denoise, RNNoise, or stem engine. Do not invent a limiter (V-024 / I-060 stay closed). Do not start I-061 or claim V-026=gltf-preview. Do not start I-055 unless a narrow already-specified LocaleCatalog/semantics slice is required. Do not start I-035 or claim a V-020 precision/recall achievement. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not claim I-016–I-019 hardware ports. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, or V-006 complete.
