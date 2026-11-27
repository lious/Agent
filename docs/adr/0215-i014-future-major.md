# ADR 0215 — Official s5d future major schema is read-only outer metadata and must not be executed (I-014 leftover)

## Status

Accepted for Increment 3.16 as a distinct already-specified s5d leftover on I-014: a future major schema may be scanned only at the recognizable outer layer; the unknown core is read-only metadata, the original package is kept, and the core must not be interpreted or executed. This is not a re-qualification of the already-official I-014 “不支持feature只读保留” bound, which covers an unsupported feature in a known schema. I-014 stays partial and is not marked complete. Existing I-014 remainingAcceptance wording (zip slip / bomb / symlink refusal, fork new projectId, migration keeps a good copy, unsupported feature stays read-only, Increment 2.51 restore event-seq, and Increment 3.15 identity-collision) is not silently rewritten or cleared. An I-014 RestoreService commit path and a schema migrator are not invented. ID remapping and restore-as-new-revision are not officialized here. The known-schema missing media/font/plugin sentence and copy-only migration sentence of the same s5d row are not taken, because they would re-qualify “不支持feature只读保留” or “迁移中断保好副本”. Increment 3.15 IdentityCollisionAdmission, Increment 3.14 CasDbGapAdmission, I-011 crash leftovers, AtomicFilePublisher, files_test, and save_crash_test are not re-qualified. The s5c DISK_FULL unique-copy, Web OPFS/IndexedDB, and IO_ERROR / PUBLICATION_UNCERTAIN rows are not taken. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-014, I-011, I-003, I-012, I-013, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5d states that a future schema is first scanned in a limited way at the recognizable outer layer; that the unknown core is read-only metadata and the original package is kept; and that the unknown core must not be interpreted or executed.

This increment officializes only that future-major bound as a DEV-PURE compiler at the official entry path `packages/studio_future_major_probe/lib/future_major_admission.dart`:

- A future major schema is admitted when the scan is limited to the recognizable outer layer, the unknown core is read-only metadata, and the original package is kept (`readOnly=true`, `executed=false`, `originalPackageKept=true`).
- A path that is not a future major schema is `FUTURE_MAJOR_REQUIRED`.
- Interpreting or executing the unknown core is `FUTURE_MAJOR_MUST_NOT_EXECUTE`.
- A writable or executable unknown core is `FUTURE_MAJOR_READ_ONLY`.
- Dropping the original package is `FUTURE_MAJOR_ORIGINAL_REQUIRED`.
- An unbounded scan of the unknown core is `FUTURE_MAJOR_SCAN_BOUNDED`.
- `identityCollisionRequalified`, `unsupportedFeatureReadonlyRequalified`, `i014RestoreInvented`, `migrationCopyRequalified`, `restoreEventSeqRequalified`, `schemaMigratorInvented`, `flutterWidgetTreeInvented`, `idRemapOfficialized`, and `casDbGapRequalified` stay false.

`tools/spikes/future_major/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s5d future-major read-only bound is officialized at this admission. I-014 remainingScope (ID remapping, restore as a new revision) stays open, and a product RestoreService is not invented, so I-014 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i014-future-major/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this future-major admission, “不支持feature只读保留”, Increment 3.15 IdentityCollisionAdmission, Increment 2.51, or already-official I-014 zip-slip / fork-new-id / migration-copy conclusions. Do not invent an I-014 RestoreService or a schema migrator. I-014 remainingScope “ID重映射” may be considered only if it can be bounded without inventing a RestoreService or re-qualifying fork-new-projectId. Do not re-qualify Increment 3.14, I-011 crash leftovers, AtomicFilePublisher, files_test, or save_crash_test. Do not take the restricted s5c rows if that would re-qualify those leftovers or claim V-007.
