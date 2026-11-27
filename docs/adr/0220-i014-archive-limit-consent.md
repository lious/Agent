# ADR 0220 — Official s5c raising an archive size limit requires one-time explicit consent and must not disable path, permission, or hash checks (I-014 leftover)

## Status

Accepted for Increment 3.21 as a distinct already-specified s5c leftover on I-014: raising an archive size limit requires one-time explicit consent and must not disable path, permission, or hash checks. I-014 stays partial and is not marked complete. Existing I-014 remainingAcceptance wording (zip slip / bomb / symlink refusal, fork-new-projectId, migration keeps a good copy, 不支持feature只读保留, Increment 2.51, Increment 3.15 IdentityCollisionAdmission, Increment 3.16 FutureMajorAdmission) is not silently rewritten or cleared. `files_test` zip-slip, advertised-size zip-bomb `ARCHIVE_LIMIT`, and symlink refusal are not re-qualified and `files_test` is not rewritten. Increment 3.16 FutureMajorAdmission, the already-official “不支持feature只读保留” bound, Increment 3.15 IdentityCollisionAdmission, Increment 2.51, and fork-new-projectId are not re-qualified. The same s5c row’s “future or unknown objects stay read-only or keep the original package” and “dangerous paths are isolated” sentences are not officialized here, because they would re-qualify Increment 3.16 or the already-official zip-slip / unsafe-path bound. Default `ProjectArchive` `maxArchiveBytes` / `maxExpandedBytes` are not changed. A schema migrator, an I-014 RestoreService, and a Flutter widget tree are not invented. Increment 3.20 ArchiveSpaceAdmission, Increment 2.50 packMode, Increment 3.18 PackageProjectionAdmission, and Increment 3.19 SaveAsNamedVersionAdmission are not re-qualified. ENOSPC is not claimed. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. I-013, I-012, I-020, I-014, I-011, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5c states that future or unknown archive objects stay read-only or keep the original package, that dangerous paths are isolated immediately, and that raising a size limit requires one-time explicit consent and must not disable path, permission, or hash checks. The future-object and dangerous-path sentences are not taken here. Default zip-bomb `ARCHIVE_LIMIT` remains the already-official `files_test` bound and is not re-tested.

This increment officializes only the raise-limit consent and safety-check bounds as a DEV-PURE compiler at the official entry path `packages/studio_archive_limit_consent_probe/lib/archive_limit_consent_admission.dart`:

- `raiseArchiveLimit` is admitted only with one-time explicit consent and with path, permission, and hash checks still enabled (`consentOnce=true`, `pathChecksEnabled=true`, `permissionChecksEnabled=true`, `hashChecksEnabled=true`).
- An unknown kind is `ARCHIVE_LIMIT_KIND_UNKNOWN`.
- Raising the limit without consent is `ARCHIVE_LIMIT_CONSENT_REQUIRED`.
- Disabling path checks is `ARCHIVE_PATH_CHECKS_REQUIRED`.
- Disabling permission checks is `ARCHIVE_PERMISSION_CHECKS_REQUIRED`.
- Disabling hash checks is `ARCHIVE_HASH_CHECKS_REQUIRED`.
- `zipSlipRequalified`, `zipBombRequalified`, `symlinkRequalified`, `futureMajorRequalified`, `identityCollisionRequalified`, `forkNewProjectIdRequalified`, `archiveSpaceRequalified`, `restoreInvented`, `schemaMigratorInvented`, `flutterWidgetTreeInvented`, and `filesTestRewritten` stay false.

`tools/spikes/archive_limit_consent/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing `project_archive.dart` and `files_test.dart` are not rewritten.

## Consequences

The s5c raise-limit consent bound is officialized at this admission. I-014 remainingAcceptance zip-slip / bomb / symlink, fork, migration, unsupported-feature, Increment 2.51, Increment 3.15, and Increment 3.16 wording stay listed, so I-014 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i014-archive-limit-consent/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this archive-limit consent admission, `files_test` zip-slip / zip-bomb `ARCHIVE_LIMIT` / symlink refusal, Increment 3.16 FutureMajorAdmission, “不支持feature只读保留”, Increment 3.15 IdentityCollisionAdmission, Increment 2.51, or fork-new-projectId. Do not invent an I-014 RestoreService or a schema migrator. Do not take I-014 “ID重映射.” Do not re-qualify Increment 3.20 ArchiveSpaceAdmission, Increment 3.19 SaveAsNamedVersionAdmission, Increment 3.18 PackageProjectionAdmission, Increment 3.17 WebPublicationAdmission, or Increment 2.37 / ADR 0136. Do not claim a 60s WebCodecs/OPFS roundtrip, a V-007 production lock, or an ENOSPC measurement. Do not take s5d “再分发/执行许可分开” if that would re-qualify `FONT_REDISTRIBUTION_FACT` or `MODELS_REFERENCED_NOT_DOWNLOADED`.
