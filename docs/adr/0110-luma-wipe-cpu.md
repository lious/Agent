# ADR 0110 — Admit registered lumaWipe@1.0.0 incomingLuma Linux CPU

## Status

Accepted for Increment 2.09 as a bounded slice of the remaining I-008 contract (registered luma). I-008 stays partial. `fullTaskComplete` stays false. This increment opens only `maskMode=incomingLuma` on the reviewed plugin `studio.fx/lumaWipe@1.0.0` for the Linux CPU reference path. It does not open `studio.fx/maskWipe`, `assetLuma`, `assetAlpha`, unregistered plugins, a full unspecced filter suite, crop/colorBasic animation, audioEqualPower, freeze, I-007, V-003, or a new Transition.kind, and does not invent RenderGraph, GPU FrameLease, Metal, GLSL, HLSL, or Web WGSL. Leftover I-008 remainingAcceptance items 「缺handles拒」, 「关键帧边界连续」, and 「一次提案原子undo恢复hash」 are not re-qualified and remain listed.

## Context

Spec s8f defines LumaWipe as a sequence-owned Effect (plugin type `studio.fx/lumaWipe`, pluginVersion 1.0.0), not a Transition.kind and not a dissolve-field spoof. Increments 1.15–1.18 and 2.05 already admitted static opacity, opacity keys, static and animated transform2d, video dissolve, and static crop/colorBasic on the canonical crop → transform → color → opacity → dissolve CPU consumer. Local admission and definition fingerprint previously refused any `requiredFeatures` and any sequence-owned effect, so a legal luma Effect could not persist or close a definition. Unsupported backends must not silently fall back to dissolve.

## Decision

Add `SetLumaWipe` and `RemoveLumaWipe` as official persist commands (specialized, like SetDissolve), writing Effect.type `studio.fx/lumaWipe` with owner.kind sequence and the closed s8f params: sequenceId, trackId, leftClipId, rightClipId, cut, before, after, softness∈[0.001,0.5], invert, and `maskMode=incomingLuma`. Do not add effectIds to closed Sequence. Do not add a Transition.kind. `requiredFeatures` includes `studio.craft.luma-wipe.v1` if and only if a luma effect exists.

Topology: before+after>0, cut equals the adjacent clip boundary, and the pair is on the same track with no gap. Sources are virtually sampled in `[cut-before, cut+after)` with the admitted Transition handles formula; ordinary Clip ranges are not widened to manufacture overlap. Over-source is `HANDLE_UNAVAILABLE` with no freeze fallback. Same-track same-window occupancy with a core Transition or another pair operator is `TRANSITION_WINDOW_CONFLICT`; a replace after `RemoveDissolve` is allowed and must not double-mix the pair. Affected track and clip locks are checked even though owner is sequence. Closed Sequence topology edits (Split/Trim/Move/Roll/Slide) that would break a luma pair stay refused (`TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL`); Slip revalidates handles.

The formula follows s8f: progress p, m=dot(B.linearRGB, rec709 luma), optional invert, threshold/softness, and linear-rec709 premultiplied blend; p=0 is all A and p=1 is all B. Dart compiles `lumaWipe` recipes (per-frame progress, softness, invert) and never emits `mixFramesQ16` for luma. The Linux CPU backend capability `lumaWipeCpuV1` consumes that recipe and reuses the admitted two-leg dissolve linear buffers. If the CPU golden path is not enabled, that backend stays `enabled=false` and returns `UNSUPPORTED_EDIT_TECHNIQUE`. GPU/Web stay disabled. Unsupported backends are read-only / block render and must not fall back to dissolve. Audio does not automatically fade with luma. InversePatch kind stays `restoreSnapshot`. `assetLuma`, `assetAlpha`, and `maskWipe` stay refused; a video matte is `MASK_MEDIA_UNSUPPORTED`.

## Consequences

I-008 remains partial. Leftover remainingAcceptance items stay listed. No RenderGraph or GPU FrameLease was required. `TRANSFORM_ANIMATION_NOT_IMPLEMENTED` is not retargeted. Production algebra of opacity, gain, transform keyframes, and dissolve is unchanged except that shared admission, fingerprint, and timeline compile now recognize this one admitted sequence-owned luma effect, and luma windows occupy the same exclusive pair slot as dissolve. The shared workbench native peer library is not replaced by this slice; the new out-of-tree `.so` is reported for later verification and install.

## Evidence

`docs/implementation/evidence/luma-wipe/`.
