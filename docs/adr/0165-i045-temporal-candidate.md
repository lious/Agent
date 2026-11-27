# ADR 0165 — Official I-045 lock, inferred-region, and no-auto-accept protocol

## Status

Accepted for Increment 2.66 as the first I-045 slice. I-045 moves planned → partial and is not marked complete. The V-012=temporal-inpaint gate is not met and is not claimed; V-012 stays blocked. This increment does not invent a temporal inpaint engine, a real tracker, auto-segmentation, optical-flow, or a real inpainting engine. V-011 is not claimed. I-044 and I-043 leftovers are not re-qualified. I-061 stays planned; V-026=gltf-preview and preview consistency are not claimed. I-039 and I-038 leftovers are not re-qualified. I-035 stays planned. I-055 is not started. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, and I-044 stay partial and are not marked complete. V-009, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. Optical-flow and V-003 stay unclaimed.

## Decision

s8q requires that a `VideoEraseCandidate` keep source/mask/fill provenance, mark observed versus inferred coverage, and not claim inferred pixels as recovered fact. Locked trim and captions must not move. The original audio is retained independently. An interrupt resumes from the last valid chunk rather than restarting. Overlap QA that fails, or a ten-segment temporal check that has not met V-012, must not auto-accept. Frame-by-frame LaMa must not be labeled a stable temporal fill. A missing qualified pack stays waiting adaptation and must not silently substitute a classic hole-fill or a cloud service. A near-static reconstruction alternative needs explicit user consent. Overwriting a locked mask is refused.

This increment officializes that bound as a DEV-PURE compiler in `packages/studio_video_tools/lib/erase/video_erase_candidate.dart`, exported alongside the existing I-044 MaskTrackService (which is not rewritten):

- `preview` reports locked mask, caption, and trim unchanged, keeps the original hash and audio, and does not auto-accept or write user layers. Overwriting a locked mask is `MASK_LOCK_CONFLICT`. Overwriting a locked caption or moving a locked trim is `FIELD_LOCKED`.
- `resumeAfterInterrupt` continues from `lastValidChunkIndex`, not from chunk 0. Inferred region indexes are marked, and `inferredBackgroundIsFact` stays false. `lateCancel` does not write user layers or delete the original.
- `autoAcceptTenSegments` without `v012Met` is `V012_GATE_UNMET`. Claiming frame-wise LaMa as a stable temporal fill, or relabeling classic fill as temporal, is `UNSUPPORTED_EDIT_TECHNIQUE`. A missing qualified pack is `MODEL_ABI_UNVERIFIED`. Near-static reconstruction without consent is `APPROVAL_REQUIRED`. `temporalInpaintEngineInvented`, `v012Claimed`, and `v011Claimed` stay false.

A ProPainter / LaMa / E2FGVI runtime, V-012 qualification, and automatic NLE attach remain unopened.

## Consequences

The first I-045 leftover acceptance items (locked mask and captions stay unchanged, an interrupt resumes from the last valid chunk, inferred regions are marked, and ten-segment temporal QA must not auto-accept unless V-012 is met) are officialized at this VideoEraseSession bound. The V-012=temporal-inpaint gate and a real temporal inpaint engine remain unopened, so I-045 stays partial and is not marked complete. 87-task counts become 0 complete / 57 partial / 17 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i045-temporal-candidate/`.

## Follow-up

Next honest Linux/Web increment: prefer a narrowly specified I-047 stem / denoise lock protocol if it is already written and does not invent a real RNNoise/stem engine or rewrite I-046 locked captions. Otherwise pick the next still-doable planned or remaining-partial work from the four planning documents. Do not start I-061 or claim V-026=gltf-preview. Do not start I-055 unless a narrow already-specified LocaleCatalog/semantics slice is required. Do not start I-035 or claim a V-020 precision/recall achievement. Do not invent a limiter, a temporal inpaint engine, a real tracker, or auto-segmentation. Do not claim V-011 or V-012. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not re-qualify I-045, I-044, I-043, I-039, or I-038 leftovers. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, or I-045 complete.
