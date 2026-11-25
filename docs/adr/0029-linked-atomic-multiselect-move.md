# ADR0029: linked same-track atomic selection move (I-005 subset)

Status: implemented restricted slice; original acceptance/dependencies unchanged.

## Contract and actual user path

Original `docs/studio/spec/s3.md` rows selection, links, copy/multi-move and undo
require whole-set collision evaluation, exact offsets, whole-group refusal and
one explicit command. `MoveClips` implements **same existing tracks / reject /
includeLinks=true only**. It does not silently accept target-track, insert,
overwrite, unlink/Alt, snap, grouping or clipboard semantics. Those APIs are not
exposed here. This does not complete I-005.

The shared native workbench offers per-video/audio-clip checkboxes, explicit
positive frame count (shared field), candidate +/- preview, expanded linked IDs,
and a separate one-time commit/cancel. Selection is viewport-only. Selection is
not silently filtered after another edit/fork: stale IDs refuse until explicitly
cleared. This is a button-confirmed candidate, NOT pointer-drag/snap completion.
SDK gestures bind canonical requested IDs, base root/revision and writer fence;
different requested sets do not merge even if a link closure happens to match.

## Atomic geometry and preservation

Pure domain code expands the complete admitted LinkGroup closure before edits;
track/field locks, missing/unsupported selection, negative starts, video-frame
and 48kHz-audio-sample grids reject the whole operation. It never rounds linked
audio independently. All final intervals are collision-checked together after
conceptually removing the whole moved set. Gap identity is reused only for exact
unchanged intervals. Dissolves require both endpoints, move cut by the same Q,
check transitions locks and revalidate unchanged source handles. Clip source
ranges/time maps/local effects/keyframes/audio automation/link offsets remain
unchanged; admitted absolute captions stay absolute. Rich caption anchors and
other unsupported semantics retain existing refusal/opaque policies. Captions
still explicitly refuse pixel preview/encoding, never disappear from output.

Move is not implicit ripple/shorten. Prior duration is retained; when an audio
end is between video frames, necessary video tail Gap ends at **ceil project
frame**, never an illegal fractional-frame Gap. Source timing is unaffected.

Existing normal repository edit publishes definitions/root/journal/receipt/
events/outbox/pins atomically under expected revision and writer fence. Undo/
redo restore actual saved roots as new revisions, not recomputed moves. SQL
abort leaves no partial member update. Existing gesture same-ID retry after
rollback is retained; completed gesture cannot commit twice. Unknown history
continues to refuse rather than truncate. No new persistence schema/tables.

## Bounds, limitations and evidence

Canonical immutable selection rejects empty/duplicate/invalid IDs and is bounded
by the original 100000-item schema limit. Complexity is O(document + affected
track sorting), not O(frames); participation derives from the displayed same-track/link closure,
not the full selectable sync-lock/participating-track diff planner. Original balanced interval index and O(n) history
cursor performance remain unfinished. No field-aware selective collaboration
inverse, full NLE random operation matrix or other-platform qualification.
Current CPU/SDR effects, VFR refusal, native clock underrun/old-writer/RTC limits
remain unchanged. Linux widget/native tests are not physical device acceptance.
See `implementation/evidence/multi-move/` for exact frozen-source results and
retained preliminary failures. This local-only increment must NOT be pushed
until the prior commit_refs_rules refusal is compliantly resolved and allowed.
