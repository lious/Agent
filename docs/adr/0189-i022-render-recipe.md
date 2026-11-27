# ADR 0189 — Official s4 same RenderRecipe for preview and final (I-022 leftover)

## Status

Accepted for Increment 2.90 as a distinct already-specified s4 leftover on I-022: preview and final use the same RenderRecipe. I-022 stays partial and is not marked complete. A V-003 measurement (60s duration ≤1 delivery frame, 20-point seek ≤1 frame, SDR patch ≤2/255) is not claimed, and V-003 stays partial. This increment does not rewrite I-024 export suites, Increment 2.72 ExportService, or `PREVIEW_SCREENSHOT_NOT_EXPORT`. A muxer and a FrameLease are not invented. Increment 2.89 RotationOnceAdmission and Increment 2.69 ColorPipelineAdmission are not re-qualified. An HDR or LUT runtime is not invented, and V-006 numeric or appearance qualification is not claimed. I-059 stays planned. Increment 2.88 ProxySourceSeekAdmission, Increment 2.84 VFR audio-duration admission, and I-021 seek/VFR/PTS suites are not re-qualified. Increment 2.87 RelinkVersionAdmission, Increment 2.86 ProxyDeliveryAdmission, Increment 2.85 recording-drift admission, Increment 2.83 varispeed-and-pitch admission, Increment 2.80 media retention, Increment 2.82 I-005 0.02s link-offset work, Increment 2.81 V-023 PressureAdmission, and Increments 2.74–2.79 are not re-qualified. CompatibilityStore / ModelLease are not started. I-061 and I-055 are not started. I-013 stays partial. I-014 stays partial. I-035 stays planned. V-006, I-021, I-004, I-023, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` is not opened as a claimed qualification.

## Decision

s4 requires that the same RenderRecipe is used for preview and final.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_render_recipe_probe/lib/render_recipe_admission.dart`:

- A matching non-empty preview and final recipe hash is admitted.
- Divergent preview and final recipe hashes are `RENDER_RECIPE_MISMATCH`.
- An empty recipe hash is `RENDER_RECIPE_REQUIRED`.
- This is not a pixel, duration, or seek measurement, and is not `PREVIEW_SCREENSHOT_NOT_EXPORT`.
- `v003Claimed`, `i024Requalified`, `rotationOnceRequalified`, `colorPipelineRequalified`, `muxerInvented`, `frameLeaseInvented`, and `paidApiCalled` stay false.

A real renderer, muxer, and FrameLease remain unopened. `tools/spikes/render_recipe/README.md` points at the Dart admission; `run_probe.py` is not opened.

## Consequences

The s4 “相同RenderRecipe用于preview/final” bound is officialized at this admission. I-022 V-003 tolerance, FrameLease, and cancel-leak leftovers stay listed, so I-022 stays partial and is not marked complete. V-003 stays unclaimed as a measurement gate. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i022-render-recipe/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this RenderRecipe admission, I-024 export suites, or Increment 2.89 rotation-once admission. Do not invent a FrameLease, and do not claim a V-003 measurement.
