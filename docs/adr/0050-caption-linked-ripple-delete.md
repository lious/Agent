# ADR 0050 — Caption-aware ripple DeleteClip (video-only and linked audio)

## Status

Accepted for Increment 1.43 as a bounded slice of the original I-005 / I-010 remaining work on ripple delete. I-005 and I-010 remain partial. This increment does not open leave-gap `DeleteClip`, source-interval crop, or auto-close as a MoveClips mode.

## Decision

`DeleteClip(ripple: true)` is no longer a whole-group `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`, and on a persistent-audio timeline it is not rewritten as `LINKED_RIPPLE_NOT_IMPLEMENTED`. The persistent-audio path delegates that command to the existing `RippleDeleteClips` implementation: link-group members are removed together, later content on participating tracks closes the vacated interval, and captions and markers use the same interval crop/split/shift already opened for `RippleDeleteClips`. On a video-only timeline, the generic path applies those same interval hooks after the existing single-clip ripple delete. Caption geometry matches `RippleDeleteClips` (remnant ids may differ). Uncovering a source window is whole-group `ANCHOR_OUT_OF_RANGE`. A locked partner is `FIELD_LOCKED`.

`DeleteClip(ripple: false)` (leave-gap delete) is unchanged and still refuses `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED` when captions exist. `MoveClip` with captions still refuses `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`. Leave-gap trim still does not shift later content. Lifting a host that still has a `clipLocal` marker remains `REF_NOT_FOUND`.

A real workbench path imports an AV file, extracts a persistent audio clip from the selected video, splits at one second, adds a spanning cue, uses the existing Ripple delete range control, then undoes, redoes, archives a fork, and exports a VTT sidecar. Preview and MP4 still refuse `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`. The same persist path is also exercised with `DeleteClip(ripple: true)` through the SDK.

## Consequences

Leave-gap `DeleteClip` with captions, source-interval crop, field-aware inverse, marker sidecar formats, auto-close-on-move, new-track, cross-project bake, OS clipboard, I-006 roll/slip/slide, and MP4 burn-in remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered leave-gap trim, single-range ripple delete/close, shorten and lengthen `RippleTrimClip`, video-only and linked-audio `TrimClip(ripple: true)`, reject/overwrite/insert, `includeLinks=false`, insert-move leave-gap, caption default/follow/interval/source-window, split and leave-gap rebind/remnants, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/caption-linked-ripple-delete/`.
