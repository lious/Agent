# ADR 0200 — Official s4 ImageDocument shares the video effect path (I-026 leftover)

## Status

Accepted for Increment 3.01 as a distinct already-specified s4 leftover on I-026: ImageDocument becomes a RenderGraph node through the same color, font, mask, and EffectRegistry as video, and may be used as a static clip, an I2V first frame, or a product overlay. Images and video may not use two unrelated effect systems. I-026 stays partial and is not marked complete. An I2V runtime and an unregistered plugin are not invented. Increments 2.96–2.99 still-image work, Increment 2.97 RenderNodeGraphAdmission, Increment 3.00 GeneratedOutputAdmission, and I-026 template / graphics-library suites are not re-qualified and are not rewritten. I-004 attach, V-003 image rendering, and a Flutter widget tree are not opened. s4b referenceColor / localLight / classicComic operators are not started. Quote/apply, a WorkflowCoordinator, and paid generation are not started. No paid API is called. Increments 2.74–3.00 already-landed slices are not re-qualified. A FrameLease is not invented, and a V-003 measurement is not claimed. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, I-026, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s4 states that images and video are no longer two unrelated effect systems: ImageDocument becomes a RenderGraph node through the same color, font, mask, and EffectRegistry, and may be used as a static clip, an I2V first frame, or a product overlay.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_image_document_graph_probe/lib/image_document_graph_admission.dart`:

- An ImageDocument bound to `color`, `font`, `mask`, and `effectRegistry` is admitted in role `staticClip`, `i2vFirstFrame`, or `productOverlay` (`sharedEffectPath=true`).
- A private image-only effect path is `SEPARATE_IMAGE_EFFECT_SYSTEM`.
- A missing shared binding is `SHARED_EFFECT_PATH_REQUIRED`.
- An unknown role is `IMAGE_DOCUMENT_ROLE_UNKNOWN`.
- This does not re-qualify Increment 2.96 StillImageClipAdmission (stream identity and static 1x domain), Increment 2.97 closed-union node identity, or Increment 3.00 generated-output candidate rules.
- `i2vRuntimeInvented`, `unregisteredPluginInvented`, `stillImageClipRequalified`, `imageDocumentTemplatesRequalified`, `renderNodeRequalified`, `generatedOutputRequalified`, `inpaintingInvented`, `paidGenerationStarted`, `paidApiCalled`, and `workflowCoordinatorInvented` stay false.

An I2V generation runtime remains unopened. `tools/spikes/image_document_graph/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s4 ImageDocument shared-effect-path bound is officialized at this admission. I-004 attach, V-003 image rendering, and the Flutter widget tree stay unopened, so I-026 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i026-image-document-graph/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this ImageDocument graph admission, Increments 2.96–2.99 still-image work, Increment 2.97 RenderNodeGraphAdmission, Increment 3.00 GeneratedOutputAdmission, or I-026 template / graphics-library suites. Do not invent an I2V runtime or an unregistered plugin, and do not start s4b operators or I-004 attach.
