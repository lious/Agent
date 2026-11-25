# ADR0020 — legacy definition rows remain legacy; actual history is authority

Status: bounded original I-002 increment1.13, not full I-002 completion. No new
registry, SQL table/schema migration, persisted certificate or renderer capability.
Original104, original87 acceptance/dependencies and separate XD10 remain intact.

## Decision and actual user benefit

Do not rewrite entity_versions.content_hash to pretend older algorithms are the
new definition profile. Keep each old hash, snapshot, command/revision/undo, pin,
archive byte and version counter intact. Before the current runtime publishes any
supported edit, resolve its known typed versioned definitions against actual
namespace/project-scoped historical snapshot roots. Roots come only from heads,
revisions and command before/after refs, not arbitrary/orphan snapshots or bare raw
hash rows. Validate each root hash, namespace/project and anchored revision. A
noncurrent version with different resolved dependencies fails. Proposed validation
cannot teach the history or allocate/publish a version.

Already-resolved core nodes are projected read-only by the existing fingerprinter;
there is no new semantic registry. Legacy raw hashes are reconstructed by the
unchanged old algorithm and recognized against the actual supporting snapshot.
A legacy raw mismatch is accepted only when its actual historical source proves
the SAME resolved identity (e.g. excluded reverse parent location); never from a
bare hash match, unknown raw row or missing counter. The old row is not updated.
Non-render/story definitions retain their existing strict legacy raw checks; their
full semantic/execution contracts are NOT newly qualified.

## Ambiguous legitimate legacy history

Actual pre-fix SetMasterAudio could change an unversioned bus with sequence version0
unchanged. Do not erase or relabel those older definitions as unique. Keep reading
and archiving them. Normal edits may preserve the exact current identity, but a
known alternate historical identity is NOT new-write permission for an ambiguous
version. Only the existing validated undoLatest path may restore its exact stored
before-ref, after namespace/hash/revision/writer checks. That path bypasses the
current-head-only transition guard, NOT the actual complete-history reuse check.
Fresh versions still use existing max counters; existing idempotency/CAS/fences,
transactions, receipts/events/outbox/pins and native admission remain in force.

## Bounded acceleration and invalidation

The proof ledger is rebuildable process memory, not persistent authority. It holds
at most16384 distinct digest/raw observations for one bound project. Once full it
clears itself and streams candidate-only decisions over paged128 anchored roots;
no check is skipped and no history is deleted. definitionHistoryCacheLimit0 forces
that same streaming path; invalid/over-max limits reject. Actual zero-cache tests
exercise it. A different project or SQLite PRAGMA data_version invalidates the
cache; any nested/outer SQL rollback clears unpublished knowledge. Only accepted
writes append knowledge. Thus other-connection writes and a failed transaction
cannot authorize future reuse. First write after reopen may need a history scan;
large-history performance is not a P0/physical qualification.

All writers on a file must use the current guarded implementation. The unchanged
schema9 does NOT fence older executables from co-writing the trusted-local DB;
logical SQLite namespace isolation is not an OS sandbox. No old-client downgrade
protection or new peer protocol/permission is claimed. A richer/unknown old root
that this bounded core profile cannot qualify remains explicitly unqualified,
not silently stripped, migrated or made executable. Read/open is not rewritten.

## Executed review/fault work

Three reviews checked: (1) old/current hash provenance and the old undo ambiguity;
(2) cache publication/rollback/external-writer invalidation and safe full-cache
stream fallback; (3) valid parent-location raw compatibility and actual old-library
crash recovery, archive/fork/reopen. Initial style diagnostics and a quoting error
in a fixture-only crash barrier are retained; no acceptance/assertion was relaxed.

The old-DB experiment compiles BOTH studio_store and studio_document from06a2545,
so it genuinely creates the old version0/bus0 -> version0/bus-6 history. It then
uses unmodified current code to refuse new reuse and undo/rename/re-edit while
verifying old rows/snapshot bytes exactly. A separate, explicitly instrumented
TEMP library mirror blocks after real history checks/legacy registration before
pins/head/COMMIT, receives actual SIGKILL, then unmodified current code reopens and
checks rollback. Production has no crash hook; this experiment is not an App or
unmodified-binary crash qualification. SQL late-failure and parent relocation use
isolated fixtures, not user data. See implementation/evidence/definition-history.

No new I-022 consumer/GPU effect, font/mask/image/library/LUT/retained execution,
physical AV sync, non-Linux or multi-device qualification. The known resume
underrun remains unresolved despite isolated passes. Next: original I-008/I-022
actual consuming graph/pixel and lifetime qualifications, not more hash registries.
