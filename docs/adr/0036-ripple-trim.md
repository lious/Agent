# ADR0036 — Ripple trim (shorten one clip and close the vacated tail)

Status: implemented bounded native subset (Increment 1.29); original I-005 remains partial.

## Contract
Read immutable `docs/studio/spec/s3.md` rows for Trim{clipId,edge:in|out,delta:Q,mode:ripple,rippleTrackIds} and original I-005. Keep the original hard dependency on I-003 and the original acceptance: every section-3 positive/negative, 1000 randomized NLE undo with equal document hash, and whole-group refusal for locked members and negative intervals. I-005 scope still excludes “高级trim”; this slice does not open I-006 (roll/slip/slide, TrimPlanner, 1000-length conservation). No snapshot/acceptance rewrite, no new persistence schema or fingerprint registry.

## Mode bound (honest matrix)
This slice opens only first-version ripple trim shortening, as the new command `RippleTrimClip`. It coexists with leave-gap `TrimClip`, video-only `TrimClip(ripple:true)`, `RippleDeleteClips`, and `reject`/`overwrite`/`insert`. `TrimClip(ripple:true)` is not redefined and still raises `LINKED_RIPPLE_NOT_IMPLEMENTED` on persistent-audio/linked AV. Lengthening (`out` with positive delta, `in` with negative delta) is refused `RIPPLE_TRIM_LENGTHEN_NOT_IMPLEMENTED`. Closing a move's vacated source hole is not implemented and is not claimed. New-track creation, cross-project paste/import/bake and the OS clipboard remain unimplemented.

Optional `rippleTrackIds` may be omitted; the default participating set is the target tracks union `syncLock` media tracks. An explicit list may omit other syncLock media tracks but cannot drop targets or include a caption track.

## Temporal semantics
Shorten the complete link closure by timeline δ. For an out edge, duration shrinks at the tail. For an in edge, timeline start stays at the old value, source start advances, and duration shrinks. The vacated tail of the selected clip, R=[oldEnd-δ, oldEnd), is then closed on every participating track: split b then a, drop items fully inside R (except the already-trimmed members), and shift later items by -δ. Sequence duration shrinks by δ, but not below later ends on unmoved non-ripple tracks. Assets are kept. Remnants are not auto-joined. Over-shorten raises `CLIP_TOO_SHORT`.

## Whole-group refusal, transitions, captions
Link closure is included (`includeLinks=true`). Locks on a written field raise `FIELD_LOCKED`. A locked `syncLock` non-target that would have to crop or shift raises `SYNC_LOCKED`. Negative starts, off-grid frame/sample times and unsupported animated non-opacity effects abort the entire request. Absolute captions that would have to crop or shift (cue end > R.start) refuse `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`; cue-follow / anchor policy is not opened. Transitions whose cut is strictly inside R, or whose endpoints vanish or lose adjacency, are dropped; cuts at or after oldEnd remap and subtract δ.

## Verification / remaining scope
Frozen-source commands and outcomes: `docs/implementation/evidence/ripple-trim/summary.json`. Three actual review/correction rounds: REVIEW.md Increment 1.29. Linux CPU SDR consumer only. Ripple-trim lengthening, source-hole close, new-track, cross-project, OS clipboard, caption cue-follow, I-006 roll/slip/slide, mobile/marker matrix, 1000 randomized NLE undo, field-aware inverse, interval index and O(n) history remain unfinished. Old-writer schema9 limitation and historical underrun failures remain; RTC policy unchanged. Local commit only; no push or remote diagnosis.
