# ADR 0092 — Official I-006 trim-mode matrix (handles, cross-link, locked tracks)

## Status

Accepted for Increment 1.85 as the original I-006 remainingAcceptance item “全部trim模式逐条含handles/跨链接/锁轨断言”. I-005 and I-006 remain partial. `fullTaskComplete` stays false. The planned `trim_planner.dart` / `test/nle/trim_modes/` / `tools/acceptance/cases/i006.py` surfaces are not added, because the acceptance is case-by-case assertions on already-official commands rather than a new planner or command shape.

## Decision

Every already-admitted trim-family mode is covered in `packages/studio_document/test/i006_trim_mode_matrix_test.dart`:

- leave-gap `TrimClip` (in/out shorten; lengthen into a gap)
- `RippleTrimClip` (in/out shorten and lengthen)
- `SlipClip`
- `RollCut`
- `SlideClip`

For each mode the official assertions are:

- **Handles:** a linear TimeMap keeps `sourceDuration == rate * timelineDuration`, and `sourceRange` stays inside the available stream. A head or tail shortfall is a whole-command `SOURCE_OUT_OF_RANGE`, or the existing document-parse `INVALID_RANGE` when a source start would go negative or a remnant duration would hit zero. Leave-gap lengthen into a neighbor is `COLLISION` and does not delete the neighbor (不可擅自删邻clip; 源不足整命令拒).
- **Cross-link:** linked AV stays a whole group; each member conserves its own source map; a locked audio partner refuses the whole command as `FIELD_LOCKED` and does not half-write. Sync is not silently broken. `syncLock` is not opened as a writable feature.
- **锁轨:** a locked host track, a locked linked partner track, or a locked `sourceRange` field is whole-group `FIELD_LOCKED` and leaves the document JSON and content hash unchanged.

The generator does not reopen refused modes, does not officialize field-aware invert of Slip, Roll, or Slide, and does not rewrite Increment 1.84 (`i006_random_legal_inputs_test.dart`) or the I-005 undo suite (`nle_random_undo_test.dart`). Official InversePatch kind stays `restoreSnapshot`. Production algebra is unchanged in this increment; a handles, cross-link, or half-write bug on an already-official path would have been fixed narrowly and reported, and none was found.

## Consequences

The remainingAcceptance sentence for this clause is cleared. I-006 remains partial: remainingScope still lists 轨锁/syncLock/link/unlink/多轨边界, field-aware invert of Slip/Roll/Slide is unfinished, and I-007 is not started. Video/caption mute/solo stay `FEATURE_NOT_IMPLEMENTED`; audio mute/solo stay `SetAudioTrackState`.

## Evidence

`docs/implementation/evidence/i006-trim-mode-matrix/`.
