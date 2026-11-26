# ADR 0095 — Official I-005 1000-random-sequence undo hash for already-official commands including Slip, Roll, and Slide

## Status

Accepted for Increment 1.88 as a bounded slice of the original I-005 remainingAcceptance item “1千随机序列undo后文档hash相等”. This increment officializes that clause only for the already-official command set, including the now-official SlipClip, RollCut, and SlideClip persist paths that Increment 1.38 did not cover. It does not claim a full randomized NLE matrix. I-005 and I-006 remain partial. `fullTaskComplete` stays false.

## Decision

Increment 1.38 / ADR 0045 already qualified 1000 seeded NLE trials (document seed `0x51500500`) of opened move / ripple-delete / ripple-trim / captions / markers / lock / negative-move commands, walking immutable snapshots back to the start content hash. Its `pickOp` does not include SlipClip, RollCut, or SlideClip. The SDK 1.38 companion (seed `0x10005e05`) actually calls workspace `undo` through the official `restoreSnapshot` InversePatch, but likewise omits those commands. I-006 Increment 1.84 (seed `0x16061E84`) is a conservation suite, not an undo-hash claim. Those files are not reused, weakened, or rewritten.

This increment adds two new official suites with distinct seeds:

- `packages/studio_document/test/i005_random_undo_slip_roll_slide_test.dart`, seed `0x18800505`: 1000 seeded sequences of already-official legal operations including SlipClip, RollCut, SlideClip, leave-gap TrimClip, RippleTrimClip, and MoveClips. Occasional constructed refusals stay atomic and do not half-write. `applyEdit` stays pure. Official InversePatch kind is `restoreSnapshot`: walking the immutable before-snapshots of each sequence restores the start content hash.
- `packages/studio_sdk/test/i005_random_undo_slip_roll_slide_test.dart`, seed `0x188005E5`: 1000 seeded sequences of the same already-official command set, each undone through workspace `w.undo()` (journal `restoreSnapshot`) until the origin content hash is restored.

The official count is 1000 sequences, not a claim that every unopened NLE surface was randomized. Stay-inside already-admitted commands: no new-track, no OS clipboard, no auto-close-after-move, no mobile long-press/pinch, no `syncLock`, no field-aware invert of Slip/Roll/Slide, no Retime/transition, and no compound/nest. Official InversePatch kind stays `restoreSnapshot`; this increment does not invent new undo machinery. Production algebra is unchanged; a genuine undo-hash or half-write bug would have been fixed narrowly and reported, and none was found.

## Consequences

The I-005 remainingAcceptance item “1千随机序列undo后文档hash相等” is cleared at this already-official-command bound, including Slip, Roll, and Slide. It is not a full randomized NLE matrix. The section-3 正反例 clause remains open for copy-to-a-new-track, the keyframe row, Retime/transition, compound/nest, video/caption mute/solo, `syncLock`, the table's 0.02s `OFF_FRAME_GRID` link offset, mobile long-press/pinch, auto-close, an OS clipboard, and field-aware invert of Slip/Roll/Slide. I-006 remainingAcceptance stays empty and is not reopened. I-007 is not started.

## Evidence

`docs/implementation/evidence/i005-random-undo-slip-roll-slide/`.
