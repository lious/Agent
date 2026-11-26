# ADR m002 — Workbench import and export of official `studio.markers.sidecar`

## Status

Accepted for Increment M.2 as a bounded workbench path for the official marker sidecar already admitted in Increment M.1 / ADR m001 and `docs/addenda/marker-sidecar-v1.md`. I-005 and I-010 remain partial. This increment does not claim a complete marker matrix and does not name a second format.

## Context

M.1 landed document-level `studio.markers.sidecar` import and export. The workbench already had a Markers panel for add/edit/anchor and a Caption editor path for SRT/VTT sidecar import/export. Official marker sidecar files were not yet reachable from those buttons. A typo in the M.1 addendum and ADR that wrote 喵喵 was corrected to 啾啾 (U+557E) in the same increment as this workbench path; that correction is not a new authorization, and the M.1 commit was not amended.

## Decision

Add workbench Import official marker sidecar / Export official marker sidecar controls, and matching `StudioWorkspace.importMarkers` / `exportMarkers` methods, for `.studio-markers.json` only. Export writes every current project marker through the M.1 encoder and overwrites the chosen path atomically. Import reads the file against the current project, then applies `SetMarkers` with the complete official store — it replaces all project markers, restores official ids and fields, or refuses the whole file. Unknown extra fields remain `MARKER_SIDECAR_UNSUPPORTED` and are never stripped to invent success. A `clipLocal` host that is missing or no longer covering is still `ANCHOR_OUT_OF_RANGE`, never rewritten as `absolute`. Marker labels are not burned into preview or MP4, and this path is not an MP4 mux option.

## Consequences

A metadata workbench path can add absolute markers, export the official sidecar, delete one marker, import the file, and get both official objects back; an unknown extra field shows `MARKER_SIDECAR_UNSUPPORTED` and does not change the project. A persist-path SDK test covers the same APIs with a `clipLocal` marker present. WebVTT chapters, CSV, and FCPXML stay closed. I-005 invert paths, core schema, source-interval caption crop, MP4 burn-in, and lossless arbitrary ASS effects stay closed. Official InversePatch `kind` stays `restoreSnapshot`.
