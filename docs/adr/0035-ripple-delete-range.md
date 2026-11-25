# ADR0035 — Ripple delete of a single continuous range

Status: implemented bounded native subset (Increment 1.28); original I-005 remains partial.

## Contract
Read immutable `docs/studio/spec/s3.md` rows for DeleteSelection{ids,mode:lift|ripple,range:null|Range,rippleTrackIds} and original I-005. Keep the original hard dependency on I-003 and the original acceptance: every section-3 positive/negative, 1000 randomized NLE undo with equal document hash, and whole-group refusal for locked members and negative intervals. No snapshot/acceptance rewrite, no new persistence schema or fingerprint registry.

## Mode bound (honest matrix)
This slice opens only first-version ripple delete of a single continuous range R, as the new command `RippleDeleteClips`. It coexists with existing `reject`, `overwrite` and `insert` collision modes, and with `LiftClips` / the workbench Delete (leave gap) path. `DeleteClip(ripple:true)` is not redefined and still raises `LINKED_RIPPLE_NOT_IMPLEMENTED` on persistent-audio/linked AV. Ripple trim and closing a move's vacated source hole are not implemented and are not claimed. New-track creation, cross-project paste/import/bake and the OS clipboard remain unimplemented. Local admission still allows at most one video + one audio + one caption track. Multi-range delete as right-to-left multiple commands is not this slice.

Optional `rippleTrackIds` may be omitted; the default participating set is the target tracks union `syncLock` media tracks. An explicit list may omit other syncLock media tracks but cannot drop targets or include a caption track.

## Temporal semantics
R is the merged union of the expanded link and selection closure. Touching or overlapping selected intervals merge; a remaining gap raises `RIPPLE_RANGE_NOT_CONTIGUOUS`. One R=[a,b) of length L is applied to every participating track. Split the later bound b first, then a, so coordinates stay stable. Items fully inside [a,b) are removed; items that span the bounds keep both remnants with remapped sources and opacity; later items shift by -L. Sequence duration shrinks by L, but not below later ends on unmoved non-ripple tracks. Assets are kept. Remnants are not auto-joined.

## Whole-group refusal, transitions, captions
Link closure is included (`includeLinks=true`). Locks on a written field raise `FIELD_LOCKED`. A locked `syncLock` non-target that would have to crop or shift raises `SYNC_LOCKED`. Negative starts, off-grid frame/sample times and unsupported animated non-opacity effects abort the entire request. Absolute captions that would have to crop or shift (cue end > a) refuse `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`; cue-follow / anchor policy is not opened. Transitions whose cut is strictly inside (a,b), or whose endpoints vanish or lose adjacency, are dropped; cuts at or after b remap via the end-split map and subtract L.

## Verification / remaining scope
Frozen-source commands and outcomes: `docs/implementation/evidence/ripple-delete/summary.json`. Three actual review/correction rounds: REVIEW.md Increment 1.28. Linux CPU SDR consumer only. Ripple-trim, source-hole close, new-track, cross-project, OS clipboard, caption cue-follow, mobile/marker matrix, 1000 randomized NLE undo, field-aware inverse, interval index and O(n) history remain unfinished. Old-writer schema9 limitation and historical underrun failures remain; RTC policy unchanged. Local commit only; no push or remote diagnosis.
