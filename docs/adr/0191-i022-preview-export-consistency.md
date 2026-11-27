# ADR 0191 — Official s4 preview-export consistency protocol (I-022 leftover)

## Status

Accepted for Increment 2.92 as a distinct already-specified s4 leftover on I-022: preview and export share a fixed RenderGraph effect order; a proxy replaces only the sample source, not effect semantics; preview may drop size or display frames but must not change the color formula. I-022 stays partial and is not marked complete. A V-003 pixel, duration, or seek measurement is not claimed. A FrameLease and a muxer are not invented. This is not `PREVIEW_SCREENSHOT_NOT_EXPORT`. Increment 2.90 RenderRecipeAdmission is not re-qualified and is not rewritten. Increment 2.91 IccFirstAdmission, Increment 2.89 RotationOnceAdmission, and Increment 2.69 ColorPipelineAdmission are not re-qualified. ADR 0023 and ADR 0024 CPU consumers are not rewritten and are not re-qualified. I-024 export suites and Increment 2.72 ExportService are not rewritten. I-059 stays planned. Increments 2.74–2.91 already-landed slices are not re-qualified. CompatibilityStore / ModelLease are not started. I-061 and I-055 are not started. I-013 stays partial. I-014 stays partial. I-035 stays planned. I-022, V-006, I-021, I-004, I-023, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s4 “预览与导出一致” requires a fixed RenderGraph effect order (`decode/color → source crop/mask → transform → clip effects → track composite → caption/text → sequence output transform`); a proxy replaces only the sample source, not effect semantics; preview may drop size or display frames but must not change the color formula.

ADR 0023 and ADR 0024 already officialized related but narrower CPU-consumer bounds for static transform2d and two-source dissolve: those paths run the same native function at full source size and downsample only for display, do not transform RGBA128 proxies as the raster input, and keep transform/opacity order fixed on those legs. Those consumers are not rewritten here. This increment officializes the remaining general s4 protocol that was not a standalone admission:

- The full fixed effect order, including crop/mask, clip effects, track composite, caption/text, and sequence output transform.
- A proxy may be used as a sample-source replacement, but must not replace or skip effect semantics.
- Preview may drop size or display frames; changing the color formula is refused.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_preview_export_probe/lib/preview_export_consistency_admission.dart`:

- The official order is admitted (`effectOrderFixed=true`).
- An unknown stage is `EFFECT_ORDER_UNKNOWN`.
- A reversed, truncated, or otherwise reordered official list is `EFFECT_ORDER_INVALID`.
- A proxy that replaces effect semantics is `PROXY_REPLACES_EFFECT_SEMANTICS`.
- Changing the color formula, including when preview drops size or display frames, is `COLOR_FORMULA_CHANGED`.
- This is not a V-003 off-screen golden, pixel-tolerance, duration, or seek measurement.
- `v003Claimed`, `frameLeaseInvented`, `renderRecipeRequalified`, `iccFirstRequalified`, `rotationOnceRequalified`, `colorPipelineRequalified`, `i024Rewritten`, `muxerInvented`, `previewScreenshotAsExport`, `adr0023Requalified`, `adr0024Requalified`, and `paidApiCalled` stay false.

A renderer, muxer, and FrameLease remain unopened. `tools/spikes/preview_export_consistency/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s4 “预览与导出一致” protocol bound is officialized at this admission. V-003 tolerance sampling, free-only-after-GPU/encoder-consume, and 100-cancel no-frame-leak stay unclaimed, so I-022 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i022-preview-export-consistency/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this preview-export consistency admission or Increment 2.90 RenderRecipeAdmission. Do not invent a FrameLease, and do not claim a V-003 measurement. I-022’s remaining leftovers (V-003 tolerance sampling, free only after GPU/encoder consume, 100-cancel no frame leak) are not a clean next slice without inventing a FrameLease or claiming V-003.
