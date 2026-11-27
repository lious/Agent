# ADR 0163 — Official I-043 selection geometry, locked masks, and erase-layer undo

## Status

Accepted for Increment 2.64 as the first I-043 slice. I-043 moves planned → partial and is not marked complete. The V-011=image-erase gate is not met and is not claimed. This increment does not invent auto-segmentation or a real inpainting engine. It is not a rewrite of I-026 ImageDocument / template / graphics-library tests. I-044 and I-045 stay planned. I-061 stays planned; V-026=gltf-preview and preview consistency are not claimed. I-039 and I-038 leftovers are not re-qualified. I-035 stays planned. I-055 is not started. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, and V-026 stay partial and are not marked complete. V-009, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called.

## Decision

s8p requires that prompts record upright source coordinates, not screen coordinates, and that pixel centers are `(x+0.5, y+0.5)`. The official ROI `(100,50,1000,500)` maps source `(600,300)` to model `(512,256)` after a long-side-1024 resize and bottom-right pad; the inverse uses `rw/newW` and `rh/newH` separately. `rawToUpright` carries EXIF/container orientation, and an eight-orientation plus crop-padding round-trip must stay within 0.5 source pixels. A locked tile must not be overwritten by later inference (`MASK_LOCK_CONFLICT`). A changed source hash is `MASK_SOURCE_CHANGED`. Accepting an erase candidate uses existing layer commands in one transaction; undo removes the new layer and restores prior references without deleting the original. A late cancel only quarantines and cannot write user layers. "Remove and fill" is distinct from "alpha only"; the latter knocks alpha and does not call inpaint. Text selection such as "选红杯" requires a real grounder; an uninstalled grounder must ask the user to click or box, and LLM-guessed boxes are not grounding. A missing smart pack must not be silently relabeled as classic inpaint. A binary mask is not alpha matting, and a confidence value is not physical transparency. Invisible background is inference, not a recovered fact.

This increment officializes that bound as a DEV-PURE compiler in `packages/studio_image_editor/lib/erase/erase_layer.dart`, exported alongside the existing I-026 surfaces (which are not rewritten):

- `CoordinateMapper` implements the official ROI golden and maps all eight EXIF orientations through crop padding and back with error ≤ 0.5 source pixels.
- `EraseLayerSession.refine` refuses a locked-tile overwrite (`MASK_LOCK_CONFLICT`) and a changed source hash (`MASK_SOURCE_CHANGED`). `accept(alphaOnly)` attaches a new layer in one transaction, does not call inpaint, and leaves the original hash unchanged. `undo` removes the new layer and does not delete the original. `lateCancel` quarantines with `userLayersWritten=0`.
- Text grounding without an installed grounder, and treating LLM boxes as grounding, are `GROUNDING_UNAVAILABLE`. Claiming a binary mask as matting, or confidence as physical alpha, is `UNSUPPORTED_EDIT_TECHNIQUE`. Relabeling unverified classic inpaint as intelligent is `UNSUPPORTED_EDIT_TECHNIQUE`. An unverified fill pack is `MODEL_ABI_UNVERIFIED`. `autoSegmentationInvented`, `inpaintEngineInvented`, and `v011Claimed` stay false.

A MobileSAM/LaMa/OpenCV runtime, grounding pack, and V-011 qualification remain unopened.

## Consequences

The first I-043 leftover acceptance items (eight-orientation / crop-padding round-trip error ≤ 0.5 source pixels, the original is unchanged, a locked mask is not overwritten by later inference, and accept is one undoable transaction) are officialized at this EraseLayer bound. The V-011=image-erase gate, a real inpaint/SAM runtime, and a selection UI remain unopened, so I-043 stays partial and is not marked complete. 87-task counts become 0 complete / 55 partial / 19 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i043-selection-locks/`.

## Follow-up

Next honest Linux/Web increment: prefer a narrowly specified I-044 source-PTS / cut-reset / locked-keyframe protocol if it is already written and does not invent a real tracker or auto-segmentation. Otherwise pick the next still-doable planned or remaining-partial work from the four planning documents. Do not start I-061 or claim V-026=gltf-preview. Do not start I-055 unless a narrow already-specified LocaleCatalog/semantics slice is required. Do not start I-035 or claim a V-020 precision/recall achievement. Do not invent a limiter, auto-segmentation, or a real inpainting engine. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not re-qualify I-043, I-026, I-039, or I-038 leftovers. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, or I-043 complete.
