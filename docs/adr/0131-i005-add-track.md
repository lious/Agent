# ADR 0131 — I-005 AddTrack / RemoveTrack and copy A+C onto a new video track

## Status

Accepted for Increment 2.32 as a leftover I-005 section-3 row. I-005 stays partial. `fullTaskComplete` stays false. TrimPlanner was not a clean already-specified slice (no s5 payload schema or official planner API; s3 names `command_planner.dart` only as “展开链接/组/轨道集合”), so this increment does not invent a TrimPlanner or new trim modes. Video muted/solo on `SetTrackState`, extra audio/caption tracks, and I-006 TrimPlanner surfaces stay unopened. InversePatch kind stays `restoreSnapshot`. `fullTasksCompleted` stays 0.

## Decision

s5 / s5a already name `addTrack{track}` and `removeTrack{trackId,contentPolicy:rejectIfNotEmpty|removeContents}`. s3's copy/paste example is “复制A+C到新轨at0→0与300，保中间150帧Gap；undo删新增Clip不删源媒体.” Local admission now allows more than one video track so that command can persist. Extra audio or caption tracks still fail `FEATURE_NOT_IMPLEMENTED`. A new video track must be empty, `muted`/`solo` false, and `busId` null; a conflicting `order` is `DUPLICATE_ORDER`; a foreign `sequenceId` is `PARENT_MISMATCH`.

`RemoveTrack` cannot drop the primary (list-index-0) or sole video track. `rejectIfNotEmpty` refuses a populated lane as `INVALID_TRACK_STATE`. `removeContents` drops only that lane's clips, wholly-contained groups, and hosted captions/markers; a cross-track link is `LINK_MEMBERSHIP_MISMATCH`; a locked track is `FIELD_LOCKED`. Source assets and blobs are not deleted.

Opening is not an in-child nest edit, not muted/solo, and not a new I-008 plugin.

## Consequences

I-005 remains partial. The unfinished remainingAcceptance list no longer includes 复制到新轨. Official new suite: 3 tests. Frozen s3 opened matrix, clipboard, locked-members, track lock, and I-006 syncLock bounds suites were re-run, not rewritten. Analyzer exit 0. 87-task counts stay 0 complete / 37 partial / 37 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i005-add-track/`.

## Follow-up

I-006 TrimPlanner stays unopened unless a later increment finds an already-specified planner API. Video/caption mute/solo, OS clipboard, auto-close, mobile gestures, and the 0.02s OFF_FRAME_GRID link-offset example stay unclaimed. Extra audio/caption `addTrack` (I-009 new-track) stays closed.
