# ADR 0213 — Official s5c CAS must be on disk before the DB references ready, and rename plus SQLite are not one atomic transaction (I-011 leftover)

## Status

Accepted for Increment 3.14 as a distinct already-specified s5c leftover on I-011: the DB must not reference a ready asset before CAS is on disk, and file rename plus SQLite must not be claimed as one atomic transaction. This increment does not officialize crash-after-CAS orphan claim or delayed GC, and does not officialize ACK-lost receipt retry (that clause is close to s5b “不能盲重试生成” and is not taken). I-011 stays partial and is not marked complete. Existing I-011 remainingAcceptance labels (各崩溃点注入后只开最后好snapshot+tail, 损坏唯一好副本不覆盖, Schema完整往返) are not silently cleared. I-011 crash leftovers, AtomicFilePublisher, files_test, and save_crash_test are not re-qualified. Increment 3.13 SharedLibraryAdmission, workspace_test.dart isolation, Increment 3.12 PreparedStageAdmission, Increment 3.09 WriterFenceAdmission, Increment 3.08 SqlCloudSideEffectAdmission, I-003 revision tests, and I-032 PlanGraph fencing are not re-qualified. A CAS runtime, an OS lock runtime, crash takeover, pending-publication reconciliation, a publish-path serial coordinator, a Flutter widget tree, a StoragePort runtime, a SAF or iCloud adapter, I-013 job archival, a muxer, and an I-014 RestoreService are not invented. Quote/apply and paid generation are not started. The s5b “不能盲重试生成”, “保存中编辑/合并”, and “生成中的资源” rows are not taken. Remaining s3 error-table rows are not taken. Increments 2.74–3.13 already-landed slices are not re-qualified. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. SQLite WAL recovery remains as already recorded in ADR 0003 and is not disabled. Store journal pragmas are not changed. I-003, I-012, I-013, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, I-011, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5c states that file rename and SQLite must not be called one atomic transaction, and that the DB must not reference a ready asset before CAS is on disk. The same row also describes crash-after-CAS orphan claim or delayed GC, and ACK-lost receipt lookup by commandId and inputHash. Those latter clauses are not officialized here: the crash path would re-qualify I-011 crash leftovers, and the ACK-lost receipt retry is close to “不能盲重试生成”.

This increment officializes only the write-order and identity bounds as a DEV-PURE compiler at the official entry path `packages/studio_cas_db_gap_probe/lib/cas_db_gap_admission.dart`:

- A path where CAS is not yet on disk and the DB does not reference ready is admitted (`dbReferencedReady=false`, `renameAndSqliteOneAtomicTransaction=false`).
- A path where CAS is on disk may let the DB reference ready (`dbReferencedReady=true`).
- Letting the DB reference ready before CAS is on disk is `CAS_NOT_ON_DISK_DB_NOT_READY`.
- Claiming that file rename and SQLite are one atomic transaction is `RENAME_SQLITE_NOT_ONE_ATOMIC`.
- `i011CrashRequalified`, `atomicFilePublisherRequalified`, `filesTestRequalified`, `saveCrashTestRequalified`, `ackLostReceiptRetryOfficialized`, `orphanGcInvented`, `sharedLibraryRequalified`, `quoteApplyStarted`, and `i014RestoreInvented` stay false.

`tools/spikes/cas_db_gap/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s5c CAS-before-DB write-order bound is officialized at this admission. I-011 remainingAcceptance crash, unique-copy, and schema-roundtrip labels stay listed, so I-011 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i011-cas-db-gap/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this CAS-to-DB gap admission, I-011 crash leftovers, AtomicFilePublisher, files_test, or save_crash_test. Do not officialize ACK-lost receipt retry or crash-after-CAS orphan claim/GC. Do not re-qualify Increment 3.13 SharedLibraryAdmission, workspace_test.dart isolation, Increment 3.12 PreparedStageAdmission, Increment 3.09 WriterFenceAdmission, or Increment 3.08 SqlCloudSideEffectAdmission. Do not take s5b “不能盲重试生成”, “保存中编辑/合并”, or “生成中的资源” if that would re-qualify I-033, I-040, I-011, ADR 0098, I-004 attach, I-013 archival, or I-024.
