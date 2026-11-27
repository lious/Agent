# ADR 0182 — Official s4 first-version varispeed-and-pitch policy (I-023 leftover)

## Status

Accepted for Increment 2.83 as a distinct already-specified s4 leftover on I-023: a non-1x source-audio rate must be explicit “变速并变调” or mute, and must not claim pitch preservation. A licensed time-stretch engine stays a later evaluation and is not invented. I-023 stays partial and is not marked complete. 20ms A/V, a resolved underrun, pulse-length, ring-bound, and device-switch rebind leftovers stay listed and are not claimed. This increment does not start I-007 PCM remapping, a limiter, or a muxer, and does not rewrite I-007 TimeMap, I-009 mix, or I-024 export suites. Increment 2.82 I-005 0.02s link-offset work and the frozen s3 1/30s suite are not re-qualified. Increment 2.81 V-023 PressureAdmission and leftover V-023 labels are not re-qualified. Increments 2.74–2.80 s6c default-delivery slices, V-006 metadata/range preservation, I-024, I-007, V-004 leftovers, V-002 format-reason leftovers, and I-042 pack leases are not re-qualified. CompatibilityStore / ModelLease are not started. I-059 stays planned. I-061 and I-055 are not started. I-013 stays partial. I-014 stays partial. I-035 stays planned. I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` is not opened as a claimed qualification.

## Decision

s4 requires that a first-version non-1x source-audio rate is explicit “变速并变调” or mute, and must not claim pitch preservation. Independent licensed time-stretch is a later evaluation.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_varispeed_probe/lib/varispeed_admission.dart`:

- A 1x rate needs no special policy.
- A non-1x rate with policy `varispeedPitchChange` or `muted` is admitted and does not claim pitch preservation.
- Claiming `pitchPreserved` on a non-1x rate is `PITCH_PRESERVED_UNAVAILABLE`.
- A non-1x rate with no explicit policy is `VARISPEED_POLICY_REQUIRED`. A non-positive rate is `RATE_INVALID`.
- `timeStretchInvented`, `pcmRemapInvented`, `limiterInvented`, `i007Requalified`, `i009Requalified`, `i024Requalified`, `v023Requalified`, `i005Requalified`, `muxerInvented`, and `paidApiCalled` stay false.

A real time-stretch engine, I-007 PCM remapping, and a limiter remain unopened. `tools/spikes/varispeed_pitch/README.md` points at the Dart admission; `run_probe.py` is not opened.

## Consequences

The s4 “源音频非1x首版明确变速并变调或静音，不能称保音调” bound is officialized at this admission. 20ms A/V, underrun, pulse, ring, and device-switch leftovers stay listed, so I-023 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i023-varispeed-pitch/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this varispeed-and-pitch admission. Do not invent a time-stretch engine, limiter, or I-007 PCM remapper, and do not claim 20ms A/V or a resolved underrun.
