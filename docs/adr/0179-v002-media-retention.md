# ADR 0179 — Official s6c original/PTS/color-metadata retention protocol

## Status

Accepted for Increment 2.80 as a distinct s6c leftover: original media, PTS, and color metadata are retained, with explicit normalization or an unsupported notice. The slice is recorded on V-002 because that work item is the first s6c compatibility-probe contract. V-002 stays partial and is not marked complete. V-006 stays partial and is not marked complete. This increment does not re-qualify V-006 ColorPipelineAdmission metadata or range preservation (`METADATA_NOT_PRESERVED`, `RANGE_NOT_PRESERVED`, silent 8-bit clip, tonemap confirmation, appearance qualification) and does not rewrite `packages/studio_color_probe`. This increment does not re-qualify the Increment 2.79 delivery-fps PTS resample slice (`HEADER_FPS_SPEED_CHANGE`, `RETIMER_NOT_INVENTED`) and does not rewrite `packages/studio_delivery_fps`. A real HDR or LUT runtime is not invented, and V-006 numeric or appearance qualification is not claimed. I-059 stays planned. I-024, I-007, and V-004 leftovers are not re-qualified. The Increment 2.78 container-demux slice, CodecProbePort, V-002 format-reason leftovers, ResourceAdmissionController, and I-042 pack leases are not re-qualified. CompatibilityStore / ModelLease are not started. The Increment 2.75 DeviceProbeService / CompatibilityRegistry slice and the Increment 2.74 CompatibilityFallbackPlanner are not re-qualified. I-058, I-049, I-050, I-028, I-042, V-006, I-053, V-007, I-001, I-011, and I-015 leftovers are not re-qualified. I-061 and I-055 are not started. A limiter is not invented. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, and V-005 stay partial and are not marked complete. I-007 and I-042 stay partial. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` is not opened as a claimed qualification.

## Decision

s6c requires that original media, PTS, and color metadata are retained, and that normalization is explicit or the path is reported as unsupported.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_media_retention/lib/media_retention_admission.dart`:

- Replacing the original essence is `SOURCE_NOT_RETAINED`. Dropping source PTS is `PTS_NOT_RETAINED`. Dropping color metadata from the retained original is `COLOR_METADATA_NOT_RETAINED`. These codes are not V-006 `METADATA_NOT_PRESERVED` / `RANGE_NOT_PRESERVED`.
- A silent normalize is `NORMALIZATION_MUST_BE_EXPLICIT`. An explicit normalize produces a labeled derived path and still retains the original hash, PTS, and color metadata. Otherwise the receipt reports `unsupportedNotice=true` and does not rewrite the source.
- `v006Requalified`, `deliveryFpsRequalified`, `hdrRuntimeInvented`, `lutRuntimeInvented`, `retimerInvented`, `muxerInvented`, `i059Started`, and `paidApiCalled` stay false.

A real HDR/LUT runtime, a retimer, a V-006 numeric or appearance qualification, and I-059 remain unopened. `tools/spikes/media_retention/README.md` points at the Dart admission; `run_probe.py` is not opened.

## Consequences

The s6c “保留原件/PTS/color metadata，显式归一或告知不支持” bound is officialized at this admission. V-006 metadata preservation and the Increment 2.79 delivery-fps slice are not re-qualified, so V-002 and V-006 stay partial and are not marked complete. 87-task counts stay 0 complete / 61 partial / 13 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/v002-media-retention/`.

## Follow-up

Do not start I-059 until V-006=advanced-color numeric and appearance qualifications are honestly met. Do not start I-061 or I-055. Do not invent a limiter. Do not re-qualify this retention slice, V-006 metadata preservation, the Increment 2.79 delivery-fps slice, I-024, I-007, V-004 leftovers, the Increment 2.78 container-demux slice, CodecProbePort, V-002 format-reason leftovers, ResourceAdmissionController, or I-042 pack leases. Do not start CompatibilityStore / ModelLease. Do not invent a retimer, muxer, real demuxer, allocator, HDR/LUT runtime, or payment vendor. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not claim I-016–I-019 hardware ports, a 20ms A/V achievement, store-release as passed, V-007, or a finished V-005 provider qualification. Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial leftover that is not already officialized and does not invent a deferred runtime. The s6c default-delivery paragraph is now official at protocol bounds; do not re-qualify those slices. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, V-005, V-002, I-007, or I-042 complete.
