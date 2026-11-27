# ADR 0184 — Official s4 recording-drift map and confirmed-sync protocol (I-023 leftover)

## Status

Accepted for Increment 2.85 as a distinct already-specified s4 leftover on I-023: recording drift is corrected only by an explicit resample that records a mapping and does not overwrite the original; a manual sync offset is applied only after confirmation. I-023 stays partial and is not marked complete. 20ms A/V, a resolved underrun, pulse-length, ring-bound, and device-switch rebind leftovers stay listed and are not claimed. This increment does not invent a waveform correlator, a tracker, a time-stretch engine, a limiter, or an I-007 PCM remapper. Increment 2.80 media retention (`SOURCE_NOT_RETAINED`, `PTS_NOT_RETAINED`, `COLOR_METADATA_NOT_RETAINED`, `NORMALIZATION_MUST_BE_EXPLICIT`) is not re-qualified and `packages/studio_media_retention` is not rewritten. Increment 2.84 VfrAudioDurationAdmission, Increment 2.83 VarispeedAdmission, Increment 2.82 I-005 0.02s link-offset work, Increment 2.81 V-023 PressureAdmission, Increment 2.79 delivery-fps, and I-021 seek/VFR/PTS suites are not re-qualified. `source_preview_test.dart` and `frame_proxy_test.dart` are not rewritten. Increments 2.74–2.78, V-006 metadata/range preservation, I-024, I-007, V-004 leftovers, V-002 format-reason leftovers, and I-042 pack leases are not re-qualified. CompatibilityStore / ModelLease are not started. I-059 stays planned. I-061 and I-055 are not started. I-013 stays partial. I-014 stays partial. I-035 stays planned. I-021, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` is not opened as a claimed qualification. A 1-frame or 50ms sync measurement is not claimed.

## Decision

s4 requires that recording drift is corrected by an explicit resample that records a mapping and does not overwrite the original, and that a manual sync offset is applied only after user confirmation. Waveform correlation may *propose* an offset; this increment does not invent a correlator.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_drift_probe/lib/recording_drift_admission.dart`:

- A silent resample or an unstated correction is `DRIFT_MUST_BE_EXPLICIT`.
- An explicit resample that overwrites the original, or that does not retain it, is `ORIGINAL_RECORDING_NOT_RETAINED`. This code is not Increment 2.80 `SOURCE_NOT_RETAINED`.
- An explicit resample without a recorded mapping is `DRIFT_MAP_REQUIRED`.
- Applying a manual sync offset without confirmation is `SYNC_CONFIRMATION_REQUIRED`. A confirmed offset may be applied.
- `correlatorInvented`, `trackerInvented`, `mediaRetentionRequalified`, `vfrAudioRequalified`, `varispeedRequalified`, `timeStretchInvented`, `limiterInvented`, `pcmRemapInvented`, `oneFrameClaimed`, `twentyMsClaimed`, and `paidApiCalled` stay false.

A real waveform correlator, tracker, and time-stretch engine remain unopened. `tools/spikes/recording_drift/README.md` points at the Dart admission; `run_probe.py` is not opened.

## Consequences

The s4 “录音drift需显式重采样修正，记录映射而不覆盖原音；手动sync offset 须用户确认” bounds are officialized at this admission. 20ms A/V, underrun, pulse, ring, and device-switch leftovers stay listed, so I-023 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i023-recording-drift/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this recording-drift admission, Increment 2.83 varispeed-and-pitch policy, Increment 2.84 VFR audio-duration admission, or Increment 2.80 media retention. Do not invent a waveform correlator, and do not claim a 1-frame or 20ms A/V measurement.
