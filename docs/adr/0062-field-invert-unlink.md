# ADR 0062 — Field-aware invert of a prior UnlinkAudioVideo / LinkAudioVideo command

## Status

Accepted for Increment 1.55 as a bounded slice of the original I-005 remaining work on the field-aware invert matrix (s3 / s5a). I-005 and I-010 remain partial. This increment does not claim a complete invert matrix. Official InversePatch `kind` stays `restoreSnapshot`. Linear undo/redo stay tip snapshot restores. Already-delivered UnlinkAudioVideo / LinkAudioVideo, SetAudioTrackState, and SetTrackState locked/unlock semantics stay unchanged. Video and caption mute/solo stay refused at admission with `FEATURE_NOT_IMPLEMENTED`; audio muted/solo stay `SetAudioTrackState`; `syncLock` is not toggled. This increment does not open auto-close as a MoveClips mode, expand the single-clip `MoveClip` button, or open new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, or I-006.

## Context

Increment 1.47 opened field-aware invert of a prior non-tip command and demonstrated it for `SetCaptions`. Later official invert-matrix rows covered `SetMarkers`, `GroupClips` / `UngroupClips`, `SetTrackState`, and `SetAudioTrackState`. `UnlinkAudioVideo` and `LinkAudioVideo` were already admitted AV-link commands and already coexisted with captions, but they had not been qualified as invert-matrix targets on a persist path with captions present.

## Decision

Officially admit invert of a prior committed `UnlinkAudioVideo` or `LinkAudioVideo` that is not the undo tip. Only that command's link write set (`linkGroups` and `linkGroupId`) is restored when those fields still match the command's after-image. A later leave-gap move that translates both unlinked members by the same amount, so the recorded offset still holds, therefore does not conflict: invert of an unlink restores the link and keeps the moved remnants and already-followed cues. Invert of a later relink after a linked move restores only the unlink and leaves the later geometry. A later relink of the same pair, or invert of the tip, is whole-group `UNDO_CONFLICT` and does not roll the database back. Invert of an unlink after a move that diverges the members so the recorded offset no longer holds is refused by existing document validation as `LINK_OFFSET_MISMATCH` and does not roll the database back; this increment does not retarget that refusal to `UNDO_CONFLICT`. Captions and markers are not burned into preview or MP4; export stays a VTT sidecar.

## Consequences

A complete invert matrix remains unfinished. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, I-006, MP4 burn-in, video/caption mute/solo, and syncLock remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered unlink/link, SetAudioTrackState, SetTrackState locked, caption-aware grouping, invert of SetCaptions / SetMarkers / GroupClips / SetTrackState / SetAudioTrackState, overwrite, LiftClips/Cut, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/field-invert-unlink/`.
