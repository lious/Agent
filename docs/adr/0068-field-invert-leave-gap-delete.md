# ADR 0068 — Field-aware invert of a prior leave-gap DeleteClip command

## Status

Accepted for Increment 1.61 as a bounded slice of the original I-005 remaining work on the field-aware invert matrix (s3 / s5a). I-005 and I-010 remain partial. This increment does not claim a complete invert matrix. Official InversePatch `kind` stays `restoreSnapshot`. Linear undo/redo stay tip snapshot restores. Already-delivered RippleDeleteClips, RippleTrimClip, leave-gap TrimClip, leave-gap DeleteClip, SplitClip, ExtractAudioClip, UnlinkAudioVideo / LinkAudioVideo, SetAudioTrackState, and SetTrackState locked/unlock semantics stay unchanged. Video and caption mute/solo stay refused at admission with `FEATURE_NOT_IMPLEMENTED`; audio muted/solo stay `SetAudioTrackState`; `syncLock` is not toggled. This increment does not open auto-close as a MoveClips mode, expand the single-clip `MoveClip` button, or open new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, or I-006. A diverging unlink invert remains `LINK_OFFSET_MISMATCH`. Invert's version indexer continues to skip source refs (`streamId` present). Leaf-level rational `n`/`d` granularity is unchanged. This slice does not change field-invert list insertion order or retarget `IMPLICIT_GAP`.

## Context

Increment 1.60 officially admitted invert of a prior non-tip `RippleDeleteClips` of a rightmost remnant. Leave-gap `DeleteClip` (`ripple: false`, the default) was already the admitted caption-aware leave-gap delete — a removed host's `clipLocal` cue becomes an absolute remnant at the same times rather than being dropped — but it had not been qualified as an invert-matrix target on a persist path with captions present. The workbench Delete button is leave-gap only when persistent audio has been extracted; otherwise it issues a ripple delete.

Unlike a ripple delete, a leave-gap delete writes a gap filler in the vacated range. A later leave-gap out-trim of the remaining left remnant remints that filler and therefore conflicts with invert of the delete. Invert of a non-last leave-gap delete that must reinsert an earlier clip is not this slice's official success path, for the same insertion-order admission reason already documented for non-last ripple-delete invert; this slice does not reorder inserted items or retarget `IMPLICIT_GAP`.

## Decision

Officially admit invert of a prior committed leave-gap `DeleteClip` of a rightmost remnant that is not the undo tip. Only that command's delete write set is restored when those fields still match the command's after-image. A later unrelated `SetMarkers`, a later text edit of an uninvolved earlier cue, or a later text edit of the leftover absolute remnant of the deleted clip's cue, therefore does not conflict: invert restores the deleted remnant, rebinds that leftover cue to `clipLocal` on the restored host, and keeps the later markers and revised text. A later leave-gap out-trim of the remaining left remnant remints the gap filler and is whole-group `UNDO_CONFLICT`, as is invert of the tip; neither rolls the database back. Invert of a non-last leave-gap delete that must reinsert an earlier clip is not this slice's official success path. Official workbench path first extracts persistent audio so the Delete button is leave-gap, then uses a later marker rather than a later left trim. Captions and markers are not burned into preview or MP4; export stays a VTT sidecar.

## Consequences

A complete invert matrix remains unfinished. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, I-006, MP4 burn-in, video/caption mute/solo, and syncLock remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table. No production algebra change.

## Evidence

`docs/implementation/evidence/field-invert-leave-gap-delete/`.
