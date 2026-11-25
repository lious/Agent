# ADR0037 — Ripple close an explicit range including a vacated move source

Status: implemented bounded native subset (Increment 1.30); original I-005 remains partial.

## Contract
Read immutable `docs/studio/spec/s3.md` rows for DeleteSelection{range:null|Range} and MoveClips{mode:reject|overwrite|insert}, and original I-005. Keep the original hard dependency on I-003 and the original acceptance: every section-3 positive/negative, 1000 randomized NLE undo with equal document hash, and whole-group refusal for locked members and negative intervals. I-005 scope still excludes “高级trim”; this slice does not open I-006 (roll/slip/slide, TrimPlanner, 1000-length conservation). No snapshot/acceptance rewrite, no new persistence schema or fingerprint registry.

## Mode bound (honest matrix)
Closing a vacated insert-move source is not a fourth MoveClips mode and is not a silent change to insert-move, which must still leave the source as a gap. This slice opens only the already-specified explicit Range on the existing `RippleDeleteClips` command: `RippleDeleteClips([], range: TimeRange(start, duration))` closes one continuous interval R, including that vacated hole, as one persistent command. Clip-id ripple delete is unchanged. Range and clip ids are mutually exclusive (`RIPPLE_RANGE_AND_SELECTION`). It coexists with leave-gap delete/trim, shorten-only `RippleTrimClip`, and `reject`/`overwrite`/`insert`. Ripple-trim lengthening remains `RIPPLE_TRIM_LENGTHEN_NOT_IMPLEMENTED`. New-track creation, cross-project paste/import/bake and the OS clipboard remain unimplemented.

For a range-only request, targets are empty, so the default participating set is `syncLock` media tracks. An explicit `rippleTrackIds` list may be supplied but cannot include a caption track.

## Temporal semantics
Close one continuous interval R=[a,b) of length L on every participating track: split b then a, drop items fully inside R, remap remnants that span R, and shift later items by -L. Sequence duration shrinks by L, but not below later ends on unmoved non-ripple tracks. Assets are kept. Remnants are not auto-joined. Insert-move still vacates its source until this range command is used. Empty ids without a range still raise `EMPTY_SELECTION`. A negative range start raises `NEGATIVE_TIMELINE_START`. `TimeRange` still throws `INVALID_RANGE` for a non-positive duration.

## Whole-group refusal, transitions, captions
Clip-id path still includes link closure (`includeLinks=true`). Locks on a written field raise `FIELD_LOCKED`. A locked `syncLock` non-target that would have to crop or shift raises `SYNC_LOCKED`; range-only close on a locked syncLock track is `SYNC_LOCKED` because there are no selected targets. Negative starts, off-grid frame/sample times and unsupported animated non-opacity effects abort the entire request. Absolute captions that would have to crop or shift (cue end > R.start) refuse `CAPTION_SYNC_EDIT_NOT_IMPLEMENTED`; cue-follow / anchor policy is not opened. Transitions whose cut is strictly inside R, or whose endpoints vanish or lose adjacency, are dropped; later cuts remap and subtract L.

## Verification / remaining scope
Frozen-source commands and outcomes: `docs/implementation/evidence/ripple-close/summary.json`. Three actual review/correction rounds: REVIEW.md Increment 1.30. Linux CPU SDR consumer only. Ripple-trim lengthening, auto-close as part of a move, new-track, cross-project, OS clipboard, caption cue-follow, I-006 roll/slip/slide, mobile/marker matrix, 1000 randomized NLE undo, field-aware inverse, interval index and O(n) history remain unfinished. Old-writer schema9 limitation and historical underrun failures remain; RTC policy unchanged. Local commit only; no push or remote diagnosis.
