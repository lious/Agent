# ADR 0051 — Caption-aware leave-gap DeleteClip

## Status

Accepted for Increment 1.44 as a bounded slice of the original I-005 / I-010 remaining work on leave-gap delete when captions or markers are present. I-005 and I-010 remain partial. This increment does not open source-interval crop, field-aware inverse, or auto-close as a MoveClips mode.

## Decision

`DeleteClip(ripple: false)` is no longer a whole-group `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`. Later content is not shifted. A `clipLocal` cue bound to a removed host becomes an absolute remnant at the same times with the same text, rather than being dropped. Later cues keep their times. A `clipLocal` marker bound to a removed host becomes absolute at the same time. Uncovering a source window is whole-group `ANCHOR_OUT_OF_RANGE`. A locked caption track that would have to rewrite a bound cue is `FIELD_LOCKED`. On a persistent-audio timeline, linked members are removed together and the vacated hole is left on both tracks.

`DeleteClip(ripple: true)` is unchanged from Increment 1.43 and still uses the `RippleDeleteClips` interval crop/split/shift. `MoveClip` with captions still refuses `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`. Leave-gap trim still does not shift later content. Lifting a host that still has a `clipLocal` marker remains `REF_NOT_FOUND`.

A real workbench path imports an AV file, extracts a persistent audio clip from the selected video, splits at one second, adds a left-hand cue, uses the existing Delete (leave gap) control, then undoes, redoes, archives a fork, and exports a VTT sidecar. Preview and MP4 still refuse `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`. The same persist path is also exercised with `DeleteClip(ripple: false)` through the SDK.

## Consequences

Source-interval crop, field-aware inverse, marker sidecar formats, auto-close-on-move, new-track, cross-project bake, OS clipboard, I-006 roll/slip/slide, and MP4 burn-in remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered leave-gap trim, single-range ripple delete/close, shorten and lengthen `RippleTrimClip`, video-only and linked-audio `TrimClip(ripple: true)`, `DeleteClip(ripple: true)`, reject/overwrite/insert, `includeLinks=false`, insert-move leave-gap, caption default/follow/interval/source-window, split and leave-gap rebind/remnants, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/caption-leave-gap-delete/`.
