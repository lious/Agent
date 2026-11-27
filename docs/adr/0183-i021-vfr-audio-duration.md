# ADR 0183 — Official s4 VFR-normalize audio-duration retention (I-021 leftover)

## Status

Accepted for Increment 2.84 as a distinct already-specified s4 leftover on I-021: when normalizing VFR, actual audio duration is retained and must not be stretched to a nominal fps duration. I-021 stays partial and is not marked complete. The already-official I-021 labels (20-point seek ±1 frame, VFR/nonzero-PTS mapping, cache ≤ budget, no full-file decode on every seek) stay listed and are not re-qualified. `source_preview_test.dart` and `frame_proxy_test.dart` are not rewritten. This increment does not invent a retimer, time-stretch engine, limiter, muxer, or I-007 PCM remapper. Increment 2.83 VarispeedAdmission, Increment 2.82 I-005 0.02s link-offset work, Increment 2.81 V-023 PressureAdmission, Increment 2.79 delivery-fps PTS resample, and Increment 2.80 media retention are not re-qualified. Increments 2.74–2.78, V-006 metadata/range preservation, I-024, I-007, V-004 leftovers, V-002 format-reason leftovers, and I-042 pack leases are not re-qualified. CompatibilityStore / ModelLease are not started. I-059 stays planned. I-061 and I-055 are not started. I-013 stays partial. I-014 stays partial. I-035 stays planned. I-023, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` is not opened as a claimed qualification. A 20ms A/V achievement and a resolved underrun are not claimed.

## Decision

s4 requires that VFR normalization retains actual audio duration and does not stretch audio to a nominal fps duration.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_vfr_audio_probe/lib/vfr_audio_duration_admission.dart`:

- A valid plan keeps `outputAudioSamples == actualAudioSamples`.
- Stretching audio to the nominal CFR length (`frameCount / nominalFps`), or writing that nominal length as the output audio length even without an explicit stretch flag, is `AUDIO_STRETCHED_TO_NOMINAL_FPS`.
- A non-positive fps, sample rate, or negative sample/frame count is `RATE_INVALID`.
- `i021SeekRequalified`, `deliveryFpsRequalified`, `mediaRetentionRequalified`, `varispeedRequalified`, `retimerInvented`, `timeStretchInvented`, `muxerInvented`, `limiterInvented`, `pcmRemapInvented`, and `paidApiCalled` stay false.

A real retimer, time-stretch engine, and muxer remain unopened. `tools/spikes/vfr_audio_duration/README.md` points at the Dart admission; `run_probe.py` is not opened.

## Consequences

The s4 “归一时保留音频实际时长，不按nominal fps拉伸” bound is officialized at this admission. I-021 seek/VFR/PTS/cache labels stay listed, so I-021 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i021-vfr-audio-duration/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this VFR audio-duration admission or the already-official I-021 seek/VFR/PTS/cache suites. Do not invent a retimer or time-stretch engine.
