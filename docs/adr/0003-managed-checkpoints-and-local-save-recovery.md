# ADR 0003 — managed checkpoints and recoverable Linux archive publication

Status: implemented development slice, not all I-011/I-012/V-005 acceptance.

Original `docs/studio/spec/s5b.md` and `s5c.md` remain authoritative and unchanged.
The archive-only baseline was insufficient: an autosave must NOT copy all media to a
ZIP every two seconds, and in-memory saved-revision flags cannot survive reopen.

## Implemented

* Additive checksum-verified SQLite migration v3; frozen v1/v2 DDL unchanged.
  Immutable checkpoints reuse verified committed snapshots. The latest pointer is
  nondecreasing. Head is still the FULL edit transaction, not the checkpoint.
* Save state is derived from joined checkpoints/receipts, not new writable dirty,
  durable or userSavedRevision counters. Explicit managed save creates a receipt;
  automatic checkpoints do not claim explicit save or an external archive ACK.
* Monotonic Timer policy: idle 2 seconds, maximum pending 30 seconds, 50 durable
  commits, immediate background/switch/close flush. A failed checkpoint retains its
  pending state and error. Default external-package autosave remains OFF.
* Archive request freezes revision/hash. Only identical snapshot/target/kind/owner/
  fence requests in one coordinator coalesce. Per-instance FIFO plus process-wide
  per-target FIFO plus cross-process file locks serialize publication. fcntl alone
  is insufficient for two publishers in one process. Reconciliation uses the same
  queues/locks and revalidates writer/target before its receipt.
* FULL intent → verify old archive and preserve hash-addressed backup → exclusive
  sibling stage → readback/hash → target-version/fence recheck → FULL publishing
  record → file flush/rename/directory fsync → FULL immutable receipt → success.
  Stages and lock handles are cleaned up before the result Future completes.
* Cancellation before publication preserves old output. Once publication starts,
  failure is uncertain, never a fake cancellation. A host must explicitly regrant
  the original target; verified bytes can then be synced and receipted WITHOUT
  overwrite or head rollback. Journal paths alone never authorize file access.
* Flutter shows persisted head/checkpoint/explicit/target state, managed-save and
  interrupted-publication verification controls, archive phases and cancellation.
  App lifecycle flushes local checkpoints, not ZIPs. Native export stays separate.

## Boundaries, not silently redesigned acceptance

This is a controlled local Linux filesystem adapter, not a general StoragePort
qualification. Same-UID hostile path replacement/OS or hardware lies are outside
its guarantee. Advisory locks do not stop unrelated programs: target hashes are
checked, but no capability-safe directory-fd/renameat2 CAS is claimed.

A verified old output is retained as `.studio-backup-<hash>.archive`; automatic
backup retention/GC and a recovery-fork UI for a physically corrupt SQLite DB are
not implemented. SQLite WAL recovery is real; log compaction, validated fallback
checkpoint+tail reconstruction and missing-revision reports remain unfinished.

The UI currently disables editing during its archive action, although the SDK is
actually tested with continued edits and frozen receipts. Unsaved TextField drafts
are NOT automatically committed/discarded on exit. There is no complete desktop
exit wait/cancel/draft confirmation state machine, background time guarantee,
provider permission-epoch integration, durable cross-restart waiter/request-id
mapping, or arbitrary ASS/audio/resource closure support.

50 real SIGKILL experiments cover ten kills at each named save phase (before
preparation, after verified stage, before rename, after publish before receipt,
after receipt before caller ACK). They are NOT physical power-cut, ENOSPC,
read-only-volume, SAF/iCloud/Windows or Apple fullfsync tests. Other micro-instruction
crash windows and process-killed media CAS ingestion are not exhaustively qualified.
No full-task status is promoted to complete.
