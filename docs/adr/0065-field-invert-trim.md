# ADR 0065 — Field-aware invert of a prior leave-gap TrimClip command

## Status

Accepted for Increment 1.58 as a bounded slice of the original I-005 remaining work on the field-aware invert matrix (s3 / s5a). I-005 and I-010 remain partial. This increment does not claim a complete invert matrix. Official InversePatch `kind` stays `restoreSnapshot`. Linear undo/redo stay tip snapshot restores. Already-delivered TrimClip (leave-gap and ripple), SplitClip, ExtractAudioClip, UnlinkAudioVideo / LinkAudioVideo, SetAudioTrackState, and SetTrackState locked/unlock semantics stay unchanged. Video and caption mute/solo stay refused at admission with `FEATURE_NOT_IMPLEMENTED`; audio muted/solo stay `SetAudioTrackState`; `syncLock` is not toggled. This increment does not open auto-close as a MoveClips mode, expand the single-clip `MoveClip` button, or open new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, or I-006. A diverging unlink invert remains `LINK_OFFSET_MISMATCH`. Invert's version indexer continues to skip source refs (`streamId` present). Leaf-level rational `n`/`d` granularity is unchanged.

## Context

Increment 1.47 opened field-aware invert of a prior non-tip command and later official invert-matrix rows covered `SetCaptions`, `SetMarkers`, `GroupClips` / `UngroupClips`, `SetTrackState`, `SetAudioTrackState`, `UnlinkAudioVideo` / `LinkAudioVideo`, `ExtractAudioClip`, and `SplitClip`. Leave-gap `TrimClip` was already the admitted caption-aware out-trim, but it had not been qualified as an invert-matrix target on a persist path with captions present. The workbench Trim button is leave-gap only when persistent audio is present; otherwise it issues a ripple `TrimClip`.

Leave-gap out-trim writes a gap filler on the track. A later leave-gap move of an adjacent remnant, or a later same-track leave-gap move that remints that filler after a linked extract, mutates the trim write set and is `UNDO_CONFLICT`. A later marker edit does not.

## Decision

Officially admit invert of a prior committed leave-gap `TrimClip` (`ripple: false`) that is not the undo tip. Only that command's trim write set (the shortened remnant's recorded range leaves and the added gap filler) is restored when those fields still match the command's after-image. A later unrelated `SetMarkers` therefore does not conflict: invert restores the pre-trim duration, removes the filler, and keeps the later markers and unmoved cues. On a video-only timeline, a later leave-gap move of a non-adjacent remnant also does not conflict and keeps already-followed cues. A later out-trim that changes a recorded duration numerator, a later leave-gap move of an adjacent remnant, or invert of the tip, is whole-group `UNDO_CONFLICT` and does not roll the database back. Official workbench path extracts persistent audio first so the Trim button is leave-gap, then uses a later marker rather than a same-track move. Captions and markers are not burned into preview or MP4; export stays a VTT sidecar.

## Consequences

A complete invert matrix remains unfinished. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, I-006, MP4 burn-in, video/caption mute/solo, and syncLock remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered trim, split, extract, unlink/link, SetAudioTrackState, SetTrackState locked, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState / UnlinkAudioVideo / ExtractAudioClip / SplitClip, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/field-invert-trim/`.
