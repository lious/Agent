# ADR 0199 — Official s4 generated output is only a raster/video candidate (I-040 leftover)

## Status

Accepted for Increment 3.00 as a distinct already-specified s4 leftover on I-040: generated model output is only a raster or video candidate; a prompt must not turn an object inside an existing MP4 into a real independently editable layer; canvas text, captions, and brand logo stay deterministic layers. I-040 stays partial and is not marked complete. An inpainting, tracking, auto-segmentation, or optical-flow runtime is not invented. Increment 2.57 VideoGenerationProvider is not re-qualified and is not rewritten. I-043, I-044, and I-045 leftovers are not re-qualified. A WorkflowCoordinator and paid generation are not started. No paid API is called. Quote/apply is not started. Increments 2.74–2.99 already-landed slices are not re-qualified. Frozen I-008 suites, Increment 2.96 StillImageClipAdmission, Increment 2.98 document semantics, and Increment 2.99 local write-path repair are not rewritten. A FrameLease is not invented, and a V-003 measurement is not claimed. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s4 states that canvas text, captions, and brand logo remain deterministic layers, and that generated model output is only a raster or video candidate and must not, via a prompt, turn an object inside an existing MP4 into a real independently editable layer.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_generated_layer_probe/lib/generated_output_admission.dart`:

- A `raster` or `video` candidate is admitted (`editableObjectLayer=false`).
- Prompt-extracting an object from an existing MP4 into an independently editable layer is `PROMPT_OBJECT_LAYER_FORBIDDEN`.
- A claimed generated kind other than a raster or video candidate is `GENERATED_OUTPUT_NOT_CANDIDATE`.
- Replacing a deterministic canvas-text, caption, or brand-logo layer is `DETERMINISTIC_LAYER_REQUIRED`.
- This is not an inpainting, tracking, or segmentation engine, and not a rewrite of Increment 2.57 “insert as an editable clip rather than a flat MP4 only”.
- `inpaintingInvented`, `trackerInvented`, `autoSegmentationInvented`, `opticalFlowInvented`, `i043Requalified`, `i044Requalified`, `i045Requalified`, `i040ProviderRequalified`, `workflowCoordinatorInvented`, `paidGenerationStarted`, and `paidApiCalled` stay false.

A generation runtime remains unopened. `tools/spikes/generated_output_candidate/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s4 generated-output candidate bound is officialized at this admission. Real provider wiring and V-019 stay unclaimed, so I-040 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i040-generated-output-candidate/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this generated-output admission, Increment 2.57 VideoGenerationProvider, or I-043/I-044/I-045. Do not invent an inpainting, tracking, or segmentation engine, and do not start paid generation or a WorkflowCoordinator.
