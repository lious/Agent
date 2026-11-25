# ADR 0047 — Caption-aware SplitClip and leave-gap TrimClip

## Status

Accepted for Increment 1.40 as a bounded slice of the original I-005 / I-010 remaining work on caption-aware split and ordinary leave-gap trim. I-005 and I-010 remain partial. This increment does not open caption-aware ripple TrimClip, does not auto-split cue text, and does not close the full section-3 matrix.

## Decision

When captions or markers exist, `SplitClip` and ordinary `TrimClip(ripple: false)` are no longer a whole-group `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`. Media mutation stays on the existing generic and linked-audio paths; caption and marker policy is applied after that mutation, in the same atomic command.

Split keeps authored cue text and timeline range. A `clipLocal` cue uniquely covered by one remnant is rebound to that remnant; a cue that now spans the cut becomes absolute at the same times. Source cues are restored through the existing source-window snapshot; a cue wholly covered by one remnant rebinds, and a spanning or uncovering source cue refuses the whole group with `ANCHOR_OUT_OF_RANGE`. A `clipLocal` marker rebinds if uniquely covered and becomes absolute if it spans the cut. Split is not a lift: lifting a host that still has a `clipLocal` marker remains `REF_NOT_FOUND`.

Leave-gap trim (`ripple: false` only) does not shift later content. The vacated head or tail is a gap. The portion of a `clipLocal` cue that still sits on the host keeps its sequence times and stays `clipLocal` (locals are resynchronized to the new host start). The portion that now falls in the vacated gap becomes an absolute remnant with a new id and the same text; it is not cropped to empty the way a ripple close would. Absolute cues stay put. Uncovering a source window is whole-group `ANCHOR_OUT_OF_RANGE`. Linked AV split and leave-gap trim still edit every member together; caption and marker helpers run for each member id. `MoveClip`, `SlipClip`, `DeleteClip`, and `TrimClip(ripple: true)` with captions still refuse `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED` (including on the audio path, so they are not silently rewritten as `LINKED_RIPPLE_NOT_IMPLEMENTED`). A locked caption track is `FIELD_LOCKED`. The whole group is refused when any member cannot be applied; captions and markers are not dropped silently.

A real workbench path imports an AV file, extracts a persistent audio clip from the selected video, adds a default `clipLocal` cue, splits at 30 frames, leave-gap trims 15 frames off the left out edge, then undoes, redoes, archives a fork, and exports a VTT sidecar. Preview and MP4 still refuse `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`.

## Consequences

`TrimClip(ripple: true)` / `RippleTrimClip` with captions stay refused. Cue text is never auto-split. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered leave-gap delete/trim, single-range ripple delete/close, shorten and lengthen ripple trim, reject/overwrite/insert, `includeLinks=false`, insert-move leave-gap, caption default `clipLocal` / follow / interval crop / source-window anchors, marker absolute default / `clipLocal` follow / ripple interval, 1000 seeded random undo of already-opened commands, and the Increment 1.39 opened section-3 geometry matrix stay unchanged. Auto-close is not a `MoveClips` mode. No new tracks, cross-project bake, OS clipboard, I-006 roll/slip/slide, field-aware inverse, marker sidecar formats, source-interval crop, MP4 burn-in, or new persistence table.

## Evidence

`docs/implementation/evidence/caption-split-trim/`.
