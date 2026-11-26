# ADR 0052 — Caption-aware MoveClip

## Status

Accepted for Increment 1.45 as a bounded slice of the original I-005 / I-010 remaining work on single-clip MoveClip when captions or markers are present. I-005 and I-010 remain partial. This increment does not open source-interval crop, field-aware inverse, marker sidecar formats, or auto-close as a MoveClips mode.

## Decision

`MoveClip` is no longer a whole-group `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`. After the clip (and, on a persistent-audio timeline, its link-group members) translates, captions and markers use the same follow hooks already opened for `MoveClips`: `clipLocal` cues and markers translate with their host, absolute cues and default absolute markers stay at authored times, and source-anchored cues reproject from the host linear time map when the source window still covers them. The vacated source is left as a gap; this is not a new auto-close mode. A colliding destination is whole-group `COLLISION`. Uncovering a source window is still whole-group `ANCHOR_OUT_OF_RANGE`. Lifting a host that still has a `clipLocal` marker remains `REF_NOT_FOUND`.

`MoveClips` (including insert-move leave-gap and `includeLinks=false`) is unchanged. Leave-gap and ripple `DeleteClip` / `TrimClip` stay as already delivered. I-006 roll/slip/slide stay closed.

A real workbench path imports an AV file, extracts a persistent audio clip from the selected video, adds a default clipLocal cue, uses the new Move control for 15 frames, then undoes, redoes, archives a fork, and exports a VTT sidecar. Preview and MP4 still refuse `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`. The same persist path is also exercised with `MoveClip` through the SDK.

## Consequences

Source-interval crop, field-aware inverse, marker sidecar formats, auto-close-on-move, new-track, cross-project bake, OS clipboard, I-006 roll/slip/slide, and MP4 burn-in remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered leave-gap trim/delete, single-range ripple delete/close, shorten and lengthen `RippleTrimClip`, video-only and linked-audio `TrimClip(ripple: true)`, `DeleteClip(ripple: true)` and leave-gap `DeleteClip`, reject/overwrite/insert, `includeLinks=false`, insert-move leave-gap, caption default/follow/interval/source-window, split and leave-gap rebind/remnants, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/caption-move-clip/`.
