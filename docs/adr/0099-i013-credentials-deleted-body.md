# ADR 0099 — Official I-013 credentials and deleted body are not packed into the admitted archive

## Status

Accepted for Increment 1.92 as a bounded slice of the original I-013 remainingAcceptance item “凭据/已删正文不入包”. Official admitted embedded `ProjectArchive` packages carry only the frozen current snapshot and declared blobs; `manifest.sessionArchive` stays null; superseded document body, sessions, credentials, and the command journal are not zip entries. A planted non-null `sessionArchive` is refused as `ARCHIVE_VERSION_UNSUPPORTED` and does not authorize credentials into the package. I-013 remains partial. `fullTaskComplete` stays false.

## Decision

Spec s5d states that the default `sessionPolicy` is excluded, `manifest.sessionArchive` is null, and the package must not retain sessions, summaries, FTS/RAG/analysis caches, credentials, approvals, leases, download tokens, or temporary files. Already-deleted body must not ride along in a current-revision package. The already-admitted `ProjectArchive` implements that bound: it writes `sessionArchive: null` and `packMode: embedded`, packs only `manifest.json`, `checksums.json`, the current snapshot, and declared blob `packagePath`s, and `verifyBytes` refuses a non-null `sessionArchive`. `forkLocalProject` is documented never to migrate approvals, sessions, secrets, or runtime file handles through the archive. Existing `files_test.dart` officializes archive roundtrip, hostile ZIP paths, and rejection of unknown manifest fields / unlisted entries, but it does not officialize this I-013 remainingAcceptance wording, and it is not reused, weakened, or rewritten.

This increment adds:

- `packages/studio_store/test/i013_credentials_deleted_body_test.dart`: after a committed title change, the store still holds the superseded body in an earlier snapshot, but a current-revision archive has `sessionArchive == null`, contains only the admitted manifest/checksums/snapshot entries, and does not include the superseded body, sessions, or credentials; a planted `sessionArchive` object with credentials is refused as `ARCHIVE_VERSION_UNSUPPORTED` and leaves the original package unchanged.
- `packages/studio_sdk/test/i013_credentials_deleted_body_test.dart`: the same current-revision exclusion holds on the already-admitted workspace edit + `ProjectArchive.save` path.

Existing codes are not retargeted. Official InversePatch kind stays `restoreSnapshot`. Production algebra is unchanged; a genuine in-scope leak would have been fixed narrowly and reported, and none was found. Linked/proxy-only pack modes, running-job pending reports, and live tombstone filtering of old backup imports are not invented.

## Consequences

The I-013 remainingAcceptance item “凭据/已删正文不入包” is cleared at this already-admitted embedded-archive bound. This is not a complete I-013: “运行job归档固定rev并报告pending” is not officialized (job archival and pending-job reports remain unfinished; they are not invented). “不可打包资源显式manifest” is not officialized (the admitted embedded opener requires `missingExternalRefs` to be empty and does not open `packMode=linked`). “取消无半包发布” is already official in `save_test.dart` and is not re-qualified. “保留策略不删可达blob” is already official in `files_test.dart` CAS GC and checkpoint-retention suites and is not re-qualified. Those four remain listed rather than being silently reduced. I-012 leftover remainingAcceptance, I-008 leftover remainingAcceptance, I-011 leftover remainingAcceptance, and V-005 remainingAcceptance including “durableRevision零丢失” stay listed. I-007 is not started. Closed I-005 section-3 rows are not opened. SQLite schema is not expanded to v10.

## Evidence

`docs/implementation/evidence/i013-credentials-deleted-body/`.
