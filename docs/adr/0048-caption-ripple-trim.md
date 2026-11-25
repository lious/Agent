# ADR 0048 — Caption-aware ripple TrimClip

## Status

Accepted for Increment 1.41 as a bounded slice of the original I-005 / I-010 remaining work on caption-aware ripple trim. I-005 and I-010 remain partial. This increment does not open linked-audio ripple trim, source-interval crop, or auto-close as a MoveClips mode.

## Decision

On the generic (no audio-track) path, `TrimClip(ripple: true)` is no longer a whole-group `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED` when captions or markers exist. Media mutation stays on the existing generic ripple-trim path (later content closes or opens after the old out point; an in trim still pins timeline start). After that mutation, the same interval crop/split/shift already used by `RippleTrimClip` is applied: `applySourceCaptionAbsolutes`, `applyCaptionIntervalEdit`, `applyClipLocalMarkerLocals`, and `applyMarkerIntervalEdit`. Sequence duration is then recomputed from media item ends and post-edit caption ends so a remnant past the closed media tail cannot leave a stale duration.

A spanning cue keeps its authored text; the portion still before the closed interval stays, the portion inside is cropped, and the portion after is shifted. A uniquely covered `clipLocal` cue that still sits on the trimmed host follows that host. Uncovering a source window is whole-group `ANCHOR_OUT_OF_RANGE`. A locked caption track is `FIELD_LOCKED`. Out-trim geometry matches `RippleTrimClip` on a video-only document (remnant ids may differ).

`TrimClip(ripple: false)` is unchanged: later content is not shifted, and a vacated gap keeps an absolute remnant. On a document with a persistent audio track, `TrimClip(ripple: true)` still refuses `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED` rather than being rewritten as `LINKED_RIPPLE_NOT_IMPLEMENTED`. Lifting a host that still has a `clipLocal` marker remains `REF_NOT_FOUND`.

A real workbench path imports a video-only clip (no persistent audio extract, so Trim is ripple), adds a spanning cue, trims 15 frames off the out edge, then undoes, redoes, archives a fork, and exports a VTT sidecar. Preview and MP4 still refuse `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`.

## Consequences

Linked AV ripple trim, source-interval crop, field-aware inverse, marker sidecar formats, auto-close-on-move, new-track, cross-project bake, OS clipboard, I-006 roll/slip/slide, and MP4 burn-in remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered leave-gap delete/trim, single-range ripple delete/close, shorten and lengthen `RippleTrimClip`, reject/overwrite/insert, `includeLinks=false`, insert-move leave-gap, caption default/follow/interval/source-window, split and leave-gap caption rebind/remnants, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/caption-ripple-trim/`.
