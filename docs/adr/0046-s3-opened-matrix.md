# ADR 0046 — Qualify already-opened section-3 commands with a positive/negative matrix

## Status

Accepted for Increment 1.39 as a bounded slice of the original I-005 remainingAcceptance item “第3节每操作正反例通过”, limited to already-opened commands. I-005 and I-010 remain partial. This increment does not close the full section-3 matrix.

## Decision

A packed A/B/C fixture, scaled so the s3 450-frame sequence fits the existing 3-second local video (every table frame is divided by 5 and stays on the 30 fps grid), carries the planted linear source windows from the table: A[0,150) source[30,180), B[150,300) source[60,210), C[300,450) source[0,150). Each already-opened row is exercised with the table’s positive geometry and the stated refusal:

- reject MoveClips of A by +30 collides with B; a negative start refuses; the before document is unchanged
- SplitClip of A at 60 remaps the planted source window; endpoints and off-grid times refuse
- insert paste of 60 frames at 150 shifts B to 210 and C to 360, duration 510; a spanning synced audio clip is split with a 60-frame silent hole; a locked syncLock partner refuses SYNC_LOCKED
- overwrite [120,210) keeps the A head, remaps the B tail source, leaves C and duration 450
- lift leaves a gap; ripple close of R=[120,180) remaps the B remnant source to [90,210) and shortens to 390; a locked syncLock partner refuses
- ordinary leave-gap trim: A out −15 leaves a gap and does not move B; A in +15 remaps source to 45; lengthen into B is COLLISION; source exhaustion is SOURCE_OUT_OF_RANGE
- ripple trim: A out −15 and A in +15 match the table (A may keep start 0 on an in trim; duration 435)
- includeLinks keeps a recorded AV offset; includeLinks=false marks allowOutOfSync without rewriting that offset; unlink keeps both clips
- copy A+C and paste after C keeps the 150-frame relative gap, allocates new IDs, and does not copy blobs
- clipLocal captions and markers follow or stay according to already-delivered rules; lifting a clipLocal-marker host is still REF_NOT_FOUND; insert-move still leaves a source gap; auto-close is not a MoveClips mode

A real workbench path splits the 3s clip into packed A/B/C, previews a colliding +6-frame move of A (COLLISION, no write), ripple-trims A out by 3 frames, then undoes, redoes, archives a fork, exports a VTT sidecar, and still refuses preview/MP4 burn-in.

## Consequences

This increment adds no new edit command and no new persistence table. SplitClip and ordinary TrimClip still refuse as a whole group with CAPTION_SYNC_EDIT_NOT_IMPLEMENTED when captions exist; this batch does not open caption-aware split or leave-gap trim. The table’s 0.02s AV offset is off the 30 fps video grid and currently refuses on relink (OFF_FRAME_GRID); the link example uses one frame (1/30 s) on an unsplit pair, because packed A+1s would collide with B. Copy-to-a-new-track, mobile long-press/pinch, roll/slip/slide, field-aware inverse, marker sidecar formats, source-interval crop, and MP4 burn-in remain unfinished.

## Evidence

`docs/implementation/evidence/s3-opened-matrix/`.
