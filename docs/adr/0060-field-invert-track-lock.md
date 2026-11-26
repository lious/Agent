# ADR 0060 — Field-aware invert of a prior SetTrackState command

## Status

Accepted for Increment 1.53 as a bounded slice of the original I-005 remaining work on the field-aware invert matrix (s3 / s5a). I-005 and I-010 remain partial. This increment does not claim a complete invert matrix. Official InversePatch `kind` stays `restoreSnapshot`. Linear undo/redo stay tip snapshot restores. Already-delivered SetTrackState locked/unlock semantics stay unchanged: the track's own lock does not block this meta-op; video and caption mute/solo stay refused at admission with `FEATURE_NOT_IMPLEMENTED`; audio muted/solo stay `SetAudioTrackState`; `syncLock` is not toggled. This increment does not open auto-close as a MoveClips mode, expand the single-clip `MoveClip` button, or open new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, or I-006.

## Context

Increment 1.47 opened field-aware invert of a prior non-tip command and demonstrated it for `SetCaptions`. Increment 1.50 added an official `SetMarkers` row. Increment 1.52 added official invert of a prior `GroupClips` / `UngroupClips`. Increment 1.49 opened `SetTrackState` lock and unlock of an existing video, audio, or caption track, but that command had not been qualified as an invert-matrix target on a persist path with captions present.

## Decision

Officially admit invert of a prior committed `SetTrackState` that is not the undo tip. Only that command's lock write set (`locked` on the addressed track, plus the resulting sequence definition change) is restored when those fields still match the command's after-image. A later leave-gap move that only changes clip geometry therefore does not conflict: invert of a caption-track lock unlocks the track and keeps the moved remnants and already-followed cues. Invert of a later unlock after a leave-gap move restores only the lock. A later lock change of the same track, or invert of the tip, is whole-group `UNDO_CONFLICT` and does not roll the database back. Captions and markers are not burned into preview or MP4; export stays a VTT sidecar.

## Consequences

A complete invert matrix remains unfinished. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, I-006, MP4 burn-in, video/caption mute/solo, and syncLock remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered SetTrackState locked, caption-aware grouping, invert of SetCaptions / SetMarkers / GroupClips, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/field-invert-track-lock/`.
