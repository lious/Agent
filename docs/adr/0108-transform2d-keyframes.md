# ADR 0108 — Admit registered transform2d@1.0.0 keyframes (Ken Burns)

## Status

Accepted for Increment 2.05 as a bounded slice of the remaining I-008 animation/keyframe contract (§3 SetKeyframe, §4 Ken Burns / transform2d). I-008 stays partial. `fullTaskComplete` stays false. This increment does not open luma, unregistered plugins, a full unspecced filter suite, crop/colorBasic animation, audioEqualPower, freeze, or new Effect types, and does not claim the V-003 render gate is closed. Leftover I-008 remainingAcceptance items 「缺handles拒」, 「关键帧边界连续」, and 「一次提案原子undo恢复hash」 are not re-qualified and remain listed.

## Context

Increments 1.15–1.18 already admitted static opacity, clip-local hold/linear opacity keys, static transform2d@1.0.0 (seven parameters, matrix order, pixel-center inverse bilinear linear-light CPU consumer), video dissolve, and static crop/colorBasic in the canonical crop → transform → color → opacity → dissolve order. Increment 1.89 officialized already-admitted `UNSUPPORTED_EDIT_TECHNIQUE` refusal paths and left animated transform refused as `TRANSFORM_ANIMATION_NOT_IMPLEMENTED`. §4 states that Ken Burns is transform keyframes, not video generation. There was no official write path to persist registered transform2d animation, and `admittedClipEffects` refused any transform keys.

## Decision

Add `SetTransformKeyframe` and `RemoveTransformKeyframe` (`kind: setTransformKeyframe` / `removeTransformKeyframe`) as official persist commands, following the specialized opacity/gain command pattern rather than a generic SetKeyframe and without a pluginVersion or Effect.type bump. Official admission accepts hold/linear keys on the already-registered transform2d@1.0.0 parameters only: translateX, translateY, scaleX, scaleY, rotationDeg, anchorX, and anchorY. Semantics reuse the admitted opacity machine: times are quantized to the project frame grid (`KEYFRAME_NOT_ON_FRAME`); at most 256 points per effect; same param/time replace keeps the point id; outgoing interpolation is half-open `[a,b)` with endpoint holds; trim interpolates at the boundary and rebases; split clones owners and point ids; slip / dragging a clip leaves clip-local keys unchanged. Unkeyed parameters hold their static values. Dart compiles per-frame schedules; native consumes `transformFrames` (or a constant `transform2d` when every frame is identical) and does not host a second interpolator.

Unknown interpolation, audio clips, and easing stay `UNSUPPORTED_EDIT_TECHNIQUE`. Unregistered parameters and adapters that lack `linearTransform2dKeyframesV1` stay `TRANSFORM_ANIMATION_NOT_IMPLEMENTED` — that code is not retargeted and is not used for the newly admitted success path. An animated curve refuses static `SetClipTransform` (`ANIMATED_TRANSFORM_REQUIRES_EXPLICIT_KEYFRAME_EDIT`) and does not clear keys. InversePatch kind stays `restoreSnapshot`. Linear undo/redo stay tip snapshot restores.

## Consequences

Luma, unregistered plugins, crop/colorBasic animation, I-007 remapping/nest, field-aware invert matrix rows for the new commands, and V-003 / Increment 1.17/1.18 clock certification are not opened. Production algebra of opacity, gain, and dissolve is unchanged except that shared crop/admission helpers now also recognize admitted transform2d curves (gain/opacity crop behavior is unchanged). Official I-008 remainingAcceptance leftover items stay listed.

## Evidence

`docs/implementation/evidence/transform-keyframes/`.
