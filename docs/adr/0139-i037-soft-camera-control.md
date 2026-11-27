# ADR 0139 — Official I-037 SOFT_CAMERA_CONTROL for camera.dollyZoom promptSuggestion

## Status

Accepted for Increment 2.40 as a leftover I-037 remainingAcceptance slice of “SOFT_CAMERA_CONTROL告警”. I-037 stays partial. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. This slice compiles already-specified camera_craft to a soft `promptSuggestion` only. Hard physical camera control and a new I-008 effect plugin are not invented. Digital zoom is not emitted as a stand-in for a real dolly zoom. External-skill privilege escalation stays unopened. Project `user_version` stays 9. Workspace SQLite w5 is not merged. Frozen I-036 `fts5Enabled==false` assertions are not rewritten.

## Decision

s8f camera_craft says the same camera name is not a unified physical API; Wan focal length and camera moves remain `promptSuggestion`; required hard physical control without capability is `CAPABILITY_UNSATISFIED`. The example `camera.dollyZoom@1.0.0` compiles to the single-shot suggestion “相机后移同时收紧视角，主体占画面比例尽量稳定，背景空间感变化” and surfaces `SOFT_CAMERA_CONTROL`. A later digital zoom cannot pretend to be a real dolly zoom.

This increment officializes that bound:

- `CraftSkillCompiler.compileCameraCraft` admits `camera.dollyZoom@1.0.0` when the selected provider mapping is `promptSuggestion`.
- The proposal carries a `shotDesignPatchGroups` promptSuggestion, `softWarnings` includes `SOFT_CAMERA_CONTROL`, `editPatchGroups` and `commands` stay empty, and `documentWrites` stays 0.
- A required `api` / `nle` / `unsupported` mapping without physical camera capability is `CAPABILITY_UNSATISFIED`. A missing provider mapping is the same refusal. The compiler does not invent a physical camera operator or fall back to transform2d / digital zoom.

This increment adds:

- `compileCameraCraft` / `CameraCraftRequest` / `CameraSkillMapping` in `packages/studio_assets/lib/craft/skill_compiler.dart`
- `packages/studio_assets/test/skills/compile_safety/i037_soft_camera_control_test.dart` (3)

The Increment 2.38 unregistered-technique suite (3) and Increment 2.39 J/L-cut suite (3) were re-run, not rewritten.

## Consequences

The I-037 remainingAcceptance item “SOFT_CAMERA_CONTROL告警” is cleared at this already-specified promptSuggestion bound. Leftover remainingAcceptance is “外部技能不能提权/绕审批。” 87-task counts stay 0 complete / 40 partial / 34 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i037-soft-camera-control/`.

## Follow-up

Next honest Linux/Web increment: leftover I-037 “外部技能不能提权/绕审批” only if that bound is already specified as a clean slice, without inventing an executable-script privilege path. Do not start bus Effect, limiter, or I-007 PCM remapping unless a narrowly specified interface already exists; do not invent a TrimPlanner, open video muted/solo, invent PatchGroup cherry-pick or a chat workbench UI, or merge workspace SQLite w5. Do not re-qualify I-025 or I-012 leftovers already closed by ADR 0104 / ADR 0098.
