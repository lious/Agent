# ADR 0192 — Official s4 explicit input-layout downmix matrix (I-023 leftover)

## Status

Accepted for Increment 2.93 as a distinct already-specified s4 leftover on I-023: input-layout downmix uses an explicit matrix. I-023 stays partial and is not marked complete. A 20ms A/V achievement and a resolved underrun are not claimed. I-023’s remaining measurement leftovers (20ms A/V, underrun, pulse-length, ring-bound, device-switch rebind) are not re-qualified. A channel-mixer runtime, limiter, time-stretch engine, and I-007 PCM remapper are not invented. I-009 mix is not re-qualified. Increment 2.83 varispeed-and-pitch and Increment 2.85 recording-drift are not re-qualified. V-024 and I-060 stay closed. Increment 2.92 PreviewExportConsistencyAdmission, Increment 2.90 RenderRecipeAdmission, Increment 2.91 IccFirstAdmission, Increment 2.89 RotationOnceAdmission, and Increment 2.69 ColorPipelineAdmission are not re-qualified. A FrameLease is not invented, and a V-003 measurement is not claimed. Increments 2.74–2.92 already-landed slices are not re-qualified. CompatibilityStore / ModelLease are not started. I-061, I-055, I-059, and I-035 stay planned. I-013 stays partial. I-014 stays partial. I-022, V-006, I-021, I-004, I-023, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s4 “音频DSP与时钟” requires that input layouts are downmixed with an explicit matrix (`输入布局显式矩阵downmix`). The same row’s limiter, time-stretch, and I-023 measurement leftovers stay closed.

This increment officializes that downmix-matrix bound as a DEV-PURE compiler at the official entry path `packages/studio_downmix_probe/lib/downmix_admission.dart`:

- A downmix with an explicit, rectangular, finite matrix is admitted (`explicitMatrix=true`).
- Pass-through (no downmix) does not require a matrix.
- An implicit or missing matrix when a downmix is required is `DOWNMIX_MATRIX_REQUIRED`.
- An empty, ragged, or non-finite matrix is `DOWNMIX_MATRIX_INVALID`.
- This is not a channel-mixer runtime and does not perform sample mixing.
- `mixerRuntimeInvented`, `limiterInvented`, `i007PcmRemapStarted`, `i009Requalified`, `varispeedRequalified`, `driftRequalified`, `timeStretchInvented`, `av20msClaimed`, `underrunResolved`, and `paidApiCalled` stay false.

A real mixer, limiter, and I-007 PCM remapper remain unopened. `tools/spikes/downmix_matrix/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s4 “输入布局显式矩阵downmix” bound is officialized at this admission. I-023 measurement leftovers stay unclaimed, so I-023 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i023-downmix-matrix/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this downmix-matrix admission, I-009 mix, Increment 2.83 varispeed-and-pitch, or Increment 2.85 recording-drift. Do not invent a mixer, limiter, time-stretch engine, or I-007 PCM remapper. Do not claim a 20ms A/V achievement or a resolved underrun. I-023’s remaining measurement leftovers are not a clean next slice. V-024 and I-060 stay closed.
