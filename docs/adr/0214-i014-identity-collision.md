# ADR 0214 — Official s5d same-id same-revision different-hash import is IDENTITY_COLLISION and must not overwrite (I-014 leftover)

## Status

Accepted for Increment 3.15 as a distinct already-specified s5d leftover on I-014: a same projectId+revision+hash import is a duplicate and must not overwrite the existing project; the same projectId and revision with a different hash is `IDENTITY_COLLISION` and must not overwrite. I-014 stays partial and is not marked complete. Existing I-014 remainingAcceptance wording (zip slip / bomb / symlink refusal, fork new projectId, migration keeps a good copy, unsupported feature stays read-only, and Increment 2.51 restore event-seq) is not silently rewritten or re-qualified. A product I-014 RestoreService commit path is not invented. A Flutter open-or-fork widget is not invented. Future-major read-only, ID remapping, and restore-as-new-revision are not officialized here. Increment 3.14 CasDbGapAdmission, I-011 crash leftovers, AtomicFilePublisher, files_test, and save_crash_test are not re-qualified. ACK-lost receipt retry and crash-after-CAS orphan claim/GC are not officialized. Increment 3.13 SharedLibraryAdmission, Increment 3.12 PreparedStageAdmission, Increment 3.09 WriterFenceAdmission, Increment 3.08 SqlCloudSideEffectAdmission, and I-003 revision tests are not re-qualified. The s5c DISK_FULL unique-copy, Web OPFS/IndexedDB, and IO_ERROR / PUBLICATION_UNCERTAIN rows are not taken. The s5b “不能盲重试生成”, “保存中编辑/合并”, and “生成中的资源” rows are not taken. Remaining s3 error-table rows are not taken. Increments 2.74–3.14 already-landed slices are not re-qualified. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-011, I-003, I-012, I-013, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, I-014, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5d states that an import with the same projectId, revision, and hash is a duplicate and may open the existing project or create a fork, and must not overwrite; and that the same projectId and revision with a different hash is `IDENTITY_COLLISION` and must not overwrite. The “ask to open or fork” UI is not invented here. Future-schema read-only and copy-only migration are left listed in I-014 remainingScope and are not officialized in this slice.

This increment officializes only the no-overwrite identity bound as a DEV-PURE compiler at the official entry path `packages/studio_identity_collision_probe/lib/identity_collision_admission.dart`:

- A new import that does not match an existing projectId+revision is admitted (`duplicateImport=false`, `overwritten=false`).
- A same projectId+revision+hash import that does not claim overwrite is admitted as a duplicate (`duplicateImport=true`, `overwritten=false`).
- Claiming overwrite on that duplicate is `DUPLICATE_IMPORT_NO_OVERWRITE`.
- A same projectId and revision with a different hash is `IDENTITY_COLLISION`.
- `casDbGapRequalified`, `i011CrashRequalified`, `i014RestoreInvented`, `forkNewIdRequalified`, `migrationCopyRequalified`, `unsupportedFeatureReadonlyRequalified`, `restoreEventSeqRequalified`, `flutterWidgetTreeInvented`, and `zipSlipRequalified` stay false.

`tools/spikes/identity_collision/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s5d import identity no-overwrite bound is officialized at this admission. I-014 remainingScope (ID remapping, future-major read-only, restore as a new revision) stays open, and a product RestoreService is not invented, so I-014 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i014-identity-collision/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this identity-collision admission, Increment 2.51 restore event-seq, already-official I-014 zip-slip / fork-new-id / migration-copy / unsupported-feature-readonly conclusions, or invent an I-014 RestoreService. Future-major read-only and ID remapping may be considered only if they can be bounded without re-qualifying “不支持feature只读保留” or inventing a RestoreService. Do not re-qualify Increment 3.14 CasDbGapAdmission, I-011 crash leftovers, AtomicFilePublisher, files_test, or save_crash_test. Do not take s5c DISK_FULL unique-copy, Web OPFS/IndexedDB, or IO_ERROR / PUBLICATION_UNCERTAIN if that would re-qualify those leftovers or claim V-007.
