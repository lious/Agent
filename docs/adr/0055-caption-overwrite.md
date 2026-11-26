# ADR 0055 — Caption-aware overwrite move and paste

## Status

Accepted for Increment 1.48 as a bounded slice of the original I-005 / I-010 remaining work on already-defined `MoveClips` / `PasteClips` `mode=overwrite` when captions are present. I-005 and I-010 remain partial. This increment does not open auto-close as a MoveClips mode, source-interval crop, marker sidecar formats, OS clipboard, new-track, or I-006 roll/slip/slide.

## Decision

Overwrite no longer leaves destination `clipLocal` cues on a carved or removed host for follow-up validation to fail or to reuse an unchanged cue version. After destination intervals are carved, uniquely covered `clipLocal` cues and markers rebind to a remnant (the same split-style rule already used after `SplitClip`); otherwise the whole cue or marker is kept at its authored times as an absolute remnant with the same text. Later content is not shifted. Incoming overwrite-move clips still carry their own following `clipLocal` cues; a dest remnant that would occupy the same times as a followed cue is whole-group `CAPTION_OVERLAP`. Overwrite paste may rebind a uniquely covered dest cue onto the pasted clip. A source-anchored cue whose window is uncovered or cropped remains whole-group `ANCHOR_OUT_OF_RANGE`. Lifting a `clipLocal`-marker host remains `REF_NOT_FOUND`. Captions still do not enter the internal clipboard payload.

Insert-move still leaves a source gap. Official InversePatch kind stays `restoreSnapshot`. `_bindCaptionToHost` now also reallocates a cue version when only the local range changes, so persist does not reuse an immutable definition version.

A real workbench path imports an AV file, extracts persistent audio, splits, adds left / carved-interval / remnant cues, sets Collision mode to overwrite, commits a multi-select move, then undoes, redoes, archives a fork, and exports a VTT sidecar. Preview and MP4 still refuse `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`.

## Consequences

Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, I-006, MP4 burn-in, and a complete invert matrix remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered insert-move leave-gap, explicit-range ripple close, `includeLinks=false`, leave-gap and ripple trim/delete, caption-aware `MoveClip` and `LiftClips`/Cut, field-aware invert, caption default/follow/interval/source-window, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/caption-overwrite/`.
