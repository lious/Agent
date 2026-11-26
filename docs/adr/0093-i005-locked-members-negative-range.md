# ADR 0093 — Official I-005 locked-member and negative-range whole-group refusal

## Status

Accepted for Increment 1.86 as the original I-005 remainingAcceptance item “锁定成员与负区间整组拒”, limited to already-admitted I-005 commands. I-005 and I-006 remain partial. `fullTaskComplete` stays false. This increment does not reuse or rewrite Increment 1.38 (`nle_random_undo_test.dart`), Increment 1.39 (`s3_opened_matrix_test.dart`), or the I-006 1.84/1.85 suites.

## Decision

A locked member or a negative timeline range refuses the whole already-admitted command and leaves the document unchanged (失败 revision 不变; 整组拒; no half-write). Official coverage is `packages/studio_document/test/i005_locked_members_negative_range_test.dart`.

Locked members, all `FIELD_LOCKED`:

- a locked host video track
- a locked linked audio partner track
- a locked `timelineRange` or `sourceRange` field
- a locked other member of a multi-select `MoveClips`

Negative ranges, using already-official codes (not retargeted):

- `MoveClips` reject/overwrite/insert with a delta that would start below 0 → `NEGATIVE_TIMELINE_START`
- `PasteClips` reject/insert/overwrite with `at < 0` → `NEGATIVE_TIMELINE_START` at construction
- `RippleDeleteClips` with `range.start < 0` → `NEGATIVE_TIMELINE_START` at construction
- `SplitClip` at a negative time → `SPLIT_BOUNDARY`
- leave-gap `TrimClip` in-lengthen past 0 → `INVALID_RANGE`

Covered commands: `MoveClips`, `SplitClip`, leave-gap `TrimClip`, `LiftClips`, leave-gap `DeleteClip`, `RippleDeleteClips`, `RippleTrimClip`, and `PasteClips`. Auto-close-after-move is not a `MoveClips` mode. New tracks, cross-project bake, an OS clipboard, and `syncLock` as a writable feature are not opened. Official InversePatch kind stays `restoreSnapshot`. Field-aware invert of Slip, Roll, or Slide is not officialized. Production algebra is unchanged; a genuine whole-group or half-write bug would have been fixed narrowly and reported, and none was found.

## Consequences

The third I-005 remainingAcceptance clause is cleared. The first two clauses remain: “第3节每操作正反例通过” is still not the full section-3 matrix, and “1千随机序列undo后文档hash相等” remains the 1.38 opened-command suite rather than a license to rewrite it here. I-006 remainingAcceptance stays empty and is not reopened; remainingScope still lists 轨锁/syncLock/link/unlink/多轨边界. I-007 is not started.

## Evidence

`docs/implementation/evidence/i005-locked-members-negative-range/`.
