# ADR 0056 — SetTrackState locked (track lock / unlock)

## Status

Accepted for Increment 1.49 as a bounded slice of the original I-005 remaining work on s3 track lock (`SetTrackState{trackId,locked?,…}`). I-005 and I-010 remain partial. This increment does not open video or caption mute/solo (local admission still refuses those flags with `FEATURE_NOT_IMPLEMENTED`), audio muted/solo stays `SetAudioTrackState`, and `syncLock` is not toggled here. It does not open auto-close as a MoveClips mode, source-interval crop, marker sidecar formats, a complete invert matrix, or I-006 roll/slip/slide.

## Context

s3 already specifies a track-head lock: locking a track blocks content, effect, and move edits on that track; the user can still unlock it; the lock meta-op is not blocked by the track's own lock; locking V1 still allows edits on an unlocked caption track. The `locked` field already exists on every track and `FIELD_LOCKED` is already enforced by opened clip, effect, caption, and interval commands. What was missing was a persistent command (and workbench control) to set that flag.

## Decision

Add `SetTrackState(trackId, {required locked})` (`kind: setTrackState`). The command locates one existing track or refuses `TRACK_NOT_FOUND`. Setting the same value is a no-op. The track's own lock does not block this meta-op, so unlock works on a locked track. The sequence version is bumped because the definition hash includes track flags. Captions, markers, clip geometry, source windows, effect curves, audio offsets, and anchors are not rewritten by the command itself.

After a video track is locked, opened clip edits (`MoveClip`, `TrimClip`, `SplitClip`, linked members, and the same-track move family) refuse `FIELD_LOCKED` as a whole group and do not drop or retarget captions. `SetCaptions` on an unlocked caption track still applies. Locking the caption track refuses a changing `SetCaptions` with `FIELD_LOCKED`. Locking a persistent audio track refuses `SetAudioTrackState` mute/solo and clip edits on that track until it is unlocked. Preview and MP4 still refuse caption burn-in (`CAPTION_RENDER_POLICY_NOT_IMPLEMENTED`); export stays a VTT sidecar.

## Consequences

Video/caption muted/solo, caption-solo as a separate mix category, and `syncLock` toggles remain unfinished. Auto-close-on-move, new-track, cross-project bake, OS clipboard, source-interval crop, marker sidecar formats, I-006, MP4 burn-in, and a complete invert matrix remain unfinished. The table’s 0.02s AV offset remains off the 30 fps grid and still refuses `OFF_FRAME_GRID`; alignment stays at 1/30 s. Already-delivered insert-move leave-gap, explicit-range ripple close, `includeLinks=false`, leave-gap and ripple trim/delete, caption-aware `MoveClip` and `LiftClips`/Cut, field-aware invert, caption-aware overwrite, caption default/follow/interval/source-window, marker absolute default / clipLocal follow / ripple interval, 1000 seeded random undo, and the opened section-3 geometry matrix stay unchanged. No new persistence table.

## Evidence

`docs/implementation/evidence/track-lock/`.
