# ADR0015 — opt-in namespace CAS byte inventory and write reservation

Status: bounded Linux development slice, not full resource-budget/storage release.
Original104 exports and original87 acceptance/dependencies remain unchanged.

## Reuse and scope

Keep existing namespace maintenance OS lease, source maxImportBytes,64MiB preview
root/stage limits,2048-frame bounds, peer inbox64MiB quota and Harness
memory/slots/money budgets. These are intersecting limits, not replacements.
No duplicate SQLite budget table or new Project root field. A version1 private
StoragePolicy adds optional decimal-string casFileByteLimit and retention fixed
at preserveAll. Default has no extra byte cap and preserves ALL history/originals.
Setting/changing the policy requires explicit confirmation plus existing known-
fresh/single-database ownership proof. Legacy/shared unknown ownership refuses.

Inventory sums logical sizes of ALL regular files directly inside namespace CAS:
canonical originals/derived, managed stages, unknown files, owner/proof/audit and
budget metadata. It does NOT hash-verify or classify valid pins, recurse into
unknown directories, report allocated filesystem blocks/free volume bytes, or
include SQLite/WAL, peer inbox DB, external archive/export/audio temp volumes.
Unknown links/directories are reported (first16); configured writes refuse them.
Maximum100000 entries. UI inventory is a point-in-time observation; active stages
can grow, not a storage durability/closure assertion. This is explicitly NOT a
filesystem quota or proof that an arbitrary same-OS-user writer obeys the policy.

## Reservation and failure accounting

Same stable namespace OS lease serializes cooperating publishers across processes;
canonical lock paths prevent lexical aliases splitting the same-process queue.
Under that lease, require observed file bytes + conservative additional peak +
8192 administrative headroom <= configured cap BEFORE staging. Import reserves
captured source size and refuses growth beyond it before adding a chunk. Existing
source-change/hash/probe/role admission remains. Verified map/CAS byte writes use
the same wrapper; qualified foreign-source temporary generation is also covered.
Native preview build/repair reserves192MiB + assetCount*(1MiB+8192), intersecting
existing native/root bounds; this is intentionally conservative, not a prediction
of real file size. A smaller cap may reject a small preview rather than under-
reserve. This does not reserve RAM or guarantee disk-free space/ENOSPC immunity.

One persistent private reservation journal records active→released/failed.
Nested sequential publisher work uses the outer scope, not a double charge.
Successful or failed work releases accounting; bytes already published/left in
stages remain inventoried. If a process dies, only AFTER acquiring the same OS
lease can the next publisher reclaim abandoned accounting. It never deletes
stages, history or originals to obtain room. A real SIGKILL test holds the lease,
writes a real stage, blocks another publisher and proves post-kill reclaim while
that stage remains counted. Another test races queued imports with source growth.

No time-based stealing. No implicit cloud upload, history eviction, new deletion
API, or automatic application of a retention/pruning policy. Existing explicit GC
and narrowly owned crash-stage cleanup retain their previous authorization/pins
contracts; this budget feature does not invoke a cleanup operation to admit work.
Policy/journal fsync failures propagate, never claim successful admission. A
publication followed by journal failure can remain physically present; next
operation inventories actual bytes. Full volume failure/provider qualification
is still separate; injected caller failure is NOT an actual ENOSPC experiment.

## User path / remaining work

Namespace storage budget panel → read-only inventory → enter decimal cap (blank
unlimited) → explicit confirmation → Apply. Policy changes are not project edits;
project revision, originals/history and undo remain intact. Over-budget writes
explicitly refuse. Limits can be explicitly raised/disabled; default retention
cannot be changed from preserveAll in this release. Policy survives reopen/fork.

Configurable keep-N/age/named-version retention, pin/role/project-safe historical
pruning, full archive/export/SQLite/free-volume reservations, live reservation
management UI and original87 full acceptance remain unfinished. Their future
implementation must default to preserveAll and require explicit preview/consent
before applicable deletion; writing pruning code is not authorization to run it
on any user's existing data. All deletion tests here stay in isolated fixtures.
