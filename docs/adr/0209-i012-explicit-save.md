# ADR 0209 — Official s5b explicit save does not imply a .studioproj, and a bound package succeeds only after a StoragePort receipt (I-012 leftover)

## Status

Accepted for Increment 3.10 as a distinct already-specified s5b leftover on I-012: library-mode `saveManaged` writes a checkpoint and an explicit save receipt and must not imply a `.studioproj` was written; `saveBoundPackage` requires an external binding and may claim success only after a StoragePort receipt. I-012 stays partial and is not marked complete. Existing I-012 remainingAcceptance wording is not silently rewritten. Increment 3.07 CloseCheckpointAdmission, Increment 3.05 PackageAutoUpdateAdmission, Increment 3.06 ArtifactKindAdmission, ADR 0098 I-012 leftovers, Increment 3.09 WriterFenceAdmission, Increment 2.73 V-005 provider-restriction admission, and AtomicFilePublisher are not re-qualified. A Flutter widget tree, a SAF or iCloud adapter, a StoragePort runtime, I-013 job archival, a muxer, and an I-014 RestoreService are not invented. A finished V-005 provider qualification is not claimed. The 30s idle / 120s max-attempt figures in s5b remain design defaults and are not claimed as a measured qualification. The s5b close-path draft confirmation widget was not officialized in 3.07 and is not officialized here; ADR 0028 already covers discarding pending ghosts on close and is not re-qualified. The s5b “不能盲重试生成”, “保存中编辑/合并”, and “生成中的资源” rows are not taken. Remaining s3 error-table rows are not taken. Increments 2.74–3.09 already-landed slices are not re-qualified. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-003, I-012, I-013, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5b states that in library mode, `saveManaged` writes a checkpoint and an explicit save receipt and displays a local library save; that when the user has associated an external file, `saveBoundPackage` freezes the revision and updates the package, and success is shown only after a StoragePort receipt; and that an unassociated project must not imply a `.studioproj` was written.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_explicit_save_probe/lib/explicit_save_admission.dart`:

- `saveManaged` is admitted when a checkpoint and an explicit save receipt are written (`librarySaved=true`, `externalFileWritten=false`, `boundSuccess=false`).
- A `saveManaged` path missing the checkpoint or the explicit receipt is `EXPLICIT_SAVE_RECEIPT_REQUIRED`.
- A `saveManaged` path, or any unbound path, that claims a `.studioproj` or bound-package success is `UNBOUND_STUDIOPROJ_NOT_IMPLIED`.
- `saveBoundPackage` without an external binding is `EXTERNAL_BINDING_REQUIRED`.
- `saveBoundPackage` may be admitted without a StoragePort receipt only as a not-yet-successful update (`boundSuccess=false`, `externalFileWritten=false`). Claiming success without that receipt is `STORAGE_PORT_RECEIPT_REQUIRED`.
- After a StoragePort receipt, `saveBoundPackage` may claim bound success (`boundSuccess=true`, `externalFileWritten=true`).
- An unknown mode is `EXPLICIT_SAVE_MODE_UNKNOWN`.
- `closeCheckpointRequalified`, `packageAutoUpdateRequalified`, `artifactKindRequalified`, `i012UserSavedRevisionRequalified`, `flutterWidgetTreeInvented`, `safIcloudInvented`, `storagePortRuntimeInvented`, `i014RestoreInvented`, `v005QualificationClaimed`, and `writerFenceRequalified` stay false.

`tools/spikes/explicit_save/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s5b explicit-save bound is officialized at this admission. I-012 product remainingScope stays open, so I-012 stays partial and is not marked complete. Existing I-012 remainingAcceptance wording is left listed and is not silently rewritten. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i012-explicit-save/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this explicit-save admission, Increment 3.07 CloseCheckpointAdmission, Increment 3.05 PackageAutoUpdateAdmission, Increment 3.06 ArtifactKindAdmission, ADR 0098 I-012 leftovers, or Increment 3.09 WriterFenceAdmission. Do not invent a Flutter widget tree, a SAF/iCloud adapter, a StoragePort runtime, I-013 job archival, or an I-014 RestoreService. Do not take s5b “不能盲重试生成”, “保存中编辑/合并”, or “生成中的资源” if that would re-qualify I-033, I-040, I-011, ADR 0098, I-004 attach, I-013 archival, or I-024. Remaining s3 error-table rows should not be taken if they would re-qualify I-004 / Increment 2.86, I-011, or I-033.
