# ADR 0222 — Official s5c a bad original is reported missing and must not be replaced with a fake image (I-011 leftover)

## Status

Accepted for Increment 3.23 as a distinct already-specified s5c leftover on I-011: a bad cache may be rebuilt, but a bad original is reported as a missing resource and must not be replaced with a fake image. I-011 stays partial and is not marked complete. Existing I-011 remainingAcceptance labels (各崩溃点注入后只开最后好snapshot+tail, 损坏唯一好副本不覆盖, Schema完整往返, and the Increment 3.14 CasDbGapAdmission note) are not silently rewritten or cleared. Increment 3.14 CasDbGapAdmission, I-011 crash leftovers, AtomicFilePublisher, files_test, save_crash_test, I-004 MISSING_MEDIA / Increment 2.86 ProxyDeliveryAdmission, and I-014 “migration keeps a good copy” are not re-qualified. ACK-lost receipt retry and crash-after-CAS orphan claim/GC are not officialized. A RestoreService, a placeholder image generator, a Flutter widget tree, and a WAL-checkpoint runtime are not invented. SQLite WAL recovery remains as already recorded in ADR 0003 and is not disabled. The same s5c PACKAGE_CORRUPT row’s migration, unique-DB overwrite, writer-lock, recovery-fork, and WAL-recovery sentences are not officialized here, because they would re-qualify I-014 migration, I-011 unique-copy, Increment 3.09 WriterFenceAdmission, or ADR 0003. Increment 3.22 AuditJournalAdmission, Increment 3.21 ArchiveLimitConsentAdmission, and Increment 3.16 FutureMajorAdmission are not re-qualified. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. I-014, I-013, I-012, I-020, I-011, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5c states that a corrupt package is first copied read-only into an isolation area for inspection; that a bad cache may be rebuilt; that a bad original is reported as a missing resource and must not be replaced with a fake image; and that other recovery, migration, unique-DB, writer-lock, and WAL sentences apply on the same row. Those other sentences are not taken here.

This increment officializes only the cache-rebuild and no-fake-original bounds as a DEV-PURE compiler at the official entry path `packages/studio_original_placeholder_probe/lib/original_placeholder_admission.dart`:

- `cache` is admitted as rebuildable (`cacheMayRebuild=true`, `placeholderUsed=false`).
- `original` without a placeholder is admitted as a reported missing resource (`reportedMissing=true`, `placeholderUsed=false`).
- Replacing a bad original with a fake image is `PLACEHOLDER_ORIGINAL_FORBIDDEN`.
- An unknown kind is `ORIGINAL_RECOVERY_KIND_UNKNOWN`.
- `lastGoodSnapshotRequalified`, `uniqueCopyRequalified`, `schemaRoundtripRequalified`, `casDbGapRequalified`, `i004MissingMediaRequalified`, `proxyDeliveryRequalified`, `migrationCopyRequalified`, `writerFenceRequalified`, `ackLostRetryOfficialized`, `orphanClaimInvented`, `restoreInvented`, `flutterWidgetTreeInvented`, and `walRecoveryDisabled` stay false.

`tools/spikes/original_placeholder/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing `save_crash_test.dart`, `files_test.dart`, and Increment 3.14 suites are not rewritten.

## Consequences

The s5c no-fake-original bound is officialized at this admission. I-011 remainingAcceptance crash, unique-copy, schema-roundtrip, and Increment 3.14 wording stay listed, so I-011 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i011-original-placeholder/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this original-placeholder admission, I-011 crash leftovers, Increment 3.14 CasDbGapAdmission, AtomicFilePublisher, files_test, save_crash_test, I-004 MISSING_MEDIA, or Increment 2.86 ProxyDeliveryAdmission. Do not officialize ACK-lost receipt retry or crash-after-CAS orphan claim/GC. Do not invent an I-014 RestoreService. Do not re-qualify Increment 3.22 AuditJournalAdmission, Increment 3.21 ArchiveLimitConsentAdmission, Increment 3.20 ArchiveSpaceAdmission, Increment 3.19 SaveAsNamedVersionAdmission, Increment 3.18 PackageProjectionAdmission, or Increment 3.17 WebPublicationAdmission. Do not take I-014 “ID重映射” or “旧版本恢复新rev.” Do not claim a 60s WebCodecs/OPFS roundtrip, a V-007 production lock, or an ENOSPC measurement. Do not take s5d “再分发/执行许可分开” if that would re-qualify `FONT_REDISTRIBUTION_FACT` or `MODELS_REFERENCED_NOT_DOWNLOADED`.
