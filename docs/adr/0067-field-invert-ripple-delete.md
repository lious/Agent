# ADR 0067 — Field-aware invert of a prior RippleDeleteClips command

## Status

Accepted for Increment 1.60 as a bounded slice of the original I-005 remaining work on the field-aware invert matrix (s3 / s5a). I-005 and I-010 remain partial. This increment does not claim a complete invert matrix. Official InversePatch `kind` stays `restoreSnapshot`. Linear undo/redo stay tip snapshot restores. Already-delivered RippleDeleteClips, RippleTrimClip, leave-gap TrimClip, SplitClip, ExtractAudioClip, UnlinkAudioVideo / LinkAudioVideo, SetAudioTrackState, and SetTrackState locked/unlock semantics stay unchanged. Video and caption mute/solo stay refused at admission with `FEATURE_NOT_IMPLEMENTED`; audio muted/solo stay `SetAudioTrackState`; `syncLock` is not toggled. This increment does not open auto-close as a MoveClips mode, expand the single-clip `MoveClip` button, or open new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, or I-006. A diverging unlink invert remains `LINK_OFFSET_MISMATCH`. Invert's version indexer continues to skip source refs (`streamId` present). Leaf-level rational `n`/`d` granularity is unchanged. This slice does not change field-invert list insertion order.

## Context

Increment 1.59 officially admitted invert of a prior non-tip `RippleTrimClip`. `RippleDeleteClips` was already the admitted caption-aware ripple delete, with a dedicated workbench button that does not depend on extracting persistent audio, but it had not been qualified as an invert-matrix target on a persist path with captions present.

A first document attempt inverted a ripple delete of a non-last remnant after a later marker edit. Field invert reinserted the earlier clip by appending it after later remnants, and `ProjectDocument` admission refused `IMPLICIT_GAP`. That error code is not retargeted, and this slice does not reorder inserted items. Official success is therefore invert of a ripple delete of the rightmost remnant, which restores the deleted clip and its cue at the end of the track.

## Decision

Officially admit invert of a prior committed `RippleDeleteClips` of a rightmost remnant that is not the undo tip. Only that command's delete write set is restored when those fields still match the command's after-image. A later unrelated `SetMarkers`, a later out-trim of an uninvolved earlier remnant, or a later text edit of an uninvolved earlier cue, therefore does not conflict: invert restores the deleted remnant and its cue, and keeps the later markers, trim, and revised text. A later leave-gap move of a remnant whose start was shifted by a ripple delete of an earlier remnant, or invert of the tip, is whole-group `UNDO_CONFLICT` and does not roll the database back. Invert of a non-last ripple delete that must reinsert an earlier clip is not this slice's official success path. Official workbench path uses the dedicated Ripple delete button and a later marker. Captions and markers are not burned into preview or MP4; export stays a VTT sidecar.

## Consequences

A complete invert matrix remains unfinished. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, I-006, MP4 burn-in, video/caption mute/solo, and syncLock remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered ripple delete, ripple trim, leave-gap trim, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/field-invert-ripple-delete/`.
