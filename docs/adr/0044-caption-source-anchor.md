# ADR 0044 — Admit explicit source caption anchors with linear reprojection

## Status

Accepted for Increment 1.37 on the already-schemaed `Anchor.kind=source` and I-010 / s3 caption language. I-005 and I-010 remain partial.

## Decision

A cue may be explicitly bound with `CaptionCue.anchoredToSource`. `anchor.range` is the offset from the host clip's `sourceRange.start` under a linear time map; `timelineRange` is the projection `hostTimelineStart + local / rate`. New and imported uniquely covered cues still default to clipLocal, never source. Existing or made-absolute cues stay absolute until the user anchors them.

On already-opened MoveClips, overwrite, paste, insert-move, ripple delete/close and ripple trim, source cues are snapshotted as absolute media source times before the rewrite. After the rewrite they reproject when a unique same-stream host still fully covers that source window (including a split remnant). An interval or rewrite that would uncover or crop a source cue refuses the whole command (`ANCHOR_OUT_OF_RANGE`) and leaves the document unchanged; this slice does not silently crop, split, or drop source-anchored text. Non-linear or non-positive rates refuse `TIME_MAP_MISMATCH`. Styles, words, speakers, and MP4 / preview text burn-in stay refused.

Insert-move still leaves a source gap. includeLinks=false, default clipLocal, explicit absolute, clipLocal follow, absolute/clipLocal interval crop/split/shift, and the Increment 1.36 marker semantics are unchanged. Lifting a clipLocal *marker* host is still an atomic `REF_NOT_FOUND`. No new persistence table.

## Consequences

The workbench can convert a selected cue to a source anchor of its unique covering clip, follow that picture on MoveClips, undo/redo, archive fork, and export a sidecar. Source crop/split across an uncovering interval, rich caption styles, field-aware InversePatch, 1000 random NLE undo, auto-close-on-move, new-track, cross-project bake, OS clipboard, marker sidecars, and I-006 remain closed.

## Evidence

`docs/implementation/evidence/caption-source-anchor/`.
