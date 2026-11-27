# ADR 0180 — Official V-023 pressure-pause and interrupt durable-chunk protocol

## Status

Accepted for Increment 2.81 as the first official V-023 slice: under thermal or memory pressure, heavy models are paused first and basic editing stays available; ten interrupts do not lose already-durable chunks, and in-flight non-durable work is discarded. V-023 moves from planned to partial and is not marked complete. This increment does not re-qualify I-042 pack leases (`LEASE_DOUBLE_COUNT`, stale pointer after process/ABI change, signature, offlineOnly) and does not rewrite `packages/studio_agent/lib/model_pack.dart`. This increment does not re-qualify the Increment 2.77 ResourceAdmissionController budget arithmetic (`INCREMENTAL_SHARED_DOUBLE_COUNT`, `VRAM_NOT_OFFSET_BY_RAM`, `MMAP_NOT_ZERO_RESIDENT`) and does not rewrite `packages/studio_resource_admission`. Shared-once accounting and ABI/device stale-pointer leftovers stay listed on V-023 and I-042. CompatibilityStore / ModelLease are not started. A real GPU worker, a real allocator, and a 20-minute no-OOM or deadlock measurement are not invented or claimed. Increments 2.74–2.80 s6c default-delivery protocol slices (CompatibilityFallbackPlanner, DeviceProbeService / CompatibilityRegistry, CodecProbePort, ResourceAdmissionController, container-demux, delivery-fps PTS resample, MediaRetentionAdmission) are not re-qualified. V-006 metadata/range preservation, I-024, I-007, V-004 leftovers, V-002 format-reason leftovers, V-001 toolchain probes, and I-015 leftovers are not re-qualified. I-059 stays planned. I-061 and I-055 are not started. A limiter is not invented. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, V-005, V-002, I-007, and I-042 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` is not opened as a claimed qualification.

## Decision

V-023 requires that pressure pauses heavy models first, and that ten interrupts do not lose already-durable chunks.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_pressure_probe/lib/pressure_admission.dart`:

- Under thermal or memory pressure, heavy models and preview are paused first and basic editing remains available. Pausing basic editing first, or pausing everything equally, is `HEAVY_NOT_PAUSED_FIRST`.
- Ten interrupts retain already-durable chunks. The first interrupt discards in-flight non-durable work (`inflightDiscarded=true`); later interrupts keep the same durable set and do not invent that discarded work as durable. Dropping a durable chunk is `DURABLE_CHUNK_LOST`.
- `i042LeaseRequalified`, `resourceAdmissionRequalified`, `sharedOnceRequalified`, `stalePointerRequalified`, `gpuWorkerInvented`, `modelLeaseInvented`, `compatibilityStoreInvented`, `oomClaimed`, and `paidApiCalled` stay false.

A real GPU worker, a ModelLease store, a CompatibilityStore, a 20-minute no-OOM measurement, I-042 pack-lease re-qualification, and the Increment 2.77 ResourceAdmissionController slice remain unopened or un-rewritten. `tools/spikes/resource_pressure/README.md` points at the Dart admission; `run_probe.py` is not opened.

## Consequences

The V-023 “压力先暂停重模型；10次中断不丢durable chunk” bounds are officialized at this admission. Shared-once accounting, ABI/device stale-pointer leftovers, and the 20-minute no-OOM/deadlock measurement stay listed, so V-023 stays partial and is not marked complete. 87-task counts move from 0 complete / 61 partial / 13 planned / 13 blocked to 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.
