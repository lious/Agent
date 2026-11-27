# ADR 0178 — Official s6c delivery-fps PTS resample protocol

## Status

Accepted for Increment 2.79 as a distinct s6c leftover: a delivery fps change must resample timeline PTS rather than rewrite the header and thereby alter playback speed. The slice is recorded on V-002 because that work item is the first s6c compatibility-probe contract. V-002 stays partial and is not marked complete. This increment does not invent a retimer, muxer, or optical-flow interpolator. I-024 stays partial: ExportService, the 2.72 smart-render slice, fps/HDR/upload `APPROVAL_REQUIRED`, and already-official export suites are not re-qualified or rewritten. I-007 TimeMap / nest leftovers are not re-qualified; OpenNested in-child persist and P2 reverse/freeze/smooth stay unopened. V-004 Pulse audio-sink work and the Increment 2.71 drop-disclosure slice are not re-qualified; output time is not re-stated here. The Increment 2.78 container-demux slice, the Increment 2.76 CodecProbePort slice, V-002 format-reason leftovers, the Increment 2.77 ResourceAdmissionController slice, and I-042 pack leases are not re-qualified. CompatibilityStore / ModelLease are not started. The Increment 2.75 DeviceProbeService / CompatibilityRegistry slice and the Increment 2.74 CompatibilityFallbackPlanner are not re-qualified. I-058, I-049, I-050, I-028, I-042, V-006, I-053, V-007, I-001, I-011, and I-015 leftovers are not re-qualified. I-059 stays planned until V-006=advanced-color is honestly met. I-061 and I-055 are not started. A limiter is not invented. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, and V-005 stay partial and are not marked complete. I-042 stays partial. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` is not opened as a claimed qualification. 1-frame, 20ms A/V, and V-003 measurements are not claimed.

## Decision

s6c requires that changing delivery fps resample timeline PTS rather than change the container or stream header in a way that alters playback speed. Section 7 remains the unique time/frame ownership semantics; this slice does not open I-007 PCM remapping or a product retimer.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_delivery_fps/lib/delivery_fps_admission.dart`:

- Rewriting only the fps header is `HEADER_FPS_SPEED_CHANGE`.
- A resampled plan keeps the original duration (`durationTicks` equals one second of `tickRate` for a one-second source) and sets `ptsResampled=true`, `playbackSpeedUnchanged=true`, and `durationPreserved=true`. Frame count is unchanged.
- Inventing interpolated frames or a retimer is `RETIMER_NOT_INVENTED`.
- `retimerInvented`, `opticalFlowInvented`, `muxerInvented`, `i024Requalified`, `i007Requalified`, `v004Requalified`, `containerDemuxRequalified`, and `paidApiCalled` stay false.

A real retimer, muxer, optical-flow interpolator, I-024 export re-run, I-007 TimeMap re-run, and V-004 clock re-run remain unopened. `tools/spikes/delivery_fps/README.md` points at the Dart admission; `run_probe.py` is not opened.

## Consequences

The s6c “改交付fps应重采样时间轴PTS而非改header致变速” bound is officialized at this admission. I-024, I-007, and V-004 leftovers are not re-qualified, so V-002 and I-024 stay partial and are not marked complete. 87-task counts stay 0 complete / 61 partial / 13 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/v002-delivery-fps/`.

## Follow-up

Do not start I-059 until V-006=advanced-color numeric and appearance qualifications are honestly met. Do not start I-061 or I-055. Do not invent a limiter. Do not re-qualify this delivery-fps slice, I-024, I-007, V-004 leftovers, the Increment 2.78 container-demux slice, CodecProbePort, V-002 format-reason leftovers, ResourceAdmissionController, or I-042 pack leases. Do not start CompatibilityStore / ModelLease. Do not invent a retimer, muxer, real demuxer, allocator, or payment vendor. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not claim I-016–I-019 hardware ports, a 20ms A/V achievement, store-release as passed, V-007, or a finished V-005 provider qualification. Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial leftover that is not already officialized and does not invent a deferred runtime. A possible distinct candidate is the s6c bound that original media, PTS, and color metadata are retained, with explicit normalization or an unsupported notice, only if it can be officialized without re-qualifying V-006 metadata preservation or this PTS resample slice. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, V-005, V-002, or I-042 complete.
