# ADR 0066 — Field-aware invert of a prior RippleTrimClip command

## Status

Accepted for Increment 1.59 as a bounded slice of the original I-005 remaining work on the field-aware invert matrix (s3 / s5a). I-005 and I-010 remain partial. This increment does not claim a complete invert matrix. Official InversePatch `kind` stays `restoreSnapshot`. Linear undo/redo stay tip snapshot restores. Already-delivered RippleTrimClip, leave-gap TrimClip, SplitClip, ExtractAudioClip, UnlinkAudioVideo / LinkAudioVideo, SetAudioTrackState, and SetTrackState locked/unlock semantics stay unchanged. Video and caption mute/solo stay refused at admission with `FEATURE_NOT_IMPLEMENTED`; audio muted/solo stay `SetAudioTrackState`; `syncLock` is not toggled. This increment does not open auto-close as a MoveClips mode, expand the single-clip `MoveClip` button, or open new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, or I-006. A diverging unlink invert remains `LINK_OFFSET_MISMATCH`. Invert's version indexer continues to skip source refs (`streamId` present). Leaf-level rational `n`/`d` granularity is unchanged.

## Context

Increment 1.58 officially admitted invert of a prior non-tip leave-gap `TrimClip`. `RippleTrimClip` was already the admitted caption-aware ripple out-trim, with a dedicated workbench button that does not depend on extracting persistent audio, but it had not been qualified as an invert-matrix target on a persist path with captions present. Ripple out-trim of a non-last remnant also shifts later items and followed cues; those starts are part of the write set, so a later leave-gap move of a shifted remnant is `UNDO_CONFLICT`.

## Decision

Officially admit invert of a prior committed `RippleTrimClip` that is not the undo tip. Only that command's ripple-trim write set is restored when those fields still match the command's after-image. A later unrelated `SetMarkers` therefore does not conflict: invert of a rightmost ripple out-trim restores the pre-trim duration, and invert of a left ripple out-trim also restores later starts and already-shifted cues, while later markers stay. A later out-trim that changes a recorded duration numerator, a later leave-gap move of a remnant whose start was shifted by the ripple, or invert of the tip, is whole-group `UNDO_CONFLICT` and does not roll the database back. Official workbench path uses the dedicated Ripple trim out button and a later marker. Captions and markers are not burned into preview or MP4; export stays a VTT sidecar.

## Consequences

A complete invert matrix remains unfinished. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, I-006, MP4 burn-in, video/caption mute/solo, and syncLock remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered ripple trim, leave-gap trim, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip / leave-gap TrimClip, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/field-invert-ripple-trim/`.
