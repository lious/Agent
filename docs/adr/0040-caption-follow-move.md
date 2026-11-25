# ADR 0040 — Follow clip-local captions when a host clip moves

## Status

Accepted for Increment 1.33 on the existing I-005 MoveClips and SetCaptions commands. I-005 remains partial.

## Decision

Admit the already-specified caption `clipLocal` anchor (host media clipId plus a clip-local range that fits the host duration). On MoveClips — reject, overwrite and insert, including later hosts shifted by insert-move — rewrite `timelineRange.start` to `hostStart + localStart`. Stored local range, text and offsets of unmoved members are unchanged. Absolute cues stay at authored times. New and imported cues stay absolute until the user runs “Anchor selected cue to covering clip”. Source anchors and rich caption fields stay refused on writable admission. Insert paste and ripple cue crop/split stay `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`. MP4 text burn-in stays `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`.

Auto-close as part of a move is still not a legal MoveClips mode. Insert-move still leaves a source gap. includeLinks=false still moves only explicit IDs; a cue follows only if its host moved. No new table is added.

## Consequences

A clipLocal cue travels with its host through undo/redo, reopen, archive fork and sidecar export. Making the cue absolute stops follow. Cue crop/split on ripple, defaulting new cues to clipLocal, marker business, and burned-in MP4 text remain closed.

## Evidence

`docs/implementation/evidence/caption-follow-move/`.
