# ADR0017 — non-proxy resource closure and usable read-only preservation

Status: bounded file workflow, NOT full I-002/I-013/I-014 or renderer completion.
Source: original s5/s5a core Schema and s5d ResourceClosureResolver/opaque remapper,
plus continuing user t82/t83/t84 and this non-proxy resource instruction.
No original104 export, original87 acceptance/dependency or Project core field changed.

## Do not conflate resource integrity, business capability and execution

Registered pure-Dart walker covers all declared blobs, asset originals/generated
sources and proxies/maps, fonts, mask effects, image-layer masks, license evidence
and declared retained-source dependencies. ImageDocument/source/font FK, layer and
sequence cycle semantics remain the existing full validator's responsibility.
Missing font Blob declaration is a RESOURCE diagnostic, not a fabricated invalid
Project schema: external font fingerprints can be structurally valid. Missing
collected bytes, metadata-role mismatch, external media and opaque closure are
separate report categories. Hash-looking strings are never guessed as references.

Current core has NO first-class LUT/library pin type. Unknown library extension
and vendor/LUT effect parameters are retained opaque and produce
UNRESOLVED_EXTENSION_CLOSURE; no library/profile is downloaded. Retained definition
JSON recursive interpretation is not qualified: declared hashes are inventoried
but complete packaging/fork refuses until an actual registered walker exists.
Model profiles/license/package fingerprints are kept as references; reproduction
omission is explicit. License/embedAllowed facts are reported without granting
permission. No privacy, sharing, budget, rights or provider authority is inferred.

Report distinguishes declared/reference closure, hash+size integrity of explicitly
collected bytes and formatQualification=notRun/renderExecutable=false. Even a
hash-valid file can be an unusable font/image/LUT. No font install, media decode,
plugin execution or rendering is triggered. sourceCompleteness remains unqualified;
an embedded ZIP with all declared bytes is NOT certified selfContained/renderable.

## Actual file workflow, not weakened editor admission or new database subsystem

Native App has a separate READ-ONLY resource panel:
explicit JSON → missing/role/opaque report → explicitly select each resource file
(actual hash must match one declared Blob) → local collection confirmation bound
to root+collected hashes → new-output metadata or embedded resource archive →
reopen archive → limited registered-ID fork → explicit new save.

This is import into a read-only FILE VIEW, NOT writable StudioWorkspace import or
an active-project switch. No SQLite row, CAS object, pin, owner, history or lease
is mutated. Archives own their copied bytes and never rely on an unpinned CAS
object. Existing namespace quota/pin/GC/pruning/recovery rules remain untouched;
there is no new SQL migration/table, alternate scheduler or background cleanup.
Users can preserve opaque metadata JSON verbatim in value (canonical encoding),
but unknown closure blocks complete archive creation and fork. Last valid loaded
snapshot stays after rejection. No path from document metadata/locator is opened.

New ProjectArchive preservationOnly is explicit. It retains existing ZIP central-
directory/CRC/path/duplicate/checksum/hash/size/expanded-size validation but does NOT
claim local edit/proxy/render admission. VerifiedArchive carries preservationOnly.
Default archive verification/restore still requires strict local editing profile
and derived-resource qualification; no old endpoint silently gets this mode.
Input and output format remain existing studio-project2.0; no new core enum.

Session limits: JSON1MiB, individual resource64MiB, total collected128MiB; archive
reader128MiB compressed/256MiB expanded. Reads are bounded while streaming and
check source changes; collection is private copied bytes, not deferred mutable
file paths. General existing CAS archive loader is now bounded before allocating
beyond remaining expanded budget as well. These are slice caps, not physical RSS,
volume-free-space, ENOSPC or full per-volume reservation qualification.

AtomicFilePublisher gains only Linux same-directory new-output publication using
mature POSIX link(2)+fsync/unlink staging. Unlike rename it atomically refuses an
existing target even if another publisher wins; no existing file is replaced.
Unknown volume free space is disclosed. Fsync failure can mean publication exists
with durability unknown, never a fake success. Cancellation before publication
removes only this operation's stage; no user original/output is auto-cleaned.

## Registered fork, not recursive ID guessing

Narrow profile remaps declared project/assets/streams/sequences/tracks/items/
buses/rights/image layers/fonts/effects and their exact registered local reference
fields. Hashes, versions, external license/model/provider IDs and literal text are
not rewritten. Actual first test found missing track.sequenceId/clip.trackId
backlinks; fixed typed fields and revalidated complete Project semantics.
Unknown extensions, retained definitions, story/generation/caption/group/transition
profiles refuse rather than pretending all references were remapped. Fork is
read-only revision0/new IDs in selected namespace; no approval/job adoption.
Persistent ImportMap provenance is not supplied in this slice and remains an
original I-014 gap; no complete fork-service claim.

## Evidence boundary

Real official fixed Flutter SDK Roboto font + synthetic PNG mask + existing
synthetic MP4 are read/collected, saved as JSON/archive, reopened by a separate
Dart process, forked and reopened with hash/reference identity checks. Actual
widget load/collect/consent/archive/reopen/fork proves active SQLite head and CAS
inventory unchanged. Pure graph/opaque semantics run in actual offline Chrome;
this is NOT Web native-file preservation, RTC or physical multi-device validation.
Only isolated fixtures are written/deleted. First SDK fork and UI fixture-path
failures are retained. Three review/correction rounds and final source hashes are
in implementation evidence. Audio underrun remains unresolved; no old182/full
migration/release/audio-stress results are attributed to this source.
