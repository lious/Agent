# ADR 0176 — Official s6c ResourceAdmissionController protocol

## Status

Accepted for Increment 2.77 as a distinct s6c ResourceAdmissionController budget-arithmetic slice, recorded on V-002 because that work item is the first s6c compatibility-probe contract. V-002 stays partial and is not marked complete. I-042 stays partial and is not marked complete. I-042 ModelPack `ResourceLease` / `LEASE_DOUBLE_COUNT` / stale-pointer suites are not re-qualified and `packages/studio_agent/lib/model_pack.dart` is not rewritten. CompatibilityStore / ModelLease are not started. This increment does not invent a real memory or GPU allocator. The Increment 2.76 CodecProbePort slice, the Increment 2.75 DeviceProbeService / CompatibilityRegistry slice, and the Increment 2.74 CompatibilityFallbackPlanner slice are not re-qualified and are not rewritten. V-001 toolchain probes, V-002 format-reason leftovers, and I-015 leftovers are not re-qualified. V-004 Pulse audio-sink work and the Increment 2.71 drop-disclosure / proxy-downgrade slice are not re-qualified. The Increment 2.72 I-024 smart-render default slice and already-official I-024 export suites are not re-qualified. The Increment 2.73 V-005 provider-restriction slice, `AtomicFilePublisher`, `files_test`, `save_crash_test`, and I-011 crash leftovers are not re-qualified. I-058, I-049, I-050, I-028, I-042, V-006, I-053, V-007, I-001, I-011, and I-015 leftovers are not re-qualified. I-059 stays planned until V-006=advanced-color is honestly met. I-061 and I-055 are not started. A limiter is not invented. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, and V-005 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` is not opened as a claimed qualification.

## Decision

s6c requires `ResourceAdmissionController.admit` to compute incremental allocations, not total App peak. In a unified pool, host-exclusive, device-exclusive, and shared charges plus headroom must fit available memory, and shared is counted once. Already-resident shared packs are deducted first so weight is neither double-counted nor subtracted twice. On a discrete GPU, host and VRAM are checked separately; idle RAM must not offset VRAM. mmap is not zero residency. A resource shortfall is `waitingResource` and must not disable basic project editing.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_resource_admission/lib/resource_admission_controller.dart`:

- Incremental shared is charged once per unique allocation id. A second incremental charge of the same shared id is `INCREMENTAL_SHARED_DOUBLE_COUNT`. This is not I-042 `LEASE_DOUBLE_COUNT`.
- Already-resident shared packs are excluded from the incremental charge even if they also appear as a needed entry.
- Asking to cover a VRAM shortfall with idle host RAM is `VRAM_NOT_OFFSET_BY_RAM`. A discrete device shortfall returns `waitingResource` with `basicEditingRemainsAvailable=true`.
- Treating mmap as zero residency is `MMAP_NOT_ZERO_RESIDENT`. mmap bytes remain in `mmapResidency` and in the incremental shared or exclusive charge.
- `i042LeaseRequalified`, `codecProbeRequalified`, `registryRequalified`, `fallbackPlannerRequalified`, `modelLeaseInvented`, `compatibilityStoreInvented`, `realProbeInvented`, and `paidApiCalled` stay false.

A real allocator, I-042 pack-lease re-run, CompatibilityStore, and ModelLease remain unopened. `tools/spikes/resource_admission/README.md` points at the Dart admission; `run_probe.py` is not opened.

## Consequences

The s6c ResourceAdmissionController budget-arithmetic contract is officialized at this bound. I-042 pack leases and earlier s6c slices are not re-qualified, so V-002 and I-042 stay partial and are not marked complete. 87-task counts stay 0 complete / 61 partial / 13 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/v002-resource-admission/`.

## Follow-up

Do not start I-059 until V-006=advanced-color numeric and appearance qualifications are honestly met. Do not start I-061 or I-055. Do not invent a limiter. Do not re-qualify this ResourceAdmissionController slice, I-042 pack leases, the Increment 2.76 CodecProbePort slice, the Increment 2.75 DeviceProbeService / CompatibilityRegistry slice, the Increment 2.74 CompatibilityFallbackPlanner, V-001 toolchain probes, or V-002 format-reason / I-015 leftovers. Do not start CompatibilityStore / ModelLease. Do not invent a real memory or GPU allocator, codec probe, SAF/iCloud adapter, or payment vendor. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not claim I-016–I-019 hardware ports, a 20ms A/V achievement, store-release as passed, or a finished V-005 provider qualification. Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial leftover that is not already officialized and does not invent a deferred runtime. A possible distinct candidate is the s6c bound that demux of a container does not imply the bitstream can be decoded or encoded, only if it can be officialized without inventing a real demuxer or re-qualifying CodecProbePort or V-002 format-reason leftovers. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, V-005, I-042, or V-002 complete.
