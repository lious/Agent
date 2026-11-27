# ADR 0175 — Official s6c CodecProbePort protocol

## Status

Accepted for Increment 2.76 as a distinct s6c CodecProbePort slice, recorded on V-002 because that work item is the first s6c compatibility-probe contract. V-002 stays partial and is not marked complete. Already-official V-002 items — Linux AAC/H264 software probe evidence, P0 format processing, 10 cancel handles, and explicit unsupported-format reasons — are not re-qualified, and I-015 leftovers are not re-qualified. The Increment 2.75 DeviceProbeService / CompatibilityRegistry slice and the Increment 2.74 CompatibilityFallbackPlanner slice are not re-qualified and are not rewritten. This increment does not invent a real FFmpeg, VideoToolbox, MediaCodec, MFT, or WebCodecs probe. V-001 toolchain probes and I-042 leases are not re-qualified. ResourceAdmissionController is not started. V-004 Pulse audio-sink work and the Increment 2.71 drop-disclosure / proxy-downgrade slice are not re-qualified. The Increment 2.72 I-024 smart-render default slice and already-official I-024 export suites are not re-qualified. The Increment 2.73 V-005 provider-restriction slice, `AtomicFilePublisher`, `files_test`, `save_crash_test`, and I-011 crash leftovers are not re-qualified. I-058, I-049, I-050, I-028, I-042, V-006, I-053, V-007, I-001, I-011, and I-015 leftovers are not re-qualified. I-059 stays planned until V-006=advanced-color is honestly met. I-061 and I-055 are not started. A limiter is not invented. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, and V-005 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` is not opened as a claimed qualification. A 60s WebCodecs/OPFS roundtrip and a V-007 production lock are not claimed.

## Decision

s6c requires `CodecProbePort.probe` to treat decode and encode as independent directions, to refuse writing `unknown` as `supported=true`, and to keep unrelated modality fields as null rather than a forged 0. Advertised capability, session creation, and sample processing are distinct facts; advertised alone is not a qualification. Audio combinations must not be inferred from video capabilities or a maximum channel count.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_codec_probe/lib/codec_probe_port.dart`:

- Applying a decode result as encode support, or an encode result as decode support, is `DECODE_ENCODE_NOT_INTERCHANGEABLE`.
- Claiming `supported=true` when the result is unknown, or when no sample has been processed, is `UNKNOWN_NOT_SUPPORTED`. An advertised-only result reports `supported=false`.
- Forging an unrelated modality field as `"0"` is `FORGED_MODALITY_ZERO`. Video results leave audio fields null; audio results leave video fields null.
- Inferring audio sample-rate, channel-count, or bitrate combinations from video capabilities is `COMBINATION_NOT_INFERRED`.
- `realProbeInvented`, `formatReasonRequalified`, `i015Requalified`, `registryRequalified`, `fallbackPlannerRequalified`, `v001Requalified`, `i042LeaseRequalified`, `paidApiCalled`, and `v007Claimed` stay false.

A real codec probe, P0 hardware qualification, V-002 format-reason re-run, I-015 ABI re-run, and ResourceAdmissionController remain unopened. `tools/spikes/codec_probe/README.md` points at the Dart admission; `run_probe.py` is not opened.

## Consequences

The s6c CodecProbePort contract is officialized at this bound. Already-official V-002 format-reason and I-015 leftovers, the Increment 2.75 registry slice, and the Increment 2.74 fallback planner are not re-qualified, so V-002 stays partial and is not marked complete. 87-task counts stay 0 complete / 61 partial / 13 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/v002-codec-probe-port/`.

## Follow-up

Do not start I-059 until V-006=advanced-color numeric and appearance qualifications are honestly met. Do not start I-061 or I-055. Do not invent a limiter. Do not re-qualify this CodecProbePort slice, the Increment 2.75 DeviceProbeService / CompatibilityRegistry slice, the Increment 2.74 CompatibilityFallbackPlanner, V-001 toolchain probes, I-042 leases, V-002 format-reason leftovers, or I-015 leftovers. Do not invent a real codec probe, encoder, device probe, SAF/iCloud adapter, or payment vendor. Do not start ResourceAdmissionController unless that bound can be officialized without re-qualifying I-042 leases. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not claim I-016–I-019 hardware ports, a 20ms A/V achievement, store-release as passed, or a finished V-005 provider qualification. Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial leftover that is not already officialized and does not invent a deferred runtime. A possible distinct candidate is the s6c ResourceAdmissionController bound (unified-pool shared counted once; idle RAM does not offset VRAM; mmap is not zero residency) only if it can be officialized without re-qualifying I-042 leases. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, V-005, or V-002 complete.
