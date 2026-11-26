# ADR 0091 — Official I-006 1000 random legal inputs (length/source-range conservation; no half-write)

## Status

Accepted for Increment 1.84 as the original I-006 remainingAcceptance item “1千随机合法输入长度/源范围守恒；失败不半写”. The other I-006 remainingAcceptance clause “全部trim模式逐条含handles/跨链接/锁轨断言” is not closed by this increment. I-005 and I-006 remain partial. `fullTaskComplete` stays false.

## Decision

A seeded, deterministic document-algebra suite applies 1000 already-official legal I-006 operations (SlipClip, RollCut, SlideClip, leave-gap TrimClip, RippleTrimClip, including linked AV when ExtractAudioClip is already official). Caption-aware SplitClip is used only to build packed topology and is not counted toward the 1000. The official seed is `0x16061E84`. This is not a substitute for:

- Increment 1.38 / ADR 0045 `packages/studio_document/test/nle_random_undo_test.dart` (seed `0x51500500`), which is the I-005 item “1千随机序列undo后文档hash相等”
- the SDK undo driver (seed `0x10005e05`)
- the existing 1000 seeded legal slip/inverse cases in `edit_algebra_test.dart` (seed `251125`)

Those files are not weakened, rewritten, or reused as this acceptance.

Length and source-range conservation is the original I-006 / `docs/studio/spec/s3.md` meaning, not a weaker invented invariant:

- every media clip keeps a linear TimeMap with `sourceDuration == rate * timelineDuration`
- `sourceRange` stays inside the available stream (`sourceRange.start >= 0` and `sourceRange.start + sourceRange.duration <= stream duration`)
- sequence duration equals the cover of items and captions (总时长正确)
- slip keeps `timelineRange` and sequence duration
- roll keeps the left start, the right outer end, and sequence duration
- slide keeps the left start, the right outer end, the middle duration and sourceRange, and sequence duration
- leave-gap trim, slip, roll, and slide do not silently delete a neighbor (不可擅自删邻clip)
- source media hashes (`originalBlobHash`) and clip source identity are unchanged (源hash不变)
- `applyEdit` is a pure function: the before document is unchanged after success

Failures (`NOT_ADJACENT`, `ANCHOR_OUT_OF_RANGE`, `SOURCE_OUT_OF_RANGE`, `FIELD_LOCKED`, `TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL`, `CAPTION_OVERLAP`, and other existing codes including `INVALID_RANGE` and `COLLISION`) leave the document JSON and content hash unchanged — 失败不半写 / s3 “失败不半提交”. A negative source start is the existing `INVALID_RANGE` raised at document parse; a tail overshoot of the available stream remains `SOURCE_OUT_OF_RANGE`. Those codes are not retargeted.

The generator only proposes operations the current official algebra already admits. It does not silently admit previously refused commands, auto-close, new tracks, syncLock, or field-aware invert of Slip/Roll/Slide. Official InversePatch kind stays `restoreSnapshot`. Production edit algebra is unchanged in this increment; a conservation or half-write bug on an already-official path would have been fixed narrowly and reported, and none was found.

## Consequences

I-006 remains partial. The trim-mode/handles/cross-link/lock matrix is still unfinished (`trim_planner.dart`, `test/nle/trim_modes/`, and `tools/acceptance/cases/i006.py` are still absent). Field-aware invert of Slip, Roll, or Slide is not officialized. This increment does not start I-007, an underrun hunt, or xd10 work, and does not rewrite C.1–C.3 caption production or A.1 audio bus production.

## Evidence

`docs/implementation/evidence/i006-random-legal-inputs/`.
