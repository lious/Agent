# ADR 0069 — Field-aware invert of a prior leave-gap MoveClip command

## Status

Accepted for Increment 1.62 as a bounded slice of the original I-005 remaining work on the field-aware invert matrix (s3 / s5a). I-005 and I-010 remain partial. This increment does not claim a complete invert matrix. Official InversePatch `kind` stays `restoreSnapshot`. Linear undo/redo stay tip snapshot restores. Already-delivered RippleDeleteClips, RippleTrimClip, leave-gap TrimClip, leave-gap DeleteClip, MoveClip / MoveClips, SplitClip, ExtractAudioClip, UnlinkAudioVideo / LinkAudioVideo, SetAudioTrackState, and SetTrackState locked/unlock semantics stay unchanged. The single-clip Move button stays `MoveClip` and does not silently take an unlinked audio partner or expand into a group move. Video and caption mute/solo stay refused at admission with `FEATURE_NOT_IMPLEMENTED`; audio muted/solo stay `SetAudioTrackState`; `syncLock` is not toggled. This increment does not open auto-close as a MoveClips mode, or open new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, or I-006. A diverging unlink invert remains `LINK_OFFSET_MISMATCH`. Invert's version indexer continues to skip source refs (`streamId` present). Leaf-level rational `n`/`d` granularity is unchanged. This slice does not change field-invert list insertion order or retarget `IMPLICIT_GAP`.

## Context

Increment 1.61 officially admitted invert of a prior non-tip leave-gap `DeleteClip` of a rightmost remnant. `MoveClip` was already the admitted caption-aware leave-gap single-clip move: the vacated source is left as a gap, `clipLocal` cues follow the host, and the workbench Move button issues `MoveClip` rather than `MoveClips`. It had not been qualified as an invert-matrix target on a persist path with captions present.

A later leave-gap out-trim of the remaining left remnant remints the gap filler written in the vacated source range and therefore conflicts with invert of the move. Official later work is a marker or a text edit, not a later left trim. This slice does not open auto-close of that vacated gap as a MoveClips mode.

## Decision

Officially admit invert of a prior committed leave-gap `MoveClip` of a right remnant that is not the undo tip. Only that command's move write set is restored when those fields still match the command's after-image. A later unrelated `SetMarkers`, a later text edit of the followed cue, or a later text edit of an uninvolved earlier cue, therefore does not conflict: invert restores the remnant's start and the followed cue's times, and keeps the later markers and revised text. A later second leave-gap move of the same remnant, a later leave-gap out-trim of the remaining left remnant that remints the vacated filler, or invert of the tip, is whole-group `UNDO_CONFLICT` and does not roll the database back. Official workbench path uses the single-clip Move button and a later marker; extract is not required. Captions and markers are not burned into preview or MP4; export stays a VTT sidecar.

## Consequences

A complete invert matrix remains unfinished. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, I-006, MP4 burn-in, video/caption mute/solo, and syncLock remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered ripple delete, ripple trim, leave-gap trim, leave-gap delete, move, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip / RippleTrimClip / rightmost RippleDeleteClips / leave-gap DeleteClip, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table. No production algebra change.

## Evidence

`docs/implementation/evidence/field-invert-move-clip/`.
