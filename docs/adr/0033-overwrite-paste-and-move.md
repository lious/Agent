# ADR0033 — Overwrite paste and move on existing same-kind tracks

Status: implemented bounded native subset (Increment 1.26); original I-005 remains partial.

## Contract
Read immutable `docs/studio/spec/s3.md` rows for move (mode: reject|overwrite|insert), overwrite, insert, and copy/paste, plus original I-005. Keep the original hard dependency on I-003 and the original acceptance: every section-3 positive/negative, 1000 randomized NLE undo with equal document hash, and whole-group refusal for locked members and negative intervals. No snapshot/acceptance rewrite, no new persistence schema or fingerprint registry.

## Mode bound (honest matrix)
This slice opens only `mode=overwrite` for `PasteClips` and `MoveClips`. Default `mode=reject` is unchanged and still raises `COLLISION` on overlap. `mode=insert` is refused at command construction (`INSERT_MODE_NOT_IMPLEMENTED`); insert/ripple, including ripple-track splits, non-target gaps, caption-anchor policy and syncLock, is not implemented here and is not claimed. New-track creation, cross-project paste/import/bake and the OS clipboard remain unimplemented. Local admission still allows at most one video + one audio + one caption track.

## Temporal semantics
Coverage is the union of each pasted or moved member's destination interval, not a bounding-box punch of the space between gapped members. Intersecting old items are cut; front and back remnants keep remapped sources (linear rate). The first leftover fragment always reuses the original clip id (including a back-only trim-in); later fragments receive new ids and have link/selection membership cleared. Uninvolved later content is not moved. Sequence duration is `max(old end, new ends)` and is never implicitly shortened by carving. Absolute captions stay; other-track music is not auto-deleted.

## Whole-group refusal and transitions
Link closure is included (`includeLinks=true`). Locks, negative starts, off-grid frame/sample times and unsupported animated non-opacity effects abort the entire request; no command writes a subset of the closure. Transitions whose endpoints are touched, or whose handle window intersects a dest interval, are deleted and described by the resulting document. A fully-moved dissolve pair is kept and its `cut` shifts with the pair, even when the new dest intervals overlap the old handle window.

## Verification / remaining scope
Frozen-source commands and outcomes: `docs/implementation/evidence/overwrite/summary.json`. Three actual review/correction rounds: REVIEW.md Increment 1.26. Linux CPU SDR consumer only. Insert/ripple, new-track, cross-project, OS clipboard, mobile/marker matrix, 1000 randomized NLE undo, field-aware inverse, interval index and O(n) history remain unfinished. Old-writer schema9 limitation and historical underrun failures remain; RTC policy unchanged. Local commit only; no push or remote diagnosis.
