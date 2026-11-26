# ADR 0059 — Field-aware invert of a prior GroupClips / UngroupClips command

## Status

Accepted for Increment 1.52 as a bounded slice of the original I-005 remaining work on the field-aware invert matrix (s3 / s5a). I-005 and I-010 remain partial. This increment does not claim a complete invert matrix. Official InversePatch `kind` stays `restoreSnapshot`. Linear undo/redo stay tip snapshot restores. Already-delivered GroupClips/UngroupClips and MoveClips group-expansion semantics stay unchanged. This increment does not open auto-close as a MoveClips mode, expand the single-clip `MoveClip` button, or open new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, video/caption mute/solo, syncLock, or I-006.

## Context

Increment 1.47 opened field-aware invert of a prior non-tip command and demonstrated it for `SetCaptions`. Increment 1.50 added an official `SetMarkers` row. Increment 1.51 officially opened caption-aware `GroupClips` / `UngroupClips`. Those grouping commands had not been qualified as invert-matrix targets on a persist path with captions present.

## Decision

Officially admit invert of a prior committed `GroupClips` or `UngroupClips` that is not the undo tip. Only that command's grouping write set (`selectionGroups` and `selectionGroupId`) is restored when those fields still match the command's after-image. A later group move that only changes clip geometry therefore does not conflict: invert dissolves the group and keeps the moved remnants and already-followed cues. A later `UngroupClips` of the same group, or invert of the tip, is whole-group `UNDO_CONFLICT` and does not roll the database back. Invert of a prior `UngroupClips` after a later single-member move restores only the group membership and leaves the later geometry and cues. Captions and markers are not burned into preview or MP4; export stays a VTT sidecar.

## Consequences

A complete invert matrix remains unfinished. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, I-006, MP4 burn-in, video/caption mute/solo, and syncLock remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered caption-aware grouping, SetTrackState locked, overwrite, LiftClips/Cut, field-aware invert of SetCaptions and SetMarkers, caption default/follow/interval/source-window, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/field-invert-group/`.
