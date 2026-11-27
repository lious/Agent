# ADR 0164 — Official I-044 source-PTS, cut-reset, and locked-keyframe protocol

## Status

Accepted for Increment 2.65 as the first I-044 slice. I-044 moves planned → partial and is not marked complete. The V-012=tracking gate is not met and is not claimed; V-012 stays blocked. This increment does not invent a real tracker, auto-segmentation, or optical-flow interpolation. I-045 stays planned. I-043 and I-026 leftovers are not re-qualified; V-011 is not claimed. I-061 stays planned; V-026=gltf-preview and preview consistency are not claimed. I-039 and I-038 leftovers are not re-qualified. I-035 stays planned. I-055 is not started. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, and I-043 stay partial and are not marked complete. V-009, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. Optical-flow and V-003 stay unclaimed.

## Decision

s8q requires that `FrameMaskRef` fix the source blob/version, a rational source PTS, `decodeIndex`, and `frameHash`. VFR uses the decoded PTS map; duplicate PTS values are disambiguated by `decodeIndex`. A timeline trim does not change the source index. Retime goes through a TimeMap: at 2× speed, timeline 0.05s is source 0.1s, and `floor(0.05×30)` must not be used to pick a mask. Optical-flow interpolation or a complex remap without same-source mask interpolation is `MASK_RETIME_INTERPOLATION_UNSUPPORTED`. A confirmed cut clears memory and does not inherit object identity across the shot; an unconfirmed cut is only a candidate. A manual keyframe correction creates a new mask version and `correctionEpoch`, locks that frame, and retraces only to the next locked anchor or shot boundary. It must not rewrite the correction frame or locked tiles. Already accepted NLE media is retained. Overlapping retrack sides are not simply averaged. A lost, occluded, or shot-changed object becomes `unreviewed` or `lost` and must move to `waitingCorrection`; an empty mask is not "the object is gone"; auto-erase stops. A bbox-only tracker is not a precise mask. Tracker kind (bbox, flow-assisted, memory) must be labeled honestly, and manual corrections are not overwritten.

This increment officializes that bound as a DEV-PURE compiler in `packages/studio_video_tools/lib/tracking/mask_track.dart`:

- `lookupSource` maps timeline time through the TimeMap to source PTS. Official 2× speed `1/20` s of timeline resolves to source `1/10` s / decode index 2. Looking up by edited frame number or a constant-fps guess is `UNSUPPORTED_EDIT_TECHNIQUE`. `interpolateRetime` is `MASK_RETIME_INTERPOLATION_UNSUPPORTED`. Trim does not change `pts` or `decodeIndex`.
- `confirmCut` clears memory. Placing a post-cut frame with `identityFromPreviousShot` is `UNSUPPORTED_EDIT_TECHNIQUE`. `correct` locks the keyframe, invalidates only the open block up to the next lock or confirmed cut, keeps accepted media, and does not average overlapping sides. Correcting a locked keyframe is `MASK_LOCK_CONFLICT`. A stale `correctionEpoch` is `CORRECTION_EPOCH_STALE`.
- `markLost` moves the frame to `waitingCorrection` and stops auto-erase. Treating an empty mask as gone is `UNSUPPORTED_EDIT_TECHNIQUE`. `bboxOnlyIsPreciseMask`, `realTrackerInvented`, `autoSegmentationInvented`, `opticalFlowInvented`, and `v012Claimed` stay false.

A SAM2 / DIS / optical-flow runtime, a correction workbench, and V-012 qualification remain unopened.

## Consequences

The first I-044 leftover acceptance items (under VFR and retiming every mask references source PTS, a confirmed cut resets, a keyframe correction only invalidates related blocks, and a lost object becomes `waitingCorrection`) are officialized at this MaskTrackService bound. The V-012=tracking gate and a real tracker remain unopened, so I-044 stays partial and is not marked complete. I-045 stays planned. 87-task counts become 0 complete / 56 partial / 18 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i044-source-pts-masks/`.

## Follow-up

Next honest Linux/Web increment: prefer a narrowly specified I-045 lock / inferred-region / no-auto-accept protocol if it is already written and does not invent a temporal inpaint engine or claim V-012. Otherwise pick the next still-doable planned or remaining-partial work from the four planning documents. Do not start I-061 or claim V-026=gltf-preview. Do not start I-055 unless a narrow already-specified LocaleCatalog/semantics slice is required. Do not start I-035 or claim a V-020 precision/recall achievement. Do not invent a limiter, a real tracker, auto-segmentation, or a real inpainting engine. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not re-qualify I-044, I-043, I-026, I-039, or I-038 leftovers. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, or I-044 complete.
