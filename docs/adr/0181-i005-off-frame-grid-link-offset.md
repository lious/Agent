# ADR 0181 — Official s3 0.02s AV link-offset example (I-005 leftover)

## Status

Accepted for Increment 2.82 as a distinct already-specified I-005 leftover: the s3 table example “视频0秒/音频0.02秒链接，move+1秒后1/1.02；强制只移视频+1显示+1秒不同步；unlink后两Clip仍在.” I-005 stays partial and is not marked complete. This increment does not invent a TrimPlanner or new trim modes, does not open video or caption muted/solo on SetTrackState, and does not invent OS clipboard, auto-close, or mobile gestures. Other I-005 remainingAcceptance labels (关键帧行, Retime/转场, 复合嵌套, 视频/字幕mute/solo, syncLock, 移动端长按/双指, auto-close, OS剪贴板, Slip/Roll/Slide字段级invert) are not silently cleared. The frozen s3 opened-matrix suite still uses its 1/30 s substitute and is not rewritten. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged.

This increment does not re-qualify Increment 2.81 V-023 PressureAdmission, leftover V-023 labels, Increments 2.74–2.80 s6c default-delivery slices, V-006 metadata/range preservation, I-024, I-007, V-004 leftovers, V-002 format-reason leftovers, I-042 pack leases, V-001 toolchain probes, or I-015 leftovers. CompatibilityStore / ModelLease are not started. I-059 stays planned. I-061 and I-055 are not started. A limiter is not invented. I-013 stays partial. I-014 stays partial. I-035 stays planned. I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. No paid API is called. `run_probe.py` is not opened as a claimed qualification.

## Decision

s3 requires that a linked AV pair may record a 0.02s audio offset: video at 0s, audio at 0.02s (on the 48 kHz sample grid). A default includeLinks move +1s yields 1s / 1.02s. Forcing a move of the video only marks `allowOutOfSync` and leaves the audio in place. Unlink keeps both clips and does not relocate them. Link records the current offset.

The earlier s3 opened-matrix slice deferred this example because unlink/relink after a 0.02s audio offset refused `OFF_FRAME_GRID`. The cause was not the audio start itself: `_persistentAudioEdit` reused the audio-extended sequence duration as a video-track `retain` and invented a 3s–3.02s video tail gap, which is off the 30 fps grid. This increment changes only that retain: a video track is extended to `retain` only when `retain` is on the sequence frame grid. Off-grid video clip starts still fail (`NOT_ON_FRAME` at MoveClips; `OFF_FRAME_GRID` in the document validator). The 0.02s leftover is the audio link offset, not a waiver of the video frame grid.

Official suite: `packages/studio_document/test/i005_off_frame_grid_link_offset_test.dart` (3). Frozen s3 opened-matrix, persistent-audio, unlink invert, and multi-move suites were re-run, not rewritten.

## Consequences

The s3 0.02s OFF_FRAME_GRID link-offset example is officialized. I-005 stays partial. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i005-off-frame-grid-link-offset/`.

## Follow-up

TrimPlanner, video/caption muted/solo on SetTrackState, OS clipboard, auto-close, and mobile gestures stay unopened. Other listed I-005 remainingAcceptance labels stay listed unless a later increment honestly reconciles them with evidence. The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime; do not re-qualify this 0.02s link-offset slice.
