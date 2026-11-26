# ADR 0094 — Official section-3 roll, slip, and slide positive/negative rows

## Status

Accepted for Increment 1.87 as a bounded slice of the original I-005 remainingAcceptance item “第3节每操作正反例通过”. This increment officializes only the s3 roll, slip, and slide geometry and stated refusals on the same scaled planted A/B/C fixture as Increment 1.39. It does not close the full section-3 matrix and does not clear “1千随机序列undo后文档hash相等”. I-005 and I-006 remain partial. `fullTaskComplete` stays false.

## Decision

Increment 1.39 / ADR 0046 already qualified opened move, split, insert, overwrite, lift, ripple close, ordinary trim, ripple trim, link, and copy-paste-after-C rows, and explicitly left roll, slip, and slide unfinished. Those later became official persist paths in Increments 1.81–1.83, but not against the planted s3 source windows. This increment adds `packages/studio_document/test/s3_roll_slip_slide_matrix_test.dart` and does not rewrite `s3_opened_matrix_test.dart`, `nle_random_undo_test.dart`, `i005_locked_members_negative_range_test.dart`, or the I-006 1.84/1.85 suites.

The fixture is the s3 450-frame A/B/C sequence scaled by 5 onto the 3-second local video (30 fps grid; `f(n) = n/150` seconds): A[0,150) source[30,180), B[150,300) source[60,210), C[300,450) source[0,150). Official positive rows:

- Roll of the A/B cut 150→165: A duration 165 and source [30,195); B start 165, duration 135, source [75,210); C and sequence duration 450 unchanged
- Slip of B by +15 source frames: B source [75,225), B timeline [150,300) unchanged; A, C, and duration 450 unchanged
- Slide of B by +15: A duration 165; B [165,315) with source [60,210) unchanged; C [315,450) source [15,150); left start, C outer end, and duration 450 unchanged

Linked AV partners follow at each stream's source rate. Official negative rows, using already-official codes: `NOT_ADJACENT`, `SOURCE_OUT_OF_RANGE` or the existing `INVALID_RANGE` on a handle or zero-duration shortfall, and `FIELD_LOCKED` on a locked track or `sourceRange`. Failures leave the document unchanged. Source media hashes stay put. Auto-close-after-move is not a `MoveClips` mode. New tracks, cross-project bake, an OS clipboard, and `syncLock` as a writable feature are not opened. Official InversePatch kind stays `restoreSnapshot`. Field-aware invert of Slip, Roll, or Slide is not officialized. Production algebra is unchanged; a genuine geometry or half-write bug would have been fixed narrowly and reported, and none was found.

## Consequences

The section-3 正反例 clause remains open for copy-to-a-new-track, the keyframe row, Retime/transition, compound/nest, video/caption mute/solo, `syncLock`, the table's 0.02s `OFF_FRAME_GRID` link offset, mobile long-press/pinch, auto-close, an OS clipboard, and field-aware invert of Slip/Roll/Slide. The I-005 1000-random undo clause remains the Increment 1.38 opened-command bound and is not cleared. I-006 remainingAcceptance stays empty and is not reopened. I-007 is not started.

## Evidence

`docs/implementation/evidence/s3-roll-slip-slide-matrix/`.
