# ADR m001 — Official `studio.markers.sidecar` import and export

## Status

Accepted for Increment M.1 as a bounded slice of remaining marker sidecar work. This format is a **new written authorization** recorded in `docs/addenda/marker-sidecar-v1.md`; it is not an enumeration that already existed in the original 104-spec snapshot, and that snapshot is not rewritten. I-005 and I-010 remain partial. This increment does not claim a complete marker matrix.

## Context

The original studio specs define Marker as a core project-document field (`markers[]` in s2 / s5) and describe edit semantics in s3. Section 7 export options remain `captions:burnIn|sidecarSrt`. Earlier increments listed “marker sidecar formats” as unfinished without naming a first official interchange format. The user authorized 啾啾 to specify that format in writing. A typo that wrote 喵喵 was corrected to 啾啾 (U+557E); this is not a new authorization.

## Decision

Admit one official sidecar, `studio.markers.sidecar`: UTF-8 JSON without a BOM, recommended extension `.studio-markers.json`, media type `application/json`. The envelope is `format`, `formatVersion` (this slice writes `1.0.0` and admits the same major `1.y.z`), and `markers` (an array that may be empty). Each entry round-trips the existing Marker object — rational Time JSON, not floating-point seconds — and must not change the core schema.

Export writes every selected marker (default: all project markers) and refuses a missing selected id rather than dropping it. Import restores every official field or rejects the whole file. Unknown extra fields are listed as `MARKER_SIDECAR_UNSUPPORTED` warnings and the file is refused; they are never stripped to invent success. A `clipLocal` host that is missing or no longer covers the marker is `ANCHOR_OUT_OF_RANGE`, never quietly rewritten as `absolute`. A missing target `sequenceId` is `PARENT_MISMATCH`. Marker labels are not burned into preview or MP4, and this sidecar is not an MP4 mux option.

## Consequences

Document and SDK tests cover empty and official-field round trips, silent-drop refusal, and whole-file refusal for missing fields, illegal values, duplicate ids, the wrong format or major version, unknown extra fields, a missing `sequenceId`, and an uncovered or missing `clipLocal` host. WebVTT chapters, CSV, and FCPXML stay closed. I-005 invert paths, source-interval caption crop, MP4 burn-in, and lossless arbitrary ASS effects stay closed. Official InversePatch `kind` stays `restoreSnapshot`.
