# ADR 0042 — Default new and imported cues to clipLocal when uniquely covered

## Status

Accepted for Increment 1.35 on the existing I-005/I-010 SetCaptions and import/add paths. I-005 remains partial. I-010 remainingAcceptance is unchanged.

## Decision

s3 says captions default to clipLocal and travel with the shot. For a **new** cue ID authored as absolute, `SetCaptions` applies `defaultClipLocalIfCovered`: if a unique covering video (else unique covering media) fully contains the cue, it is anchored clipLocal; otherwise it stays absolute (gap or spanning a cut). Existing cue IDs that remain or are made absolute are not converted, so “Make selected cue absolute” stays effective. Source anchors stay refused. MP4 text burn-in stays `CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`.

Insert-move still leaves a source gap. Explicit range close, includeLinks=false, MoveClips follow, and ripple/insert interval crop/split/shift stay unchanged. Auto-close as part of a move is still not a legal MoveClips mode. No new table is added.

## Consequences

Workbench Add cue and SRT/VTT import of a uniquely covered range create a following cue in one persistent command, through undo/redo, reopen, archive fork and sidecar export. Marker business, new-track, cross-project bake, OS clipboard, source caption anchors, burned-in MP4 text, and I-006 remain closed.

## Evidence

`docs/implementation/evidence/caption-default-cliplocal/`.
