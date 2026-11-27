# ADR 0188 — Official s4 source-orientation-applied-once protocol (V-006 leftover)

## Status

Accepted for Increment 2.89 as a distinct already-specified s4 leftover on V-006: source orientation is applied once. V-006 stays partial and is not marked complete. V-006=advanced-color numeric (CPU/GPU normalized error ≤0.002) and appearance qualifications are not claimed. An HDR or LUT runtime is not invented. I-059 stays planned. Increment 2.69 ColorPipelineAdmission metadata/range preservation (`METADATA_NOT_PRESERVED`, `RANGE_NOT_PRESERVED`, silent 8-bit clip, tonemap confirmation, appearance qualification) is not re-qualified and `packages/studio_color_probe` is not rewritten. Increment 2.80 media retention is not re-qualified. Increment 2.88 ProxySourceSeekAdmission, Increment 2.84 VFR audio-duration admission, and I-021 seek/VFR/PTS suites are not re-qualified. `source_preview_test.dart` and `frame_proxy_test.dart` are not rewritten. Increment 2.87 RelinkVersionAdmission, Increment 2.86 ProxyDeliveryAdmission, Increment 2.85 recording-drift admission, Increment 2.83 varispeed-and-pitch admission, Increment 2.82 I-005 0.02s link-offset work, Increment 2.81 V-023 PressureAdmission, and Increments 2.74–2.79 are not re-qualified. CompatibilityStore / ModelLease are not started. I-061 and I-055 are not started. I-013 stays partial. I-014 stays partial. I-035 stays planned. I-021, I-004, I-023, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s4 requires that, after explicit YUV matrix/range conversion and image ICC transforms, source rotation is applied only once.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_rotation_once_probe/lib/rotation_once_admission.dart`:

- Container / EXIF / display-matrix orientation, or already-baked upright pixels, may be used once.
- Applying display-matrix orientation and then rotating already-rotated pixels a second time is `ROTATION_APPLIED_TWICE`.
- A user `transform2d` `rotationDeg` is a creative edit and is not counted as a second container orientation.
- `hdrRuntimeInvented`, `lutRuntimeInvented`, `v006NumericClaimed`, `v006AppearanceClaimed`, `colorPipelineRequalified`, `i059Started`, and `paidApiCalled` stay false.

A real HDR/LUT runtime and I-059 remain unopened. `tools/spikes/rotation_once/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s4 “旋转只应用一次” bound is officialized at this admission. V-006 numeric and appearance qualifications stay unclaimed, so V-006 stays partial and is not marked complete. I-059 stays planned. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/v006-rotation-once/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this rotation-once admission or Increment 2.69 ColorPipelineAdmission metadata/range preservation. Do not invent an HDR/LUT runtime, do not claim V-006 numeric or appearance qualification, and do not start I-059 until that gate is honestly met.
