# ADR 0145 — Official I-038 babyDance@1.0.0 PlayRecipe safety and guardian refusals

## Status

Accepted for Increment 2.46 as a leftover I-038 PlayRecipe slice of the already-specified s8l `babyDance@1.0.0` safety and guardian refusal bound only. I-038 stays partial. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. I-037 is not marked complete. Motion capture, adult-motion retargeting, auto-segmentation, and paid generation are not invented. No new child-related surface, imagery, or motion path beyond s8l is invented. Signed-pack import, production FTS/RAG, SQL `vertical.v1`, workspace SQLite w5, and quote/apply stay unopened. A PlanGraph manual-lock API is not invented; `PLAN_CYCLE` is not re-qualified.

## Decision

s8l says `babyDance@1.0.0` defaults to a fictional clothed cartoon infant. Required slots are one authorized appearance and one of `seatedClap` / `gentleSway` / `smallStep`. A real-child path needs explicit guardian authorization, portrait scope, minimal upload, and a verified provider child policy. Even with a guardian record, an unverified provider child policy is `PROVIDER_CHILD_POLICY_UNVERIFIED` and must not bypass by silently staying on the real-child path. Sexualized actions and adult seductive choreography are refused. Dangerous twists or high jumps may only be reduced to clap or gentle sway, or refused. Adult motion must not be scaled onto an infant. A locked parent caption and private status are not overwritten. Selecting the recipe does not auto-publish to a social platform. Compile does not submit or claim a frame-perfect dance copy.

This increment officializes that bound in `packages/studio_vertical/lib/play_recipe.dart`:

- `PlayRecipeCompiler.compileBabyDance` admits only the official fictional clothed-cartoon safe-sway golden on the I2V route. `autoPublished`, `framePerfectDanceClaimed`, and `adultMotionRetargeted` stay false. Locked parent caption and private status are preserved. Compile does not submit.
- A real-child path without guardian authorization is `RIGHTS_REQUIRED`. A real-child path with guardian but unverified provider policy is `PROVIDER_CHILD_POLICY_UNVERIFIED`. A revoked rights epoch, and missing music or reference-motion licenses, are `RIGHTS_REQUIRED`. Missing appearance or action is `SLOT_COUNT`.
- Adult-motion retargeting, motion capture, a frame-perfect dance claim, and auto-segmentation are `CAPABILITY_UNSUPPORTED`. Sexualized or adult seductive choreography, and incomplete clothing, are `MEDIA_COMBINATION`. Requested auto-publish is `APPROVAL_REQUIRED`. A dangerous jump is reduced to `gentleSway`.

This increment adds:

- `compileBabyDance` / `BabyDanceRequest` in `packages/studio_vertical/lib/play_recipe.dart`
- `packages/studio_vertical/test/vertical/all_scenarios/i038_baby_dance_play_recipe_test.dart` (3)

The Increment 2.42 fixture (3), 2.43 hug (3), 2.44 miniature (3), and 2.45 animalHumanized (3) suites were re-run, not rewritten.

## Consequences

The leftover I-038 remainingScope item for the `babyDance@1.0.0` safety/guardian bound is officialized. The four s8l PlayRecipe official slot/safety bounds (hug, miniature, animalHumanized, babyDance) are now officialized at compiler/fixture level. WorkflowCoordinator quote/apply, SQL `vertical.v1`, paid generation, and full s8m prompt layering remain unopened. I-038 stays partial. 87-task counts stay 0 complete / 41 partial / 33 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i038-baby-dance-play-recipe/`.

## Follow-up

Next honest Linux/Web increment: a narrowly specified leftover I-038 s8m prompt-layering / override bound only if that slice is already specified and does not start quote/apply, paid generation, or SQL `vertical.v1`. Otherwise pick the next still-doable planned or remaining-partial work from the four planning documents. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037 complete. Do not start signed-pack import or claim production FTS/RAG.
