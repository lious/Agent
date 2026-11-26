# ADR 0049 — Caption-aware linked-audio ripple TrimClip

## Status

Accepted for Increment 1.42 as a bounded slice of the original I-005 / I-010 remaining work on ripple trim when a persistent audio track exists. I-005 and I-010 remain partial. This increment does not open linked ripple delete, source-interval crop, or auto-close as a MoveClips mode.

## Decision

`TrimClip(ripple: true)` on a document that already has an audio track is no longer a whole-group `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`, and it is not rewritten as `LINKED_RIPPLE_NOT_IMPLEMENTED`. The persistent-audio path delegates that command to the existing `RippleTrimClip` implementation: link-group members shorten or lengthen together, later content on participating tracks closes or opens after the old out point, and captions and markers use the same interval crop/split/shift already opened for video-only ripple trim and for `RippleTrimClip`. An in trim still pins timeline start. Uncovering a source window is whole-group `ANCHOR_OUT_OF_RANGE`. A locked partner is `FIELD_LOCKED`. Out-trim caption geometry matches `RippleTrimClip` (remnant ids may differ).

`TrimClip(ripple: false)` is unchanged: later content is not shifted, and a vacated gap keeps an absolute remnant. `MoveClip` with captions still refuses `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`. `DeleteClip(ripple: true)` on a linked pair still refuses `LINKED_RIPPLE_NOT_IMPLEMENTED` without captions and `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED` when captions exist. Lifting a host that still has a `clipLocal` marker remains `REF_NOT_FOUND`.

A real workbench path imports an AV file, extracts a persistent audio clip from the selected video, adds a spanning cue, uses the existing Ripple trim out control, then undoes, redoes, archives a fork, and exports a VTT sidecar. Preview and MP4 still refuse `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`. The same persist path is also exercised with `TrimClip(ripple: true)` through the SDK.

## Consequences

Linked ripple delete, source-interval crop, field-aware inverse, marker sidecar formats, auto-close-on-move, new-track, cross-project bake, OS clipboard, I-006 roll/slip/slide, and MP4 burn-in remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered leave-gap delete/trim, single-range ripple delete/close, shorten and lengthen `RippleTrimClip`, video-only `TrimClip(ripple: true)`, reject/overwrite/insert, `includeLinks=false`, insert-move leave-gap, caption default/follow/interval/source-window, split and leave-gap rebind/remnants, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/caption-linked-ripple-trim/`.
