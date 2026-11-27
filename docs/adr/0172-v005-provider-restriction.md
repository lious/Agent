# ADR 0172 — Official V-005 untested-provider restriction protocol

## Status

Accepted for Increment 2.73 as a distinct V-005 leftover slice. V-005 stays partial and is not marked complete. Already-official V-005 items — the Linux controlled-local fsync/rename publisher and the 50 child SIGKILL trials at five save phases — are not re-qualified, and `AtomicFilePublisher`, `files_test`, and `save_crash_test` are not rewritten. This increment does not invent a SAF/iCloud adapter, a general StoragePort runtime, or an I-014 RestoreService commit path. I-011 crash leftovers (durableRevision, only-good-copy, checksum silent-open) are not re-qualified. The Increment 2.72 I-024 smart-render default slice and already-official I-024 export suites are not re-qualified. V-004 Pulse audio-sink work and the Increment 2.71 drop-disclosure slice are not re-qualified. I-058, I-049, I-050, I-028, I-042, V-006, I-053, V-007, I-001, I-011, and I-015 leftovers are not re-qualified. I-059 stays planned until V-006=advanced-color is honestly met. I-061 and I-055 are not started. A limiter is not invented. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, and I-024 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` is not opened as a claimed qualification.

## Decision

s5d and the V-005 remainingScope require that local fsync and SAF/iCloud are proven separately, that POSIX rename is not applied to every cloud disk, and that untested providers stay restricted. The already-admitted Linux `AtomicFilePublisher` is a controlled local filesystem adapter, not a general StoragePort (ADR 0003).

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_storage_probe/lib/storage_provider_admission.dart`:

- `StorageProviderKind.localLinux` is the admitted adapter. `saf`, `icloud`, `genericCloud`, `windowsPort`, and `appleFullfsync` stay `unvalidated` and restricted.
- Applying the local rename semantic to an untested provider is `RENAME_NOT_PORTABLE`.
- A silent rename on a non-atomic provider, without staging and confirmation, is `STAGING_CONFIRMATION_REQUIRED`.
- Claiming that SAF, iCloud, or another untested provider is qualified is `PROVIDER_UNVALIDATED`. Claiming a finished V-005 provider qualification, including for the admitted local Linux adapter, is `V005_GATE_UNMET`. `v005ProviderQualificationClaimed`, `crashSuiteRequalified`, `onlyGoodCopyRequalified`, `i014CommitInvented`, `atomicFileRewritten`, and `paidApiCalled` stay false.

A real SAF, iCloud, Windows, or Apple fullfsync adapter, a measured 10-crash-point / powerloss / ENOSPC qualification, and an I-014 RestoreService commit path remain unopened. `tools/spikes/storage_faults/README.md` points at the Dart admission; `run_probe.py` is not opened.

## Consequences

The V-005 leftover “未测provider保持受限；不把rename套所有云盘” is officialized at this StorageProviderAdmission bound. Already-official local Linux fsync/rename and SIGKILL trial suites are not re-qualified, so V-005 stays partial and is not marked complete. 87-task counts stay 0 complete / 61 partial / 13 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/v005-provider-restriction/`.

## Follow-up

Do not start I-059 until V-006=advanced-color numeric and appearance qualifications are honestly met. Do not start I-061 or I-055. Do not invent a limiter. Do not re-qualify this untested-provider slice, AtomicFilePublisher, files_test, save_crash_test, or I-011 crash leftovers, and do not re-qualify the Increment 2.72 smart-render slice, already-official I-024 export suites, V-004 Pulse or drop-disclosure work, I-058, I-049, I-050, I-028, I-042, V-006, I-053, V-007, I-001, or I-015 leftovers. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not invent a SAF/iCloud adapter or claim a V-005 provider qualification as passed. Do not claim I-016–I-019 hardware ports, a 20ms A/V achievement, or store-release as passed. Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial leftover that is not already officialized and does not invent a deferred runtime. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, or V-005 complete.
