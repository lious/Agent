# ADR0016 — explicitly reviewed recovery-checkpoint index retention

Status: bounded implementation; NOT complete historical/resource compaction.
Source: original s5b checkpoint/named-version contract, s5d root-set/retention/GC,
and t82 continuing implementation plus explicit preserveAll instruction.
Original104/87 acceptance and dependencies are untouched.

## Preserve history first; distinguish index pruning from CAS GC

s5d describes design defaults of100-or7-day checkpoints, saved points and backup
windows, long-lived named pins, protected undo/redo/current/job/publication roots,
and7-day ordinary resource GC grace. The user's newer instruction makes our
runtime default **preserveAll**, overriding automatic default eviction, not
changing the original export. This increment supplies an explicit optional
keepLatest1..10000 CHECKPOINT INDEX policy only. It is NOT the full count+age union,
saved-point rotation, incremental backup schedule, or deletion of command history.
Namespace CAS policy remains preserveAll for all immutable history/resources;
this independent per-project index policy does not relax CAS ownership/pin rules.
No created-at timestamps are invented for old checkpoints. Those qualifications
remain unimplemented, and original tasks remain partial.

SQLite schema8 adds policy, permanent named-checkpoint labels and prune receipts;
checksums for1..7 and approved SQLite3.54.1 runtime gate remain unchanged. Named
labels map a unique case-sensitive name (1..128 chars, no controls/outer whitespace)
to an immutable checkpoint; duplicate names refuse, never overwrite. Names cannot
be automatically removed. Existing snapshots, revisions, commands/inverses,
receipts, event/outbox history, entity definitions, blob_edges and ALL physical
resources are retained unconditionally. Thus original/unknown/derived roles,
undo/redo/resource pins and other projects remain protected by construction.
This policy cannot free CAS bytes or shrink the DB file; UI explicitly says so.

Candidates are only current-project unnamed, unsaved checkpoint index entries
outside selected recent count. Current head/latest recovery pointer, ANY save
operation (including failed/uncertain), named label and any project with a Harness
plan are pinned. Session pins are conservative even after completion; automatic
session-retirement is not invented. Other projects/namespaces are never selected.
Unknown/malformed/cross-project checkpoint snapshots or label/pointer refs fail
closed. Up to10000 rows/labels and64MiB cumulative root text are inspected; larger
history refuses rather than truncating candidates. Pruning never removes a
blob_edges resource pin or snapshot and never calls CAS GC, so it cannot bypass7-day resource grace.

## Explicit actions and atomic audit

Native App: optional permanent named pin; explicitly configure policy (no delete),
read-only dry-run, inspect policy/candidate count/first20 IDs and bound review hash,
then separate confirmation+apply. No timer, quota error or startup applies it.
SDK enforces existing fresh single-database namespace ownership and shared
maintenance OS lease; legacy/shared namespaces refuse configure/review/apply.
Scope is local workspace metadata; policy/labels/audits survive reopening original
workspace, not a portable fixed-R fork's newly created history. Original workspace
labels/receipts are never removed by that fork. There is no external deletion.

The review hash binds namespace/project, revision/root hash, writer owner/fence,
policy, named pins, full checkpoint entries/protection reasons and candidates.
Apply recomputes it under BEGIN IMMEDIATE (same DB transaction); edits, new pins,
checkpoint changes, policy changes or writer takeover invalidate stale reviews.
Storage authority and writer/revision are checked before and after deletion.
Deletes and full review+result receipt commit atomically. Same receipt retry with
same live writer/revision is idempotent; foreign project or new writer cannot
reuse the old receipt. Last20 project-scoped audit receipts can be read in UI;
readback verifies recorded review content hash. No fake byte-freed total is given.

## Actual qualification / limitations

Tests only create isolated systemTemp fixtures. Real SQLite trigger failure AFTER
index deletion and real final-authority failure roll back both deletion and audit.
A real child invokes the production transaction, holds namespace OS lease and
blocks after deletes+audit insertion but before COMMIT; SIGKILL proves reopen
retains all old indexes/no receipt and next fenced writer can re-review/apply.
Fixture worker refuses paths outside its dedicated temp prefix.

Real native source import/proxy generation, named pin, explicit pruning, undo,
archive/fork/reopen and proxy reuse preserve source/derived bytes. Actual clickable
widget configuration/dry-run/consent/apply is tested. Initial widget assertion
looked for offscreen lazy text and failed; retained evidence, corrected scrolling
and waits on actual busy lifecycle, not ignored hit-test warnings or fixed delay.

Real v7→v8 layout upgrade, injected partial-DDL rollback, reopen, integrity/FK
checks plus existing selected transaction/save/history tests are run. This is NOT
a rerun of the full old-runtime/v4-v7 matrix, full182, release/Chrome/audio stress
or physical multi-device/platform qualification. Intermittent underrun remains
unresolved. Full resource closure and49 planned tasks remain subsequent work;
this increment must not grow into an unbounded new storage subsystem.
