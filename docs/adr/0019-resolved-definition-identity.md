# ADR0019 — resolved frozen definition identity, not render equivalence

Status: bounded I-002 increment1.12; original full task not complete. Original s5a
requires canonical entity data plus sorted resolved rendering dependencies, excluding
reverse parent edges/unrelated project title. Original104/87 acceptance/dependencies
unchanged. No SQL schema migration, new registry/transport/storage subsystem.

## Implemented identity profile

Pure-Dart `DefinitionFingerprinter` explicitly resolves current or retained exact
(kind,id,version). Never follows latest. Frozen bytes must be <=1MiB strict full
Project2 snapshots with correct hash/origin and an actual exact target. The existing
closure checker still enforces declared resource roles/dependency pins and depth8.
Snapshot registration fingerprints all registered asset/sequence/image definitions,
not just the selected literal target. Same version with changed resolved identity
fails IMMUTABLE_VERSION_CONFLICT even if the literal Sequence JSON is unchanged.

The profile includes canonical entity data and sorted dependency fingerprints:
clip -> exact frozen media/effects; sequence -> clips/captions/audio recipe and
unversioned bus state; bus -> forward inputs/effects, including actual mix48k solo
recipe; image -> source/mask/effects/font references and forward layer hierarchy;
core effect -> mask/font dependencies. Source blob identity includes hash/bytes/role,
not its packaging locator. Project title is outside every entity definition.
Effect.owner, clip.trackId, track.sequenceId, bus.outputBusId and layer.parentId
reverse edges are excluded; layer hierarchy is re-expressed as forward children.
Unknown extension/required-feature/vendor LUT and unqualified transition semantics
fail closed. Track/sequence-owned effect stack ordering has no qualified consumer
in this profile and fails DEFINITION_PROFILE_UNQUALIFIED instead of silently
omitting those owner-only edges or inventing order. Missing font has an explicit missing marker, never system font lookup.

Context hashes/decoded documents/typed lookup indexes are cached; no repeated deep
project clone per dependency. Limits8192 visits/96 internal recursion and source
nesting8 fail explicitly. Only exact declared paths are followed; hash/ID-looking
opaque text is not recursively interpreted. Snapshot fingerprints are scoped while
version consistency is checked across that origin project.

## Real consumer connection and current edit safety

`verifyDefinitionTransition` is called inside the existing repository commit before
snapshot/definition/pin publication. If a current sequence keeps its version while
resolved dependencies change, the transaction rejects. The first actual native AAC/service regression exposed SetMasterAudio changed an
unversioned bus without advancing its owning sequence. That production edit now
allocates exactly one new sequence version; duplicate/no-op allocates none. Rename/title changes do not conflict.
Resource panel report now exposes the root definition identity or unqualified code,
explicitly `provesRenderEquivalence=false` and persistent hash-profile upgrade=false.
No writable renderer admission was widened. Unsupported fonts/masks/imageDocs/LUT/
library/retained execution remains read-only/refused, not stripped or silently baked.

Tests compare a changed unversioned bus dependency with actual Dart mix48k PCM
output (gain/pan), and rerun the existing real native AAC/edit/save/import/export
and private service paths. This is an actual dependency-consumer consistency proof
for that audio case, NOT general visual/audio equivalence, new GPU node/texture
ownership or physical clock qualification. A hash is not a decoder/renderer proof.

## Deliberate remaining boundary: persisted historical hash profile

Existing v9 entity_versions raw/legacy content_hash rows are NOT silently rewritten
or treated as the new profile. The new commit guard compares current before/after
states; it does not solve all non-current historical version reuse, migration of
legacy hash rows or arbitrary story/library/plugin definition equivalence. Those
need an explicit compatible historical qualification, not a hash-match bypass.
No new persisted certificate may substitute for source/native/admission/rights,
writer/fence or immutable SQL checks. Other original Schema/resource consumers and
I-022 full RenderGraph qualifications remain unfinished.

## Actual corrections / evidence

Initial new tests omitted a contracts import and exposed an old depth-test fixture
that changed clip source versions without raising clip/sequence versions. The
fixture now raises the actually changed versions; the original depth8 rejection
is retained, not weakened. Review also corrected nested resolution to use the
owning snapshot rather than the outer latest document, registered all current media
definitions in each frozen snapshot, and cached costly context access/forward image
hierarchy traversal. Failures are retained under implementation/evidence/definition-
identity. Three executed review/fix rounds and exact frozen commands/source hashes
are recorded there. A subsequent actual private-service run again timed out with state=interrupted,
reason=underrun after resume. The complete failure is retained; old intermittent
audio underrun remains unresolved, not hidden by native AAC or isolated successes. No RTC
retry/policy change, release/physical/nonLinux or full original-task pass is claimed.
