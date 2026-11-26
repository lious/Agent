# ADR 0096 — Official I-008 unknown-technique refusal `UNSUPPORTED_EDIT_TECHNIQUE`

## Status

Accepted for Increment 1.89 as a bounded slice of the original I-008 remainingAcceptance item “未知技术UNSUPPORTED_EDIT_TECHNIQUE”. This increment officializes that already-admitted refusal on already-admitted opacity, admission, and registry paths. It does not add luma, unregistered plugins, animated transform, audioEqualPower, freeze, or new effect types as success paths. I-008 remains partial. `fullTaskComplete` stays false.

## Decision

Increments 1.15–1.18 already implemented and, in several suites, threw a generic `StudioException` when an unknown interpolation, plugin version, extension map, or unknown node was presented. They did not officialize the exact remainingAcceptance code `UNSUPPORTED_EDIT_TECHNIQUE` as that I-008 clause, and those suites are not reused, weakened, or rewritten.

This increment adds `packages/studio_document/test/i008_unsupported_edit_technique_test.dart`. Official refused paths, all already admitted in production:

- `SetOpacityKeyframe` with interpolation other than `hold` or `linear` is `UNSUPPORTED_EDIT_TECHNIQUE`; `applyEdit` is pure and the document is unchanged
- `SetClipOpacity` and `SetOpacityKeyframe` on an extracted audio clip are `UNSUPPORTED_EDIT_TECHNIQUE` and do not half-write
- Writable admission of a schema-valid document with `pluginVersion != 1.0.0`, a non-empty `extensions` map, or an effect owned by an audio clip is `UNSUPPORTED_EDIT_TECHNIQUE` and does not strip the unknown node
- `admittedClipEffects` and `captureRasterEffects` refuse an unknown technique (`lumaWipe` is used only as a refusal input) as `UNSUPPORTED_EDIT_TECHNIQUE`

Existing codes are not retargeted. A non-null keyframe `easing` field remains `SCHEMA_TYPE` at `fromJson`. An unknown `Effect.type` in a project document remains `SCHEMA_UNION` at `fromJson`. An unreferenced or video-owned effect id on the wrong clip remains `EFFECT_OWNER_MISMATCH`. Animated `transform2d` keyframes remain `TRANSFORM_ANIMATION_NOT_IMPLEMENTED`. Official InversePatch kind stays `restoreSnapshot`. Production algebra is unchanged; a genuine in-scope mis-code would have been fixed narrowly and reported, and none was found.

## Consequences

The I-008 remainingAcceptance item “未知技术UNSUPPORTED_EDIT_TECHNIQUE” is cleared at this already-admitted-command and admission bound. “缺handles拒”, “关键帧边界连续”, and “一次提案原子undo恢复hash” are not re-qualified here: Increment 1.17 already asserts `TRANSITION_HANDLE_MISSING` for missing dissolve handles, Increment 1.15 already asserts split/trim/slip boundary and edge-hold continuity, and Increments 1.15–1.18 already undo a single official proposal and compare the content hash through workspace `undo`. Those three clauses remain listed rather than being silently reduced. Luma, unregistered plugins, animated transform, audioEqualPower, freeze, and new effect types are not opened as success paths. I-007 is not started. Closed I-005 section-3 rows are not opened.

## Evidence

`docs/implementation/evidence/i008-unsupported-edit-technique/`.
