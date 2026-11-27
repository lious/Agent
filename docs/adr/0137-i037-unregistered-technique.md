# ADR 0137 — Official I-037 unregistered craft techniques are explicitly refused

## Status

Accepted for Increment 2.38 as the first I-037 slice. I-037 moves from planned to partial. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. This is a DEV-PURE SkillPackage / CraftSkillCompiler bound in `packages/studio_assets/lib/craft`. It does not invent a new I-008 effect plugin, does not rewrite `i008_unsupported_edit_technique_test.dart`, and does not rewrite the two frozen I-036 `fts5Enabled==false` assertions. J/L-cut command goldens, `SOFT_CAMERA_CONTROL`, and external-skill privilege escalation stay unopened. Project `user_version` stays 9. Workspace SQLite w5 is not merged. InversePatch kind stays `restoreSnapshot`.

## Decision

I-037 acceptance is “未注册技法显式拒；J/L cut/handles命令golden；SOFT_CAMERA_CONTROL告警；外部技能不能提权/绕审批.” Spec s8f says FilmSkillAsset is a content type of the existing Harness SkillPackage, EffectRegistry is the only operator catalog, `RegistryBridge.resolve(pluginType, pluginVersion, backend)` returns an operator or unsupported, an unregistered or disabled plugin is `UNSUPPORTED_EDIT_TECHNIQUE` even if a skill names it, a new skill cannot register unreviewed Shader / FFmpeg filter strings, and an unsupported technique must not silently fall back to dissolve.

This increment officializes only “未注册技法显式拒” at that already-specified bound:

- `RegistryBridge` consults the already-admitted I-008 catalog. `studio.fx/lumaWipe@1.0.0` on `cpu` resolves as enabled. The same plugin on `web` / `gpu`, `studio.fx/maskWipe`, and an unknown plugin are `UNSUPPORTED_EDIT_TECHNIQUE`. `maskWipe` is not added to EffectRegistry.
- `CraftSkillCompiler.compile` refuses those unsupported requests, refuses a skill that carries shader source or an FFmpeg filter string, and does not emit a dissolve fallback or write a project document. A registered lumaWipe cpu skill compiles to a `CraftProposal` value only (`documentWrites` stays 0).

This increment adds:

- `packages/studio_assets/lib/craft/registry_bridge.dart`
- `packages/studio_assets/lib/craft/skill_compiler.dart`
- `packages/studio_assets/test/skills/compile_safety/i037_unregistered_technique_test.dart` (3)

The frozen I-008 unsupported-technique suite (3) was re-run, not rewritten. The frozen I-036 `fts5Enabled==false` assertions were not edited; their hosting suites were re-run and passed.

## Consequences

I-037 is partial. The leftover remainingAcceptance is “J/L cut/handles命令golden；SOFT_CAMERA_CONTROL告警；外部技能不能提权/绕审批。” 87-task counts become 0 complete / 40 partial / 34 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i037-unregistered-technique/`.

## Follow-up

Do not invent a new I-008 plugin. Next honest Linux/Web increment: leftover I-037 “J/L cut/handles命令golden” only if it can be compiled to already-admitted unlink / trim / move commands, without inventing a TrimPlanner or new trim modes. Do not start bus Effect, limiter, or I-007 PCM remapping unless a narrowly specified interface already exists; do not open video muted/solo, invent PatchGroup cherry-pick or a chat workbench UI, or merge workspace SQLite w5. Do not re-qualify I-025 or I-012 leftovers already closed by ADR 0104 / ADR 0098.
