# ADR 0230 — Official I-002 structural and business errors must be reported as separate classes

## Status

Accepted for Increment 3.31 as a distinct already-specified I-002 leftover, looked up more broadly after I-013 packing / session / omitted-history and recent archive-bound slices were exhausted of clean leftovers: structural errors and business errors must be reported as separate classes. I-002 stays partial and is not marked complete. Existing I-002 remainingAcceptance wording (1万次有理运算/往返无漂移；非法FK/交叠/overflow全拒；现有合成项目通过；结构与业务错误分开) is kept at the start and is not silently rewritten or cleared. This increment officializes only the last of those four labels at a DEV-PURE admission. It does not claim or re-run 10k rational roundtrips, illegal FK/overlap/overflow refusal, or existing synthetic-project passage. Schema v10 is not merged. Project `user_version` stays 9. The closed root is not extended with new fields. Unknown fields are not swallowed. A schema migrator is not invented. I-013 packing and archive admissions (including Increment 3.30 FixedRevisionArchiveAdmission, Increment 3.29 UnknownExtensionPinAdmission, Increment 3.28 ArchiveCountdownAdmission, Increment 3.27 LibraryArchiveAdmission, and Increment 3.06 ArtifactKindAdmission) are not re-qualified. I-013 job archival is not invented. I-003 revision tests are not rewritten. InversePatch kind stays `restoreSnapshot`. Production FTS/RAG is not claimed. I-013, I-011, I-014, I-012, I-020, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. I-002 stays partial. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

I-002 acceptance requires that structural errors and business errors be kept separate. Structural failures include schema, FK, overlap, and overflow problems. Business failures are policy or capability decisions on a document that is already structurally classified. The two classes must not be substituted for each other.

This increment officializes only that classification bound as a DEV-PURE compiler at the official entry path `packages/studio_error_class_probe/lib/error_class_admission.dart`:

- An `errorReport` whose `actualClass` and `reportedClass` are the same `structural` or `business` value is admitted.
- An unknown kind is `ERROR_CLASS_KIND_UNKNOWN`.
- An unknown class is `ERROR_CLASS_UNKNOWN`.
- Reporting a structural failure as a business error, or a business failure as a structural error, is `ERROR_CLASS_MISMATCH`.
- `rationalOpsRequalified`, `fkOverlapOverflowRequalified`, `syntheticProjectRequalified`, `schemaMigratorInvented`, `userVersionChanged`, `closedRootFieldsAdded`, `unknownFieldsSwallowed`, and `packingAdmissionRequalified` stay false.

`tools/spikes/error_class/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing I-002 schema/time suites are not rewritten.

## Consequences

The I-002 “结构与业务错误分开” bound is officialized at this admission. The other three I-002 remainingAcceptance labels stay listed and unclaimed, so I-002 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i002-error-class/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this error-class admission. Do not claim the remaining I-002 labels (10k rational roundtrips, illegal FK/overlap/overflow refusal, existing synthetic projects) without honest measurement evidence. Do not merge schema v10 or change Project `user_version`. Do not invent I-013 job archival or re-qualify Increments 3.06 / 3.27–3.30. The I-013 packing / session / omitted-history cluster and recent archive-bound slices remain exhausted of clean leftovers. Do not take s5d “再分发/执行许可分开” if that would re-qualify `FONT_REDISTRIBUTION_FACT` or `MODELS_REFERENCED_NOT_DOWNLOADED`. Do not take s5d “遗忘屏障与流式竞态” if that would re-qualify I-029 DeletionBarrier.
