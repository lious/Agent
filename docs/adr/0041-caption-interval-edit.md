# ADR 0041 — Crop, split, and shift captions across a ripple or insert interval

## Status

Accepted for Increment 1.34 on the existing I-005 ripple delete/close, ripple trim, and insert paste/move commands, together with the already-admitted I-010 cue model. I-005 remains partial. I-010 remainingAcceptance is unchanged.

## Decision

`applyCaptionIntervalEdit` is a shared timeline-space transform for admitted cues. A close removes `[at, at+L)` and shifts later absolute cues by `-L`. An open splits at `at` and shifts the right side and later absolute cues by `+L`. Text is never rewritten. A right remnant gets a new id. A cue wholly inside a closed interval is dropped as a crop-to-empty, not a silent loss, and comes back on undo.

clipLocal cues follow their current host when that host still fully covers the stored local range, so an insert-move of an unsplit host does not split its cues at the destination hole. When the host is gone or no longer covers the cue, the same interval transform is applied and each remnant is rebound to a covering host (preferred original clipId if it still covers, otherwise the unique covering video or media). A remnant with no covering host refuses the whole command (`ANCHOR_OUT_OF_RANGE`). This path must not also follow already-transformed later clipLocal cues a second time. Insert-move applies the transform only after moved hosts are placed again, because those clips are temporarily removed while the destination hole is opened.

Source anchors stay `CAPTION_RICH_EDIT_NOT_IMPLEMENTED`. A locked caption track is `FIELD_LOCKED` for the whole group. Listing a caption track as a media ripple track stays `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`. MP4 text burn-in stays `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`; sidecar VTT is the export path. Manual timing flags are kept through this user-initiated timeline edit.

Insert-move still leaves a source gap. Explicit range close stays a separate command. includeLinks=false and already-anchored MoveClips follow stay unchanged. Auto-close as part of a move is still not a legal MoveClips mode. No new table is added.

## Consequences

Ripple delete, range close, ripple trim, and insert paste/move now crop, split, and shift cues through undo/redo, reopen, archive fork and sidecar export. Marker business, new-track, cross-project bake, OS clipboard, default-on-create clipLocal, source anchors, burned-in MP4 text, and I-006 remain closed.

## Evidence

`docs/implementation/evidence/caption-interval/`.
