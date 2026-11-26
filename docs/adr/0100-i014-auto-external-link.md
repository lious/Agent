# ADR 0100 — Official I-014 refusal of automatic external-link resolution

## Status

Accepted for Increment 1.93 as a bounded slice of the original I-014 remainingAcceptance item “zip slip/炸弹/符号链接/自动外链均拒”. Only the wording “自动外链均拒” is officialized at the already-admitted bound. Writable local admission refuses a non-null `asset.externalLocator` as `FEATURE_NOT_IMPLEMENTED`; `projectResourceClosure` reports `EXTERNAL_MEDIA_UNRESOLVED`; `ProjectArchive.save` does not publish a package; `ResourcePreservationSession.openJson` does not fetch a planted HTTP locator or follow a planted file locator. Zip slip / bomb / symlink refusals are already official in `files_test.dart` and are not re-qualified or rewritten. I-014 remains partial. `fullTaskComplete` stays false.

## Decision

Spec s5d states that restore, fork, and import must never auto-fetch an external URL, resolve a locator, execute a plugin, install a model, or open a script. The already-admitted local-video asset schema permits `externalLocator` as an Id or null; `requireLocalEditingWritable` refuses any non-null value as `FEATURE_NOT_IMPLEMENTED` (the same gate used by writable `ProjectArchive.save` / `open`); `projectResourceClosure` records `EXTERNAL_MEDIA_UNRESOLVED` without obtaining bytes; and `ResourcePreservationSession` is documented never to follow locators or obtain files except an explicit `LocalFileGrant`. Existing `files_test.dart` officializes hostile ZIP paths (`ARCHIVE_UNSAFE_PATH`), advertised-size ZIP bombs (`ARCHIVE_LIMIT`), Unix symlinks (`ARCHIVE_UNSAFE_ENTRY`), unknown manifests, and unlisted entries, but it does not officialize this I-014 “自动外链均拒” wording, and it is not reused, weakened, or rewritten. `resource_preservation_test.dart` already treats a planted locator as opaque extension metadata for `UNRESOLVED_EXTENSION_CLOSURE` and is not rewritten.

This increment adds:

- `packages/studio_document/test/i014_auto_external_link_refusal_test.dart`: a legal local-video document remains writable while `externalLocator` is null; setting it to a valid Id is refused as `FEATURE_NOT_IMPLEMENTED`, `projectResourceClosure` reports `EXTERNAL_MEDIA_UNRESOLVED`, and a sibling sentinel file is not read.
- `packages/studio_store/test/i014_auto_external_link_refusal_test.dart`: `ProjectArchive.save` of that document is refused as `FEATURE_NOT_IMPLEMENTED` and does not publish a zip.
- `packages/studio_sdk/test/i014_auto_external_link_refusal_test.dart`: `ResourcePreservationSession.openJson` of a granted JSON that plants an HTTP locator (served by a local listener that records requests) and a `file://` locator does not issue any HTTP request or read the sentinel file; subsequent writable `ProjectArchive.save` is still `FEATURE_NOT_IMPLEMENTED` and publishes nothing.

Existing codes are not retargeted. Official InversePatch kind stays `restoreSnapshot`. Production algebra is unchanged; a genuine in-scope auto-fetch would have been fixed narrowly and reported, and none was found. `packMode=linked`, populated `missingExternalRefs`, a same-project `RestoreService` / `restoreVersion`, new recovery or migration modes, and overwrite of existing files are not invented.

## Consequences

The I-014 remainingAcceptance wording “自动外链均拒” is cleared at this already-admitted bound. The compound item is reduced only by that wording: “zip slip/炸弹/符号链接均拒” remains listed because those refusals were already official in `files_test.dart` and are not re-qualified. This is not a complete I-014: “恢复不倒退事件” is not officialized (same-project RestoreService `head+1` restore is not invented). “fork新projectId” is already official in `files_test.dart` archive fork and related suites and is not re-qualified. “迁移中断保好副本” is already official in `transactions_test.dart`, `resource_import_test.dart`, and checkpoint-retention migration-failure suites and is not re-qualified. “不支持feature只读保留” is already official in Increment 1.11 implementedScope and `persistent_audio_transaction_test.dart` and is not re-qualified. Those items remain listed rather than being silently reduced.

I-013 leftover remainingAcceptance stays listed in full. “运行job归档固定rev并报告pending” still cannot be officialized without invention (job archival and pending-job reports remain unfinished). “不可打包资源显式manifest” still cannot be officialized without invention (the admitted embedded opener requires empty `missingExternalRefs` and does not open `packMode=linked`). “取消无半包发布” and “保留策略不删可达blob” are already official and are not re-qualified. I-012 leftover remainingAcceptance, I-008 leftover remainingAcceptance, I-011 leftover remainingAcceptance, and V-005 remainingAcceptance including “durableRevision零丢失” stay listed. I-007 is not started. Closed I-005 section-3 rows are not opened. SQLite schema is not expanded to v10.

## Evidence

`docs/implementation/evidence/i014-auto-external-link/`.
