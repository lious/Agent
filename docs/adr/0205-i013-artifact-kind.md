# ADR 0205 — Official s5b backup, archive, export, and sync are distinct artifacts (I-013 leftover)

## Status

Accepted for Increment 3.06 as a distinct already-specified s5b leftover on I-013: backup, logical archive, portable archive, finished export, and sync are distinct artifacts; a finished export must not stand in for an editable project; a provider-written receipt is not a remote device sync acknowledgment. I-013 stays partial and is not marked complete. I-013 job archival remains unopened and is not invented. Increment 2.50 packMode, Increment 2.86 ProxyDeliveryAdmission, Increment 3.05 PackageAutoUpdateAdmission, official I-024 export suites, AtomicFilePublisher, and Increment 2.73 V-005 provider-restriction admission are not re-qualified and are not rewritten. A muxer and `packMode=proxyOnly` are not invented. An I-014 RestoreService commit path is not invented. A SAF or iCloud adapter is not invented. The s5b “生成中的资源” row and remaining s3 error-table rows are not taken. Increments 2.74–3.05 already-landed slices are not re-qualified. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-012, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, I-013, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5b states that backup is an independently verified recovery root kept by policy, that logical archive is library state, that portable archive is a fixed-revision resource pack, that finished export is a render result and must not substitute for an editable project, that sync transfers only committed snapshots or events and has a separate remote ACK, and that “written to a cloud provider” is not “synced to other devices”.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_artifact_kind_probe/lib/artifact_kind_admission.dart`:

- `backup`, `logicalArchive`, `portableArchive`, `finishedExport`, and `sync` are admitted as distinct kinds. Only a `sync` with a remote device ACK is `deviceSynced=true`.
- Using a finished export as an editable project is `EXPORT_NOT_EDITABLE_PROJECT`.
- Claiming a device sync without a `sync` kind and a remote ACK, including a provider-written receipt alone, is `PROVIDER_WRITTEN_NOT_SYNCED`.
- An unknown kind is `ARTIFACT_KIND_UNKNOWN`.
- This does not invent a backup, archive, or sync runtime, does not open running-job archival at a fixed revision, and does not rewrite Increment 2.50 unpackable-resource manifests.
- `jobArchivalInvented`, `packModeRewritten`, `proxyDeliveryRequalified`, `packageAutoUpdateRequalified`, `i024ExportRequalified`, `i014RestoreInvented`, `muxerInvented`, `proxyOnlyPackModeInvented`, and `safIcloudInvented` stay false.

`tools/spikes/artifact_kind/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s5b artifact-kind bound is officialized at this admission. Running-job archival at a fixed revision still remains unopened, so I-013 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i013-artifact-kind/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this artifact-kind admission, Increment 2.50 packMode, Increment 3.05 PackageAutoUpdateAdmission, Increment 2.86 ProxyDeliveryAdmission, or official I-024 export suites. Do not invent I-013 job archival, a muxer, `packMode=proxyOnly`, or an I-014 RestoreService. Do not take s5b “生成中的资源” if that would re-qualify I-004 attach, I-013 archival, I-024, or I-040. Remaining s3 error-table rows should not be taken if they would re-qualify I-004 / Increment 2.86, I-011, or I-033.
