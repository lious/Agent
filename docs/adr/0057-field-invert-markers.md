# ADR 0057 — Field-aware invert of a prior SetMarkers command

## Status

Accepted for Increment 1.50 as a bounded slice of the original I-005 remaining work on the field-aware invert matrix (s3 / s5a). I-005 and I-010 remain partial. This increment does not claim a complete invert matrix for every already-opened command. Official InversePatch `kind` stays `restoreSnapshot`. Linear undo/redo stay tip snapshot restores. This increment does not open auto-close as a MoveClips mode, source-interval crop, marker sidecar formats, video/caption mute/solo, syncLock, or I-006 roll/slip/slide.

## Context

Increment 1.47 opened field-aware invert of a prior non-tip command and officially demonstrated it for `SetCaptions`. The store already computes a clock-stripped write set from `before_ref` / `after_ref` and restores only still-matching fields. `SetMarkers` is an already-defined, already-opened command in that matrix, but it had not been qualified on a persist path with captions present.

## Decision

Officially admit invert of a prior committed `SetMarkers` that is not the undo tip. Only that command's content write set is restored when those fields still match the command's after-image. A later edit to any of those fields, a followed `clipLocal` marker whose time has already moved with its host, or invert of the tip / undo / redo / invertCommand itself, is whole-group `UNDO_CONFLICT` and does not roll the database back. An unrelated leave-gap `MoveClip` of a non-host remnant, and earlier captions, stay. Sequence version is already bumped when markers change. Captions and markers are not burned into preview or MP4; export stays a VTT sidecar.

## Consequences

A complete invert matrix remains unfinished. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, I-006, MP4 burn-in, video/caption mute/solo, and syncLock remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered SetTrackState locked, overwrite, LiftClips/Cut, MoveClip, Delete/Trim, insert-move leave-gap, includeLinks=false, caption default/follow/interval/source-window, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/field-invert-markers/`.
