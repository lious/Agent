# ADR 0043 — Admit sequence markers with clipLocal follow, ripple interval, and snap

## Status

Accepted for Increment 1.36 on the existing I-005 timeline commands and the already-defined Marker schema. I-005 remains partial. I-010 remainingAcceptance is unchanged.

## Decision

s3 says markers are sequence-absolute or clipLocal; `ripple=false` absolute markers do not move, `ripple=true` uses the same interval transform, and markers inside a closed range R enter the inverse patch on extract. Local writable admission now accepts a non-empty `markers` table and `sequence.markerIds` when they stay in sync. `SetMarkers` is one persistent command. New markers default to absolute with ripple=false. clipLocal is explicit (covering host required on write). `time` is always a sequence position; clipLocal locals are captured before a host moves and rewritten after.

Ripple delete/close, ripple trim, and insert paste/move apply `applyMarkerIntervalEdit` after media rewrite (insert-move defers until after placement so an unsplit host is not split at the destination hole). A wholly inside closed range is a crop-to-empty, restored on undo, not a silent drop. planMoveSnap includes marker times as `SnapKind.marker` targets. Labels are not burned into preview or export media. No new table is added.

## Consequences

The workbench Markers panel can add an absolute marker or add/anchor one on a covering clip, follow that host on MoveClips, undo/redo, archive fork, and export video without burning labels. Insert-move still leaves a source gap. includeLinks=false, caption default clipLocal / follow / interval crop, and leave-gap stay unchanged. Auto-close as part of a move is still not a legal MoveClips mode. Lifting a clipLocal host is refused atomically. Split/roll/slip/slide rebinding, marker sidecar formats, source caption anchors, new-track, cross-project bake, OS clipboard, and I-006 remain closed.

## Evidence

`docs/implementation/evidence/marker-edit/`.
