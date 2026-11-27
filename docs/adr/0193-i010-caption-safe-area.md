# ADR 0193 — Official s4 caption safe-area protocol (I-010 leftover)

## Status

Accepted for Increment 2.94 as a distinct already-specified s4 leftover on I-010: captions stay inside the inner rectangle defined by `brandPolicy.safeArea` insets, and therefore avoid the unsafe margin bands. I-010 stays partial and is not marked complete. A text shaper is not invented. I-010 sidecar and font-fallback work are not re-qualified. Source-interval crop and MP4/preview burn-in stay closed. Locked captions are not overwritten. Deterministic font shaping and lossless arbitrary ASS effect roundtrip stay unclaimed. Hard dependency I-005 remains partial. Increment 2.93 DownmixAdmission, I-009 mix, Increment 2.83 varispeed-and-pitch, and Increment 2.85 recording-drift are not re-qualified. Increment 2.92 PreviewExportConsistencyAdmission and Increment 2.90 RenderRecipeAdmission are not re-qualified. A FrameLease is not invented, and a V-003 measurement is not claimed. Increments 2.74–2.93 already-landed slices are not re-qualified. CompatibilityStore / ModelLease are not started. I-061, I-055, I-059, I-060, I-035, and V-024 stay planned or closed as already recorded. I-022, V-006, I-021, I-004, I-023, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s4 “textStyle / caption” requires `字幕避开safeArea`. `brandPolicy.safeArea` is schema-only: four numbers in `[0, 1]`, with no axis labels in the schema. The only project fixture (`fixtures/project/semantic-rich.json`) uses `[0, 0, 0, 0]`. That value is a coherent default only if the tuple is edge insets (zero inset means the full canvas is usable). Reading it as an inner `[left, top, right, bottom]` rectangle would make the fixture a degenerate empty region. Cross-spec language treats the caption safe area as the region reserved for captions (`构图为{captionSafeArea}留空`, `为后期文字保留{{textSafeArea}}`, s12d “字幕安全区”), not as a solid forbidden rectangle that captions must stay outside of.

This increment therefore officializes an honest inset reading: `brandPolicy.safeArea` is normalized edge insets `[left, top, right, bottom]`. The inner safe rectangle is `(left, top, 1-right, 1-bottom)`. “字幕避开safeArea” means captions must avoid the unsafe margin bands defined by those insets — the declared layout box must stay inside the inner rectangle. Touching an inner edge is allowed. The admission does not invent canvas-pixel `layoutRect` packing (the schema does not specify `xywh` versus `ltrb`); the caller supplies a normalized `[left, top, right, bottom]` layout box. This is not a glyph-ink or line-break measurement.

The official entry path is `packages/studio_caption_safe_area_probe/lib/caption_safe_area_admission.dart`:

- Zero insets admit a full-canvas layout. A box inside nonzero insets is admitted (`stayedInsideSafeArea=true`).
- A layout that enters an inset margin is `SAFE_AREA_VIOLATION`.
- Insets that are not four finite values in `[0, 1]`, or that leave a non-positive inner width or height, are `SAFE_AREA_INVALID`.
- A non-finite or inverted layout box is `LAYOUT_RECT_INVALID`.
- `shaperInvented`, `i010SidecarRequalified`, `fontFallbackRequalified`, `sourceIntervalCropOpened`, `burnInOpened`, `lockedCaptionsOverwritten`, and `paidApiCalled` stay false.

A text shaper remains unopened. `tools/spikes/caption_safe_area/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s4 “字幕避开safeArea” bound is officialized at this layout-box admission. Source-interval crop, MP4/preview burn-in, and deterministic shaping stay closed or unclaimed, so I-010 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i010-caption-safe-area/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this caption safe-area admission or I-010 sidecar/font-fallback work. Do not invent a text shaper, and do not open source-interval crop or MP4/preview burn-in. Do not claim deterministic shaping. I-005 remains a hard dependency, so I-010 must not be marked complete.
