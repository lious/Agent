# ADR 0187 — Official s4 proxy-map source-frame selection (I-021 leftover)

## Status

Accepted for Increment 2.88 as a distinct already-specified s4 leftover on I-021: final render selects the original source frame by the same proxy-frame→source-PTS map as preview, and must not seek the original by proxy frame number; the last source frame must not go past the source. I-021 stays partial and is not marked complete. The already-official I-021 labels (20-point seek ±1 frame, VFR/nonzero-PTS mapping, cache ≤ budget, no full-file decode on every seek) stay listed and are not re-qualified. `source_preview_test.dart` and `frame_proxy_test.dart` are not rewritten. Increment 2.84 VfrAudioDurationAdmission is not re-qualified. This increment does not invent a demuxer, seeker, or retimer, and does not claim a 1-frame measurement. Increment 2.87 RelinkVersionAdmission, Increment 2.86 ProxyDeliveryAdmission, Increment 2.85 recording-drift admission, Increment 2.83 varispeed-and-pitch admission, Increment 2.80 media retention, Increment 2.79 delivery-fps, and I-004 remaining labels are not re-qualified. RelinkProposal / FileToken / AssetRepository are not invented. Increment 2.82 I-005 0.02s link-offset work, Increment 2.81 V-023 PressureAdmission, and Increments 2.74–2.78 are not re-qualified. CompatibilityStore / ModelLease are not started. I-059 stays planned. I-061 and I-055 are not started. I-013 stays partial. I-014 stays partial. I-035 stays planned. I-004, I-023, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` is not opened as a claimed qualification.

## Decision

s4 requires that a CFR proxy stores a proxy-frame→source-PTS map, that final render uses the same source-frame selection rule as preview, that the original must not be sought by proxy frame number, and that the last displayed source frame does not go past the source.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_proxy_seek_probe/lib/proxy_source_seek_admission.dart`:

- A valid plan looks up a caller-supplied map entry and returns that source PTS for both preview and final.
- Seeking the original by proxy frame number is `PROXY_FRAME_SEEK_FORBIDDEN`.
- Preview and final using different selection rules is `SOURCE_SELECTION_RULE_MISMATCH`.
- A mapped source PTS at or past the source duration is `SOURCE_FRAME_OUT_OF_RANGE`.
- This admission does not recompute VFR mapping and does not invent a demuxer.
- `i021SeekRequalified`, `vfrAudioRequalified`, `retimerInvented`, `demuxerInvented`, `oneFrameClaimed`, and `paidApiCalled` stay false.

A real demuxer, seeker, and retimer remain unopened. `tools/spikes/proxy_source_seek/README.md` points at the Dart admission; `run_probe.py` is not opened.

## Consequences

The s4 “最终渲染按同一选择规则取原source帧，不能按proxy帧号直接seek原件；最后一帧不越源” bound is officialized at this admission. I-021 seek/VFR/PTS/cache labels and Increment 2.84 stay listed, so I-021 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i021-proxy-source-seek/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this proxy-source-seek admission, Increment 2.84 VFR audio-duration admission, or the already-official I-021 seek/VFR/PTS/cache suites. Do not invent a demuxer or claim a 1-frame measurement.
