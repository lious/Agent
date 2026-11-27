# ADR 0218 — Official s5b Save As must not silently overwrite an existing file, and a named version is a label pin not a fork or rollback (I-012 leftover)

## Status

Accepted for Increment 3.19 as a distinct already-specified s5b leftover on I-012: Save As must not silently overwrite an existing file, and a named version is a label pin of an immutable checkpoint, not a fork or a rollback. I-012 stays partial and is not marked complete. Existing I-012 remainingAcceptance wording (虚拟时钟验证全部触发, 并发save合并, 保存完成只在durable receipt之后, and later Increment 3.05 / 3.07 / 3.10 / 3.11 officialization notes) is not silently rewritten or cleared. `CHECKPOINT_NAME_EXISTS` in `checkpoint_retention_test.dart`, fork-new-projectId, Increment 3.10 ExplicitSaveAdmission, and Increment 3.11 CheckpointIdentityAdmission (including “do not recopy media”) are not re-qualified. The “new project copy defaults to a new projectId” and “keep the id and explicitly switch binding” clauses of the same s5b row are not officialized here, because they would re-qualify fork-new-projectId and ExplicitSaveAdmission. “Named versions do not recopy large media” is not officialized here, because it would re-qualify CheckpointIdentityAdmission. Name-conflict no-overwrite remains the already-official `CHECKPOINT_NAME_EXISTS` bound and is not re-tested. A Flutter widget tree, a StoragePort runtime, a WAL-checkpoint runtime, and an I-014 RestoreService are not invented. Increment 3.18 PackageProjectionAdmission, Increment 2.50 packMode, Increment 3.06 ArtifactKindAdmission, and `MANIFEST_SNAPSHOT_MISMATCH` are not re-qualified. Increment 3.17 WebPublicationAdmission, Increment 2.37 / ADR 0136, a 60s WebCodecs/OPFS roundtrip, and a V-007 production lock are not re-qualified or claimed. I-014 “ID重映射” is not taken, and a RestoreService is not invented. The 30s idle / 120s max-attempt figures remain design defaults and are not claimed as a measured qualification. SQLite WAL recovery remains as already recorded in ADR 0003 and is not disabled. Store journal pragmas are not changed. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. I-013, I-020, I-014, I-011, I-003, I-012, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5b states that Save As offers a new project copy (defaulting to a new projectId) and saving the current project to a new location (keeping the id and explicitly switching the binding); that it must not silently overwrite an existing file; and that a named version is only a long-term pin of a label onto an immutable checkpoint, does not recopy large media, and is not a fork or a rollback, with a unique-name conflict prompting a rename rather than overwriting the old named version. The fork-new-projectId, explicit-binding, media-recopy, and `CHECKPOINT_NAME_EXISTS` clauses are not taken here.

This increment officializes only the silent-overwrite and named-version-identity bounds as a DEV-PURE compiler at the official entry path `packages/studio_save_as_named_version_probe/lib/save_as_named_version_admission.dart`:

- `saveAs` is admitted only when it does not silently overwrite an existing file (`silentOverwrite=false`). An existing target without overwrite confirmation is `SILENT_OVERWRITE_FORBIDDEN`.
- `namedVersion` is admitted as a label pin (`isLabelPin=true`, `isFork=false`, `isRollback=false`). Claiming it is a fork is `NAMED_VERSION_NOT_FORK`. Claiming it is a rollback is `NAMED_VERSION_NOT_ROLLBACK`.
- An unknown kind is `SAVE_AS_KIND_UNKNOWN`.
- `checkpointNameExistsRequalified`, `forkNewProjectIdRequalified`, `explicitSaveRequalified`, `checkpointIdentityRequalified`, `uniqueCopyRequalified`, `packageProjectionRequalified`, `flutterWidgetTreeInvented`, `storagePortInvented`, `restoreInvented`, and `walCheckpointInvented` stay false.

This is not the I-011 unique-copy / partial-package crash clause and does not re-qualify `AtomicFilePublisher`. `tools/spikes/save_as_named_version/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing `checkpoint_retention_test.dart` and Increment 3.10 / 3.11 suites are not rewritten.

## Consequences

The s5b Save As silent-overwrite and named-version-identity bounds are officialized at this admission. I-012 remainingAcceptance virtual-clock, concurrent-save, durable-receipt, and later increment wording stay listed, so I-012 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i012-save-as-named-version/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this Save As / named-version admission, `CHECKPOINT_NAME_EXISTS`, fork-new-projectId, Increment 3.10 ExplicitSaveAdmission, or Increment 3.11 CheckpointIdentityAdmission. Do not invent a Flutter widget tree, a StoragePort runtime, or an I-014 RestoreService. Do not re-qualify Increment 3.18 PackageProjectionAdmission, Increment 2.50 packMode, or Increment 3.06 ArtifactKindAdmission. Do not re-qualify Increment 3.17 WebPublicationAdmission or Increment 2.37 / ADR 0136, and do not claim a 60s WebCodecs/OPFS roundtrip or a V-007 production lock. Do not take I-014 “ID重映射” or invent a RestoreService for “旧版本恢复新rev.”
