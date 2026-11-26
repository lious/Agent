# ADR 0061 — Field-aware invert of a prior SetAudioTrackState command

## Status

Accepted for Increment 1.54 as a bounded slice of the original I-005 remaining work on the field-aware invert matrix (s3 / s5a). I-005 and I-010 remain partial. This increment does not claim a complete invert matrix. Official InversePatch `kind` stays `restoreSnapshot`. Linear undo/redo stay tip snapshot restores. Already-delivered SetAudioTrackState mute/solo semantics stay unchanged: audio muted/solo stay `SetAudioTrackState`; video and caption mute/solo stay refused at admission with `FEATURE_NOT_IMPLEMENTED`; `syncLock` is not toggled. Already-delivered SetTrackState locked/unlock semantics stay unchanged. This increment does not open auto-close as a MoveClips mode, expand the single-clip `MoveClip` button, or open new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, or I-006.

## Context

Increment 1.47 opened field-aware invert of a prior non-tip command and demonstrated it for `SetCaptions`. Increment 1.50 added an official `SetMarkers` row. Increment 1.52 added official invert of a prior `GroupClips` / `UngroupClips`. Increment 1.53 added official invert of a prior `SetTrackState`. `SetAudioTrackState` was already the admitted command for persistent-audio mute and solo, but it had not been qualified as an invert-matrix target on a persist path with captions present.

## Decision

Officially admit invert of a prior committed `SetAudioTrackState` that is not the undo tip. Only that command's audio-state write set (`muted` and `solo` on the addressed audio track, plus the resulting sequence definition change) is restored when those fields still match the command's after-image. A later leave-gap move that only changes clip geometry therefore does not conflict: invert of a mute unmutes the track and keeps the moved remnants and already-followed cues. Invert of a later unmute after a leave-gap move restores only the mute. A later mute change of the same track, or invert of the tip, is whole-group `UNDO_CONFLICT` and does not roll the database back. Captions and markers are not burned into preview or MP4; export stays a VTT sidecar.

## Consequences

A complete invert matrix remains unfinished. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, I-006, MP4 burn-in, video/caption mute/solo, and syncLock remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered SetAudioTrackState, SetTrackState locked, caption-aware grouping, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/field-invert-audio-mute/`.
