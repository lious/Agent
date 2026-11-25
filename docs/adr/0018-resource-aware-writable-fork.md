# ADR0018 — original retained snapshots and resource-aware writable forks

Status: bounded implemented increment1.11; I-002/I-013/I-014 remain partial.
Original s5a frozen-version/full-Project snapshot contract and s5d reference closure,
explicit fork/ImportMap and hostile input rules apply. Original104/87 acceptance
and hard dependencies are unchanged; XD scheduling/security protocols unchanged.

## Retained definitions are actual full Project2 snapshots

After explicit byte collection, only the existing retainedSources kinds asset,
sequence and imageDocument are walked. No new extension registry/schema/remote
resolver was invented. Hash-verified <=1MiB definition bytes must parse as a full
strict ProjectDocument in the same origin project/namespace, containing the exact
requested kind/id/version. No latest fallback. Every declared nested Blob must
be present in outer declarations with matching byte count/role and in the explicit
dependencyBlobHashes pins. Nested opaque/LUT/library data remains unresolved.
Traversal is bounded to depth8/64 references and rejects active cycles, conflicting
literal target definitions, missing pins/origin/version/hash/strict JSON errors.

This is **full-snapshot reference closure**, not a nested renderer or complete
resolved render-dependency definitionContentHash implementation. Format capability
for font/mask/LUT remains notRun; sourceCompleteness remains unqualified and
renderExecutable=false. Retained snapshots can now be collected/archived/reopened
read-only after this check. Writable admission still rejects retainedSources.
Unknown semantics are preserved and refused, never deleted to get a writable root.

## A real but intentionally narrow writable path

The native resource panel offers a separately labelled explicit consent action:
qualify and open a NEW writable fork. It requires a collection review hash, current
active document hash, the existing strict writable profile and existing
TimelineVideoGraph compiler (no captions/effects/retime/scaling/nonblack background
etc silently ignored). Sequence duration is capped at120s for this increment.
All declared bytes must be collected. Fonts/masks/imageDocuments/library/LUT/models
are NOT made writable merely because their bytes/hash are present.

The SDK reuses namespace maintenance lease, byte reservation and verified CAS
publication. Actual native probe facts for every stream (excluding remapped IDs)
must exactly match declarations, VFR is refused, video first-frame decode checks
the existing bounded SDR/pixel format path; audio uses the actual bounded decoder
for a1024-sample PCM block. Stored proxies retain exact source/map/derivation
qualification. The final CAS integrity pass and final repository writer/revision/
selected-project fence precede publication. No URI/locator is followed, no cloud,
plugin/model/font installation, credential or new network endpoint is involved.

First-frame/PCM-block checks are NOT a claim that every frame/sample in an entire
source has decoded successfully. Normal preview/export still perform runtime
validation; corrupt later media can fail without publication of a partial export.
Existing AAC/mux/atomic cancellation rules remain unchanged.

## Durable provenance and atomic registration, not a new storage subsystem

One additive SQLite v9 table, import_maps, stores the original-spec ImportMap:
origin(namespace,projectId,revision,hash) -> local(newId,0,hash), exact registered
entity ID mapping, no historical revision/session/job-resume binding. Existing v1-v8
DDL/checksums/runtime3.54.1 gate are unchanged. Old readers refuse newer stores.
The local fork mapper now enumerates only declared supported entity tables and
nested streams/tracks/items, not arbitrary `id` keys in opaque JSON.

Within the existing repository transaction: validate active writer/hash/selection,
create definitions and role pins, record hash-verified map, select new project,
acquire writer and capture checkpoint. Any SQL failure rolls all of these back.
A real child is SIGKILLed after map+selection, before COMMIT; recovery exposes only
the old selected project. Successful reopen has the entire new project and map.
Original project/head/history/resources are not deleted. A repeated stale active
hash refuses; a second deliberate NEW-fork action may create a distinct copy.
No imported history, origin mutation, automatic pruning or unknown-object repair.

CAS bytes written before a later qualification/fence failure remain valid counted
unadopted objects under existing conservative GC rules. Reservations and operation-
owned PCM staging are released; no unsafe eager deletion of shared/original data.
The map remains local DB provenance in this slice, not a portable session/history
migration or full previous restoreArchive API provenance upgrade.

## Verification boundaries and failures

Native source/PCM/AAC export, actual UI click, SQL rollback, takeover, isolated
SIGKILL, v8-v9 failure/retry and actual historical v4-v8 -> v9/runtime refusal are
recorded under implementation/evidence/resource-admission. Full task closure is
not inferred from test volume. The first positive fixture correctly failed because
the old schema-only golden declares profile=null while the native stream reports
its real profile. It was NOT weakened: the successful fixture now comes from the
actual importer (separate origin namespace), with the original golden unchanged.

A broad run also genuinely failed the tagged Pulse test without its required
private service endpoint (AUDIO_DEVICE_LOST). Failure retained; the documented
isolated real Pulse harness is then used serially, not skipped/mocked or pointed
at the box desktop audio service. Earlier intermittent underrun remains unresolved.
No physical sound/DAC/AV synchronization, nonLinux/device/RTC or production release
qualification is claimed. Full60s qualification, CTest/ABI and full repository gate
are not rerun in this slice. Frozen sources, exact counts and commands in summary.
