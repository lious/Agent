# ADR 0204 — Official s5b package auto-update default and provider caution (I-012 leftover)

## Status

Accepted for Increment 3.05 as a distinct already-specified s5b leftover on I-012: package auto-update defaults to off and must disclose that the project is auto-saved locally while the external package is still pending; provider, network, or OS-sync-hosted targets must not background auto-overwrite; a path must not be assumed to be a plain file with no upload; an authorized local auto-update must not re-copy CAS originals. I-012 stays partial and is not marked complete. ADR 0098 I-012 userSavedRevision leftovers, virtual-clock / coalesce / durable-receipt items already officialized in `save_test.dart`, Increment 2.73 V-005 provider-restriction admission, AtomicFilePublisher, `files_test`, `save_crash_test`, and official I-024 export suites are not re-qualified and are not rewritten. A SAF or iCloud adapter is not invented. A finished V-005 provider qualification is not claimed. Increment 3.04 JobCancelAdmission, Increment 3.03 ConflictReplanAdmission, and Increment 3.02 CommandClampAdmission are not re-qualified. An I-014 RestoreService commit path is not invented. The s5b “生成中的资源” row and remaining s3 error-table rows are not taken. Increments 2.74–3.04 already-landed slices are not re-qualified. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, I-012, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5b states that `externalPackageAuto` defaults to false and must explicitly disclose “自动保存在本机；工程文件待更新”; that a user may enable merge updates only for an authorized local target without re-copying CAS originals; that provider or network targets must not background auto-overwrite in P1 and instead require an explicit save with upload-closure confirmation; and that a target hosted by an OS sync service, or whose nature is unknown, must be treated as a provider and must not be assumed to be a plain file with no upload.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_package_auto_update_probe/lib/package_auto_update_admission.dart`:

- The default `externalPackageAuto=false` path is admitted when local save and pending external update are disclosed.
- An authorized local auto-update is admitted and must not re-copy CAS originals (`recopiedCasOriginals=false`). Re-copying is `CAS_ORIGINAL_RECOPY_FORBIDDEN`.
- Auto-update or background overwrite on `providerNetwork`, `osSyncHosted`, or `unknown` is `PROVIDER_AUTO_OVERWRITE_FORBIDDEN`.
- Assuming a non-local path is a plain file with no upload is `TARGET_NOT_PLAIN_FILE`.
- A default-off path without both disclosures is `PACKAGE_UPDATE_DISCLOSURE_REQUIRED`.
- An unknown target kind is `PACKAGE_TARGET_UNKNOWN`.
- The 30s idle / 120s max-attempt figures in s5b remain design defaults and are not claimed as a measured qualification.
- This does not rewrite Increment 2.73 `StorageProviderAdmission` (untested-provider rename restriction) or ADR 0098 userSavedRevision.
- `i012UserSavedRevisionRequalified`, `v005ProviderRestrictionRequalified`, `safIcloudInvented`, `v005QualificationClaimed`, `atomicFileRewritten`, `jobCancelRequalified`, `flutterWidgetTreeInvented`, `i014RestoreInvented`, and `i011CrashRequalified` stay false.

`tools/spikes/package_auto_update/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s5b package auto-update bound is officialized at this admission. I-012 product remainingScope (debounce / max interval / exit trigger, and edits during save) stays open, so I-012 stays partial and is not marked complete. Existing I-012 remainingAcceptance wording about virtual clock, concurrent-save merge, and durable receipt is left listed as already officialized by ADR 0098 / `save_test.dart` and is not silently rewritten. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i012-package-auto-update/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this package auto-update admission, ADR 0098 I-012 leftovers, Increment 2.73 V-005 provider restriction, AtomicFilePublisher, or official I-024 export suites. Do not invent a SAF/iCloud adapter or claim a V-005 qualification. Do not take s5b “生成中的资源” if that would re-qualify I-004 attach, I-013 archival, I-024, or I-040. Remaining s3 error-table rows should not be taken if they would re-qualify I-004 / Increment 2.86, I-011, or I-033.
