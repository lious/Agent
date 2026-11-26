# ADR 0064 — Field-aware invert of a prior SplitClip command

## Status

Accepted for Increment 1.57 as a bounded slice of the original I-005 remaining work on the field-aware invert matrix (s3 / s5a). I-005 and I-010 remain partial. This increment does not claim a complete invert matrix. Official InversePatch `kind` stays `restoreSnapshot`. Linear undo/redo stay tip snapshot restores. Already-delivered SplitClip, ExtractAudioClip, UnlinkAudioVideo / LinkAudioVideo, SetAudioTrackState, and SetTrackState locked/unlock semantics stay unchanged. Video and caption mute/solo stay refused at admission with `FEATURE_NOT_IMPLEMENTED`; audio muted/solo stay `SetAudioTrackState`; `syncLock` is not toggled. This increment does not open auto-close as a MoveClips mode, expand the single-clip `MoveClip` button, or open new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, or I-006. A diverging unlink invert remains `LINK_OFFSET_MISMATCH`. Invert's version indexer continues to skip source refs (`streamId` present).

## Context

Increment 1.47 opened field-aware invert of a prior non-tip command and later official invert-matrix rows covered `SetCaptions`, `SetMarkers`, `GroupClips` / `UngroupClips`, `SetTrackState`, `SetAudioTrackState`, `UnlinkAudioVideo` / `LinkAudioVideo`, and `ExtractAudioClip`. `SplitClip` was already the admitted caption-aware blade command, but it had not been qualified as an invert-matrix target on a persist path with captions present.

## Decision

Officially admit invert of a prior committed `SplitClip` that is not the undo tip. Only that command's split write set (the shortened left remnant's recorded range leaves and the added right/mid clip) is restored when those fields still match the command's after-image. A later leave-gap move of an uninvolved remnant therefore does not conflict: invert restores the split host and removes the new remnant, and keeps the moved remnants and already-followed cues. A later leave-gap move of a split product, a later out-trim of the left remnant that changes a recorded duration numerator, or invert of the tip, is whole-group `UNDO_CONFLICT` and does not roll the database back. Leaf-level rational `n`/`d` granularity is unchanged: a later trim that only changes an unrecorded component is not retargeted to `UNDO_CONFLICT`. Captions and markers are not burned into preview or MP4; export stays a VTT sidecar.

## Consequences

A complete invert matrix remains unfinished. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, I-006, MP4 burn-in, video/caption mute/solo, and syncLock remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, caption-aware grouping, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/field-invert-split/`.
