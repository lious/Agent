# ADR 0112 — Official coverage of admitted keyframe and lumaWipe behavior under admitted edit commands

## Status

Accepted for Increment 2.12 as a bounded official-coverage slice of already-admitted opacity / transform2d / clip-gain keyframes and registered lumaWipe incomingLuma. I-008 stays partial. I-005 stays partial. This increment does not open new effects, does not rewrite `TRANSFORM_ANIMATION_NOT_IMPLEMENTED`, does not change InversePatch (`restoreSnapshot`), and does not re-qualify I-008 leftover remainingAcceptance items 「缺handles拒」, 「关键帧边界连续」, or 「一次提案原子undo恢复hash」. The source clone labeled this Increment 2.10 and ADR 0111; those identifiers are remapped only on this feature-branch commit.

## Context

Registered transform2d keyframes (Increment 2.05) already crop on split / trim via `cropTransformPoints`, keep clip-local keys on slip, and hold the interpolated boundary when a cropped in-point is extended. Official tests covered those commands, but not overwrite-crop interpolation of a transform2d curve, even though `overwrite.dart` already calls `cropTransformPoints`. Opacity overwrite-crop, and clip-gain split / trim / slip / overwrite-crop, already had official cases (including Increment 2.06).

Registered lumaWipe incomingLuma (Increment 2.09) already refuses same-window occupancy with `TRANSITION_WINDOW_CONFLICT` at write time, and `edit_algebra.dart` already refuses SplitClip / TrimClip / MoveClip / RollCut / SlideClip of a transition or luma host with `TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL`. Those topology refusals, SlipClip, and overwrite-crop into a luma window had no dedicated official luma cases. The implemented SlipClip path does not match the dissolve "revalidate handles" success path: a sequence-owned lumaWipe is not silently dropped or rewritten, and SlipClip refuses the whole command with `UNSUPPORTED_EDIT_TECHNIQUE`. Overwrite paste into a luma window refuses with `TRANSITION_NOT_ADJACENT` or `REF_NOT_FOUND` and does not fall back to dissolve.

FoundationApp already exposes `SetTransformKeyframe` / `RemoveTransformKeyframe`, lumaWipe incomingLuma, and opacity keyframe controls, with official `locate()` UI tests from Increments 2.05 / 2.09 and the earlier opacity-keyframe slice.

## Decision

Add official document tests in a new file, without rewriting frozen 2.02 / 2.05 / 2.06 / 2.09 official test files, without rewriting `foundation_app_test.dart`, and without changing production algebra. Officialize the already-implemented transform2d overwrite-crop interpolation contract and the already-implemented lumaWipe refusals under admitted split / trim / slip / overwrite-crop. Do not add workbench controls or UI tests, because those surfaces already exist. Do not clear I-008 or I-005 leftover remainingAcceptance lists.

## Consequences

No new effects, no colorBasic or crop animation, no maskWipe / assetLuma / assetAlpha, no RenderGraph / GPU FrameLease, no I-007 / I-026 / V-003 work, and no native library replacement. I-008 and I-005 remain partial.

## Evidence

`docs/implementation/evidence/admitted-keyframe-edits/`.
