# ADR 0058 — Caption-aware GroupClips / UngroupClips

## Status

Accepted for Increment 1.51 as a bounded slice of the original I-005 remaining clipboard/group work (`编组`). I-005 and I-010 remain partial. This increment does not make auto-close a MoveClips mode, does not expand the single-clip `MoveClip` button into a group move, and does not open new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, video/caption mute/solo, syncLock, or I-006 roll/slip/slide.

## Context

s3 already specifies Group/Ungroup as selection-only metadata: grouping does not rewrite timeline geometry, and default same-track `MoveClips` expands the selection-group closure (`includeLinks=true`). `GroupClips` already refused too-small selections and already coexisted with captions at the algebra layer, but that path had not been officially qualified with a persist workbench, captions, markers, undo/redo, archive/fork, and VTT sidecar.

## Decision

Officially admit `GroupClips` / `UngroupClips` when captions or markers are present. Grouping itself does not retarget, drop, or burn captions or markers. A later `MoveClips` of one member, with default link/group closure, translates every grouped member together, leaves the vacated source as a gap, follows `clipLocal` cues and markers, leaves absolute cues/markers at authored times, and reprojects still-covered source cues. `includeLinks=false` still moves only the explicit IDs. After `UngroupClips`, a later move of one member leaves the other member and its cue in place. An ungrouped move that would overlap a neighbor remains whole-group `COLLISION`. Lifting a `clipLocal`-marker host remains `REF_NOT_FOUND`. An uncovering or cropping interval remains `ANCHOR_OUT_OF_RANGE`. Preview and MP4 still refuse caption burn-in; export stays a VTT sidecar.

The workbench path uses the existing Group selection control and the multi-select `MoveClips` gesture. The single-clip Move button stays `MoveClip` and is not silently expanded.

## Consequences

Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, a complete invert matrix, I-006, MP4 burn-in, video/caption mute/solo, and syncLock remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered insert-move leave-gap, SetTrackState locked, field-aware invert (including SetMarkers), overwrite, LiftClips/Cut, caption default/follow/interval/source-window, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/caption-group-clips/`.
