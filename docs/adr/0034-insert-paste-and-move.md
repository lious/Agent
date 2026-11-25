# ADR0034 — Insert paste and move on existing same-kind tracks

Status: implemented bounded native subset (Increment 1.27); original I-005 remains partial.

## Contract
Read immutable `docs/studio/spec/s3.md` rows for insert, move (mode: reject|overwrite|insert), and copy/paste, plus original I-005. Keep the original hard dependency on I-003 and the original acceptance: every section-3 positive/negative, 1000 randomized NLE undo with equal document hash, and whole-group refusal for locked members and negative intervals. No snapshot/acceptance rewrite, no new persistence schema or fingerprint registry.

## Mode bound (honest matrix)
This slice opens only `mode=insert` for `PasteClips` and `MoveClips`, alongside the existing `reject` and `overwrite` modes. Default `reject` still raises `COLLISION` on overlap; overwrite still carves destination intervals without moving later content. Ripple-delete, ripple-trim, and ripple-closing the source hole of a move are not implemented and are not claimed. New-track creation, cross-project paste/import/bake and the OS clipboard remain unimplemented. Local admission still allows at most one video + one audio + one caption track.

Optional `rippleTrackIds` is legal only with insert. When omitted, participating tracks are the destination/target tracks union `syncLock` media tracks. An explicit list may omit other syncLock media tracks but cannot drop targets or include a caption track. Timeline insert/move still must name participating tracks; the workbench uses the default union.

## Temporal semantics
Length `L` is the package span (earliest start to latest end), not a per-member punch, so a gapped A+C package keeps its middle gap and opens one hole of that span. At `at`, ripple tracks split any item that strictly spans the point (left keeps the original id; right gets a new id; sources and opacity curves remap). Items with start ≥ `at` shift by `L`. Non-target ripple tracks receive a gap of length `L`. Sequence duration grows by `L`. A move first lifts the closure out of its source (leaving a gap, not closing it), then opens the destination the same way.

## Whole-group refusal, transitions, captions
Link closure is included (`includeLinks=true`). Locks on a written target raise `FIELD_LOCKED`. A locked `syncLock` non-target that would have to split or shift raises `SYNC_LOCKED`. Negative starts, off-grid frame/sample times and unsupported animated non-opacity effects abort the entire request. Absolute captions that would have to move or split refuse `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`; cue-follow / anchor policy is not opened in this slice. A transition whose cut equals `at` is deleted; a dissolve after a mid-clip insert is remapped onto the right remnant and shifted; a fully-moved pair keeps and shifts its cut. Split AV link pairs get a rebuilt right-hand group with recomputed offsets.

## Verification / remaining scope
Frozen-source commands and outcomes: `docs/implementation/evidence/insert/summary.json`. Three actual review/correction rounds: REVIEW.md Increment 1.27. Linux CPU SDR consumer only. Ripple-delete/trim, source-hole close, new-track, cross-project, OS clipboard, caption cue-follow, mobile/marker matrix, 1000 randomized NLE undo, field-aware inverse, interval index and O(n) history remain unfinished. Old-writer schema9 limitation and historical underrun failures remain; RTC policy unchanged. Local commit only; no push or remote diagnosis.
