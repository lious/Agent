# ADR M.3 — Integrate official marker sidecar onto the feature branch

## Status

Accepted as an integration of already-verified Increments M.1 and M.2 onto `feat/studio-foundation-20261125` after Increment 1.82. This is not a new editing command and is not claimed as part of the original 104-spec snapshot. The format remains `studio.markers.sidecar` as decided; it is not reinvented here. I-005 and I-006 remain partial. SlideClip is not opened. Official InversePatch `kind` stays `restoreSnapshot`.

## Context

The official marker sidecar was completed on the independent branch `feat/studio-marker-sidecar` at `67821dfe` (M.2), with M.1 at `6cfe464`, forked from Increment 1.70 (`6a9b4baf`). The shared feature branch had since admitted Increments 1.71–1.82, including caption-aware SlipClip and RollCut and their workbench buttons. Those two sidecar commits are integrated linearly onto `6732b081` as a single commit.

## Decision

Cherry-pick M.1 then M.2 onto `6732b081` and collapse them to one integration commit whose unique parent is `6732b081`. The only content conflict was `docs/implementation/task-status.json`; it keeps the 1.71–1.82 invert/slip/roll status and records the integrated sidecar evidence. `packages/studio_editor_ui/lib/studio_editor_ui.dart` auto-merged: the Increment 1.81 Slip button and Increment 1.82 Roll button stay, and the official marker sidecar path plus import/export buttons (`marker-sidecar-path`, `marker-import-sidecar`, `marker-export-sidecar`) are added. `StudioWorkspace.exportMarkers` / `importMarkers` and `packages/studio_document/lib/marker_sidecar.dart` are carried forward unchanged in contract.

Format and refusal rules stay as already verified: UTF-8 JSON with no BOM, recommended extension `.studio-markers.json`, envelope `format` fixed `"studio.markers.sidecar"`, `formatVersion` `"1.0.0"` (import may accept same major `1.y.z`). Export writes every marker in the selected scope or refuses missing ids; no silent drop. Import restores all legal official fields or refuses the whole file. Workbench import replaces all project markers via existing `SetMarkers` and does not append. Unknown extra fields warn `MARKER_SIDECAR_UNSUPPORTED:<path>` and refuse the file. A clipLocal `clipId` that is missing or no longer covering the range is `ANCHOR_OUT_OF_RANGE`, never silently converted to absolute. A missing `sequenceId` in the target project is `PARENT_MISMATCH`. Labels are not burned into preview or MP4. WebVTT chapters, CSV, and FCPXML compatibility stay closed.

Already-delivered edit algebra, invert paths (including the 1.73/1.78 version bumps and the 1.79 gap-insert path), the 1.81 slip caption path, and the 1.82 roll caption path are not changed. `IMPLICIT_GAP` and the listed official error codes are not retargeted.

## Consequences

The shared feature branch now has official marker sidecar import/export and a workbench path, alongside caption-aware Slip and Roll. I-006 is still not complete (SlideClip and 1000 random legal inputs remain). Marker sidecar is still not a complete marker matrix. This integration does not push and does not merge to `main`.
