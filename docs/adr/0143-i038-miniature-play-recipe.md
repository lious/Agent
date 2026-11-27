# ADR 0143 — Official I-038 miniature@1.0.0 PlayRecipe slot and scale refusals

## Status

Accepted for Increment 2.44 as a leftover I-038 PlayRecipe slice of the already-specified s8l `miniature@1.0.0` slot/scale bound. I-038 stays partial. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. I-037 is not marked complete. Auto-segmentation, geometric calibration, and paid generation are not invented. `animalHumanized` and `babyDance` library entries stay unopened. Signed-pack import, production FTS/RAG, SQL `vertical.v1`, workspace SQLite w5, and quote/apply stay unopened. A PlanGraph manual-lock API is not invented; `PLAN_CYCLE` is not re-qualified.

## Decision

s8l says `miniature@1.0.0` requires one subject reference, one reference-object or scene image (the same image is allowed only with explicit regions), a relative scale intent in `0.005..0.2`, plus stance/contact, action, and duration. The default 1:20 example is a creative soft constraint, not real geometric calibration. Precise pixel scale can be verified only when layered assets are provided and deterministic compositing is used. Auto-segmentation is not invented. A user may lock stance and a hand mask. Without layered assets, precise occlusion is not promised and an artistic-fantasy compile is allowed. A marketing use must not exaggerate actual product size or function.

This increment officializes that bound in `packages/studio_vertical/lib/play_recipe.dart`:

- `PlayRecipeCompiler.compileMiniature` admits the official 1:20 contact golden on the I2V route. `scaleClaimsGeometricCalibration` stays false. Locked stance and hand mask are preserved. Compile does not submit.
- Missing subject or reference, a same image without explicit regions, and a scale outside `0.005..0.2` are `SLOT_COUNT`.
- Requested auto-segmentation, geometric calibration, precise scale without layered deterministic compositing, precise occlusion without layered assets, and actual product-size claims are `CAPABILITY_UNSUPPORTED`.

This increment adds:

- `compileMiniature` / `MiniatureRequest` in `packages/studio_vertical/lib/play_recipe.dart`
- `packages/studio_vertical/test/vertical/all_scenarios/i038_miniature_play_recipe_test.dart` (3)

The Increment 2.42 fixture suite (3) and Increment 2.43 hug suite (3) were re-run, not rewritten.

## Consequences

The leftover I-038 remainingScope item for the `miniature@1.0.0` slot/scale bound is officialized. `animalHumanized` / `babyDance`, WorkflowCoordinator quote/apply, SQL `vertical.v1`, paid generation, and full s8m prompt layering remain unopened. I-038 stays partial. 87-task counts stay 0 complete / 41 partial / 33 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i038-miniature-play-recipe/`.

## Follow-up

Next honest Linux/Web increment: a narrowly specified leftover I-038 PlayRecipe bound (`animalHumanized@1.0.0` slot/identity refusals, for example) only if that slice is already specified and does not invent motion capture, geometric calibration, auto-segmentation, or paid generation. Otherwise pick the next still-doable planned or remaining-partial work from the four planning documents. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037 complete. Do not start signed-pack import, claim production FTS/RAG, merge SQL `vertical.v1` or workspace SQLite w5, or start quote/apply.
