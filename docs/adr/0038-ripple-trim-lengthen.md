# ADR0038 — Ripple trim lengthen (grow a clip and shift later content)

Status: implemented bounded native subset (Increment 1.31); original I-005 remains partial.

## Contract
Read immutable `docs/studio/spec/s3.md` row for Trim{clipId,edge:in|out,delta:Q,mode:ripple,rippleTrackIds} and original I-005. The row first applies the trim, computes the duration difference Δ, and shifts items after the edit boundary on participating tracks by Δ; in trim pins timelineStart at the old value. Keep the original hard dependency on I-003 and the original acceptance: every section-3 positive/negative, 1000 randomized NLE undo with equal document hash, and whole-group refusal for locked members and negative intervals. I-005 scope still excludes “高级trim”; this slice does not open I-006 (roll/slip/slide, TrimPlanner, 1000-length conservation). No snapshot/acceptance rewrite, no new persistence schema or fingerprint registry.

## Mode bound (honest matrix)
Lengthening is not a new MoveClips mode and does not change insert-move, which must still leave the source as a gap. This slice opens both signs of Δ on the existing `RippleTrimClip` command. It coexists with leave-gap `TrimClip`, video-only `TrimClip(ripple:true)`, clip-id and range `RippleDeleteClips`, and `reject`/`overwrite`/`insert`. `TrimClip(ripple:true)` is not redefined and still raises `LINKED_RIPPLE_NOT_IMPLEMENTED` on persistent-audio/linked AV. Auto-close as part of a move, new-track creation, cross-project paste/import/bake and the OS clipboard remain unimplemented.

Optional `rippleTrackIds` may be omitted; the default participating set is the target tracks union `syncLock` media tracks. An explicit list may omit other syncLock media tracks but cannot drop targets or include a caption track.

## Temporal semantics
Δ is `out.delta`, or `-in.delta` when start is pinned. Shorten (Δ<0) still closes the vacated tail. Lengthen (Δ>0) grows the complete link closure by Δ (out extends the tail; in keeps timeline start, reveals earlier source, and extends the tail), splits other participating items at the old end, and shifts later items by +Δ. Sequence duration changes by Δ, but not below later ends on unmoved non-ripple tracks. Assets are kept. Remnants are not auto-joined. Source start below 0 or source past the stream duration raises `SOURCE_OUT_OF_RANGE`. Over-shorten raises `CLIP_TOO_SHORT`.

## Whole-group refusal, transitions, captions
Link closure is included (`includeLinks=true`). Locks on a written field raise `FIELD_LOCKED`. A locked `syncLock` non-target that would have to crop or shift raises `SYNC_LOCKED`. Negative starts, off-grid frame/sample times and unsupported animated non-opacity effects abort the entire request. Absolute captions that would have to crop or shift (cue end > affected start) refuse `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`; cue-follow / anchor policy is not opened. For shorten, transitions whose cut is strictly inside the vacated tail, or whose endpoints vanish or lose adjacency, are dropped; later cuts remap and subtract |Δ|. For lengthen, cuts at or after the old end remap and add Δ.

## Verification / remaining scope
Frozen-source commands and outcomes: `docs/implementation/evidence/ripple-trim-lengthen/summary.json`. Three actual review/correction rounds: REVIEW.md Increment 1.31. Linux CPU SDR consumer only. Auto-close as part of a move, new-track, cross-project, OS clipboard, caption cue-follow, I-006 roll/slip/slide, mobile/marker matrix, 1000 randomized NLE undo, field-aware inverse, interval index and O(n) history remain unfinished. Old-writer schema9 limitation and historical underrun failures remain; RTC policy unchanged. Local commit only; no push or remote diagnosis.
