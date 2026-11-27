# ADR 0128 — I-006 syncLock, multi-track ripple bounds, and field-aware invert of Slip / Roll / Slide

## Status

Accepted for Increment 2.29 as a leftover remainingScope slice of I-006. I-006 stays partial. `remainingAcceptance` stays empty. InversePatch kind stays `restoreSnapshot`. Video muted/solo on `SetTrackState` are not opened. The planned TrimPlanner surfaces are still not added. `fullTasksCompleted` stays 0.

## Decision

`SetTrackState` now toggles `locked` and/or `syncLock`. At least one field is required (`INVALID_TRACK_STATE` otherwise). The track's own lock does not block this meta-op, so a locked track can still be unlocked or have `syncLock` cleared. muted/solo stay unopened: video mute/solo still fail local admission (`FEATURE_NOT_IMPLEMENTED`); audio muted/solo stay `SetAudioTrackState`.

A locked `syncLock` track that a default insert ripple would have to move is `SYNC_LOCKED` and does not half-write or silently desync. Clearing `syncLock` excludes that track from the default ripple set so the insert can proceed without moving it. An explicit `rippleTrackIds` list is not auto-expanded to other `syncLock` tracks (s3: participating tracks must be listed; the AI must not widen the set).

Field-aware invert of a prior `SlipClip`, `RollCut`, or `SlideClip` uses the existing `documentFieldChanges` / `applyFieldInvert` / `fieldInvertConflicts` path. An unrelated later marker edit or a leave-gap move of a remnant the recorded command did not change can be inverted without dropping those later fields. A later edit that changes a recorded numerator is `UNDO_CONFLICT` and leaves the document unchanged. No new invert algebra is invented, and InversePatch kind is unchanged.

## Consequences

I-006 remains partial. Official new suites: 9 tests (6 invert, 3 syncLock/bounds). Frozen trim invert (4), ripple-trim invert (4), track-lock invert (4), track lock (existing), caption slip/roll/slide, unlink invert (5), and the I-006 trim-mode matrix were re-run, not rewritten. Analyzer exit 0 on `studio_document` and `studio_editor_ui`. 87-task counts stay 0 complete / 37 partial / 37 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i006-sync-lock-and-slip-invert/`.

## Follow-up

TrimPlanner surfaces and video muted/solo stay open. Next honest Linux/Web increment: I-007 UpgradeNest (fit/trim/ripple; no auto-follow) if the spec is a clean slice. OpenNested, reverse, freeze, smooth, and optical-flow stay unclaimed unless actually implemented.
