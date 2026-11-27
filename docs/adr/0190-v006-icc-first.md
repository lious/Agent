# ADR 0190 — Official s4 image-ICC-applied-first protocol (V-006 leftover)

## Status

Accepted for Increment 2.91 as a distinct already-specified s4 leftover on V-006: image ICC is applied first, before working-space color operations. V-006 stays partial and is not marked complete. V-006=advanced-color numeric and appearance qualifications are not claimed. An ICC, HDR, or LUT runtime is not invented. I-059 stays planned. Increment 2.89 RotationOnceAdmission and Increment 2.69 ColorPipelineAdmission metadata/range preservation are not re-qualified and are not rewritten. Increment 2.90 RenderRecipeAdmission is not re-qualified. A FrameLease is not invented, and a V-003 measurement is not claimed. Increment 2.88 ProxySourceSeekAdmission, Increment 2.84 VFR audio-duration admission, and I-021 seek/VFR/PTS suites are not re-qualified. Increment 2.87 RelinkVersionAdmission, Increment 2.86 ProxyDeliveryAdmission, Increment 2.85 recording-drift admission, Increment 2.83 varispeed-and-pitch admission, Increment 2.80 media retention, Increment 2.82 I-005 0.02s link-offset work, Increment 2.81 V-023 PressureAdmission, and Increments 2.74–2.79 are not re-qualified. CompatibilityStore / ModelLease are not started. I-061 and I-055 are not started. I-013 stays partial. I-014 stays partial. I-035 stays planned. I-022, I-021, I-004, I-023, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s4 requires that image ICC is applied first, before other working-space color operations (alongside explicit YUV matrix/range conversion for video, which is not re-qualified here, and rotation applied once, already official in Increment 2.89).

This increment officializes that image-ICC bound as a DEV-PURE compiler at the official entry path `packages/studio_icc_first_probe/lib/icc_first_admission.dart`:

- An image with an ICC profile must apply ICC, and must apply it before working-space color operations (`iccAppliedFirst=true`).
- Skipping a present ICC profile is `ICC_TRANSFORM_SKIPPED`.
- Applying working-space color operations before ICC is `ICC_MUST_BE_FIRST`.
- An untagged image (no ICC profile) does not require an ICC transform.
- This is not a LittleCMS or other ICC runtime.
- `iccRuntimeInvented`, `hdrRuntimeInvented`, `lutRuntimeInvented`, `v006NumericClaimed`, `v006AppearanceClaimed`, `colorPipelineRequalified`, `rotationOnceRequalified`, `renderRecipeRequalified`, `i059Started`, and `paidApiCalled` stay false.

A real ICC/HDR/LUT runtime and I-059 remain unopened. `tools/spikes/icc_first/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s4 “图像ICC先变换” bound is officialized at this admission. V-006 numeric and appearance qualifications stay unclaimed, so V-006 stays partial and is not marked complete. I-059 stays planned. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/v006-icc-first/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this ICC-first admission, Increment 2.89 rotation-once admission, or Increment 2.69 ColorPipelineAdmission. Do not invent an ICC/HDR/LUT runtime, do not claim V-006 numeric or appearance qualification, and do not start I-059 until that gate is honestly met.
