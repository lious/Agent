# ADR 0053 — Caption-aware LiftClips (leave-gap cut)

## Status

Accepted for Increment 1.46 as a bounded slice of the original I-005 / I-010 remaining work on `LiftClips` (Cut) when captions are present. I-005 and I-010 remain partial. This increment does not open source-interval crop, field-aware inverse, marker sidecar formats, or auto-close as a MoveClips mode. Captions still do not enter the internal clipboard payload.

## Decision

`LiftClips` with captions is no longer a dangling-host `REF_NOT_FOUND`. After the admitted link-and-selection closure is removed and legal gaps are left (duration kept), captions use the same leave-gap remnant hook already opened for `DeleteClip(ripple: false)`: a `clipLocal` cue whose host is lifted becomes an absolute remnant at its original times with the same text; later cues are not shifted; absolute cues stay at authored times. Linked audio and video members are still lifted together. The vacated source stays a gap; this is not auto-close-on-move.

A source-anchored cue whose host is lifted is whole-group `ANCHOR_OUT_OF_RANGE`, matching leave-gap `DeleteClip` uncover rather than leaving a dangling host. Lifting a host that still has a `clipLocal` marker remains an explicit whole-group `REF_NOT_FOUND` (not rewritten as `ANCHOR_OUT_OF_RANGE`, and not converted to an absolute remnant the way leave-gap `DeleteClip` already does). Captions are not added to the internal clipboard package in this slice, so a later paste does not copy or move them.

`MoveClip` / `MoveClips` (including insert-move leave-gap and `includeLinks=false`), leave-gap and ripple `DeleteClip` / `TrimClip`, and `SplitClip` stay as already delivered. I-006 roll/slip/slide stay closed.

A real workbench path imports an AV file, extracts a persistent audio clip from the selected video, splits, adds a default clipLocal cue, uses Cut selection (`LiftClips`), then undoes, redoes, archives a fork, and exports a VTT sidecar. Preview and MP4 still refuse `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`. The same persist path is also exercised with `cutSelection` through the SDK.

## Consequences

Source-interval crop, field-aware inverse, marker sidecar formats, auto-close-on-move, new-track, cross-project bake, OS clipboard, I-006 roll/slip/slide, and MP4 burn-in remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered leave-gap trim/delete, single-range ripple delete/close, shorten and lengthen `RippleTrimClip`, video-only and linked-audio `TrimClip(ripple: true)`, `DeleteClip(ripple: true)` and leave-gap `DeleteClip`, reject/overwrite/insert, `includeLinks=false`, insert-move leave-gap, caption-aware `MoveClip`, caption default/follow/interval/source-window, split and leave-gap rebind/remnants, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/caption-lift-clips/`.
