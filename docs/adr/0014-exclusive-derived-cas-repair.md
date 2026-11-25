# ADR0014 — explicit, exclusive, source-qualified preview CAS repair

Status: implemented Linux development slice; not whole I-002/I-021 acceptance.
Original104 specifications and original87 acceptance/dependencies are unchanged.

## Authority and limits

Repair is NOT import, relink, recipe conversion or original-file repair. A user
selects a clip and explicitly authorizes repair of its existing registered
CFR/SDR preview pair. The SDK re-probes/re-hashes the original, really regenerates
native RGBA/PTS-map stages and validates source facts/frame/blob/map checksums.
Both generated hashes must equal the already referenced hashes. Incompatible
recipes/decoder bytes fail closed; Admission is not switched off.

A stable namespace maintenance lease spans generation/publication. A synchronous
SQLite BEGIN IMMEDIATE transaction checks project hash/revision/writer fence and
scans EVERY namespace immutable-object hash and every recognized project root.
The snapshot table also stores command intents/entities: these are hash-checked,
not incorrectly parsed as roots. Malformed/future root candidates still reject.
All target occurrences must be canonical registered preview resources of the
same project and original. Other-project blob_edges, original/unknown roles,
unowned declarations or >10000 immutable objects reject before publication.
Default history/pins are retained; old revisions of the SAME project can benefit
from restoring their identical expected bytes. No project metadata revision is
created by a successful repair.

## Database/CAS identity — no retrospective ownership assumption

Different SQLite files can otherwise be configured to share the same namespace
CAS. Therefore fresh EMPTY namespaces register a durable database-path identity;
every SDK database opener leaves a permanent usage marker. Repair requires that
known-fresh owner and exactly one matching database usage, checked again just
before publication. Legacy nonempty/unbound namespaces, moved DB identities,
unknown/partial markers or another DB user fail closed. They are not silently
claimed or retroactively proven exclusive. Native editing/export/discard paths
are not granted extra permissions. Future explicit verified migration is needed;
legacy users can keep original-only archives and rebuild in a fresh namespace.
These markers are trusted-local filesystem evidence, NOT signatures against an
OS owner. Archive/peer imports cannot create hidden owner/proof/audit markers.

## Publication and crash behavior

Only corrupt or missing canonical derived entries change. Existing valid bytes
are never replaced. Symlink/unknown targets, unsafe stages and >64MiB targets
reject. All candidates are checked before a durable prepared audit is written.
Same-directory fsync+rename+directory-fsync publishes each regenerated object.
Pair publication is deliberately NOT claimed atomic: a crash after the first
leaves it correct and the second still corrupt, never changes an expected hash.
A subsequent explicit regeneration repairs the remaining object. All hashes are
postchecked before recording verified. Prepared attempts remain auditable.
There is no automatic rollback of good bytes to corrupt bytes or automatic
trust in a prepared record. Filesystem errors after rename remain potentially
partial; next attempt rechecks actual bytes. Real SIGKILL tests cover this boundary.

Audit records retain hashes/context, not the old corrupt payload. They and owner
markers are excluded from archives/peer transfer and existing GC. Maximum256
attempt records; further attempts refuse rather than auto-prune. No history,
original, valid shared blob or external file is deleted. Namespace-wide quota,
configurable retention/pruning and audit-retention UI remain unfinished.

## Shutdown finding

Actual competing-writer tests exposed close() leaking resources after checkpoint
WRITER_FENCED. Shutdown now skips ONLY that prohibited stale checkpoint and closes
resources; other checkpoint failures still propagate. Already durable edits stay
in SQLite and the new owner's checkpoint is never overwritten.

Linux-only software qualification is not physical A/V, cross-device, non-Linux,
VFR/HDR, P0 or full release qualification. Prior underrun failures remain unresolved.
