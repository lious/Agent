# ADR 0138 — Official I-037 J/L cut compiles to admitted unlink and trim commands

## Status

Accepted for Increment 2.39 as a leftover I-037 remainingAcceptance slice of “J/L cut/handles命令golden”. I-037 stays partial. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. This slice compiles to already-admitted `UnlinkAudioVideo` and `TrimClip` only. A TrimPlanner and new trim modes are not invented. `SOFT_CAMERA_CONTROL` and external-skill privilege escalation stay unopened. No new I-008 effect plugin is added. Project `user_version` stays 9. Workspace SQLite w5 is not merged. Frozen I-036 `fts5Enabled==false` assertions are not rewritten.

## Decision

s8f editing_craft says J/L cuts take J/L, `offsetQ`, and left/right AV clips; they compile to an existing unlink + trim/move batch; a short source head is refused; a locked audio track is not modified; inverse references the existing before snapshot so one undo restores the batch; J/L is not stuffed into a video-model prompt.

This increment officializes that bound:

- `CraftSkillCompiler.compileJlCut` plans a packed cut only (`NOT_ADJACENT` otherwise).
- The batch is `UnlinkAudioVideo` for each involved link group, then `TrimClip` on the left audio out-point and right audio in-point with the same signed offset (J negative, L positive). Shortening is applied first so an L-cut does not temporarily overlap on one audio track.
- A J-cut of 0.4s with a 0.2s incoming head is `HANDLE_UNAVAILABLE` and does not invent source media. A locked audio track is `FIELD_LOCKED`. The compiler does not apply the batch (`documentWrites` stays 0). Inverse kind is `restoreSnapshot` of the before document hash.

This increment adds:

- `compileJlCut` / `planJlCut` / `JlCutRequest` in `packages/studio_assets/lib/craft/skill_compiler.dart`
- `packages/studio_assets/test/skills/compile_safety/i037_jl_cut_handles_test.dart` (3)

The Increment 2.38 unregistered-technique suite (3) was re-run, not rewritten.

## Consequences

The I-037 remainingAcceptance item “J/L cut/handles命令golden” is cleared at this already-admitted command bound. Leftover remainingAcceptance is “SOFT_CAMERA_CONTROL告警；外部技能不能提权/绕审批。” 87-task counts stay 0 complete / 40 partial / 34 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i037-jl-cut-handles/`.

## Follow-up

Next honest Linux/Web increment: leftover I-037 “SOFT_CAMERA_CONTROL告警” if that camera-craft / promptSuggestion bound is already specified, without inventing hard physical camera control or a new unregistered I-008 plugin. Do not start bus Effect, limiter, or I-007 PCM remapping unless a narrowly specified interface already exists; do not invent a TrimPlanner, open video muted/solo, invent PatchGroup cherry-pick or a chat workbench UI, or merge workspace SQLite w5. Do not re-qualify I-025 or I-012 leftovers already closed by ADR 0104 / ADR 0098.
