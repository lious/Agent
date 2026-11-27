# ADR 0140 — Official I-037 external skills cannot escalate privileges or bypass approval

## Status

Accepted for Increment 2.41 as a leftover I-037 remainingAcceptance slice of “外部技能不能提权/绕审批”. I-037 stays partial. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. This slice officializes the already-specified s8f import/execute privilege and approval bound only. An executable-script privilege path is not invented. Signed package trust-chain import and production FTS/RAG stay unopened. No new I-008 effect plugin is added. Hard physical camera control is not invented. Project `user_version` stays 9. Workspace SQLite w5 is not merged. Frozen I-036 `fts5Enabled==false` assertions are not rewritten.

## Decision

s8f says FilmSkillAsset is a content type of the existing Harness SkillPackage and must not become an arbitrary-script plugin system. Import may preview an unsigned pack as untrusted knowledge; execution still requires confirmation and cannot add tool privileges. Import refuses shell, dynamic code, remote `$ref`, arbitrary network URL tools, shader source, and model-install steps. A DAG is at most 16 steps and must not cycle. Execute requires `requiredTools ⊆ installedAllowlist ∩ sessionGrant ∩ branchScope`. Every step still passes the existing gates; a skill signature is not user approval.

This increment officializes that bound:

- `CraftSkillCompiler.previewExternalSkill` admits a knowledge preview. Unsigned packs are untrusted. Preview `addedTools` stays empty and `documentWrites` stays 0. Required approval remains listed.
- `compileExternalSkill` refuses execution unless `userConfirmed` is true. A signature or a `claimedApproved` flag does not satisfy that requirement (`APPROVAL_REQUIRED`).
- A required tool outside the grant intersection is `TOOL_NOT_ALLOWED` and does not enlarge the grant. Forbidden payloads are `UNSUPPORTED_EDIT_TECHNIQUE`. A DAG longer than 16 steps or a cycle is `PLAN_INVALID`.

This increment adds:

- `packages/studio_assets/lib/craft/skill_privilege.dart`
- `previewExternalSkill` / `compileExternalSkill` on `CraftSkillCompiler`
- `packages/studio_assets/test/skills/compile_safety/i037_external_skill_privilege_test.dart` (3)

The Increment 2.38 unregistered-technique (3), 2.39 J/L-cut (3), and 2.40 SOFT_CAMERA_CONTROL (3) suites were re-run, not rewritten.

## Consequences

The four official I-037 remainingAcceptance clauses are now officialized at already-specified bounds. Leftover remainingScope is signed-pack import and FTS recall, which stay unopened. I-037 is not marked complete. 87-task counts stay 0 complete / 40 partial / 34 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i037-external-skill-privilege/`.

## Follow-up

Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial work from the four planning documents. Do not start signed-pack import or claim production FTS/RAG. Do not invent an executable-script privilege path, hard physical camera control, or a new I-008 plugin. Do not start bus Effect, limiter, or I-007 PCM remapping unless a narrowly specified interface already exists; do not invent a TrimPlanner, open video muted/solo, invent PatchGroup cherry-pick or a chat workbench UI, or merge workspace SQLite w5. Do not re-qualify I-025 or I-012 leftovers already closed by ADR 0104 / ADR 0098.
