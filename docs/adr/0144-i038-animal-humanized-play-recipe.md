# ADR 0144 — Official I-038 animalHumanized@1.0.0 PlayRecipe slot and identity refusals

## Status

Accepted for Increment 2.45 as a leftover I-038 PlayRecipe slice of the already-specified s8l `animalHumanized@1.0.0` slot/identity bound. I-038 stays partial. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. I-037 is not marked complete. Motion capture, geometric calibration, auto-segmentation, and paid generation are not invented. A `babyDance` library entry stays unopened. Signed-pack import, production FTS/RAG, SQL `vertical.v1`, workspace SQLite w5, and quote/apply stay unopened. A PlanGraph manual-lock API is not invented; `PLAN_CYCLE` is not re-qualified.

## Decision

s8l says `animalHumanized@1.0.0` requires one animal reference, species and retained features, humanization `clothingOnly` or `uprightCartoon`, wardrobe, and a single safe action. Image copyright is still required when there is no human portrait; a human voice needs a separate authorization. `clothingOnly` does not automatically become an upright human body. `uprightCartoon` may use a cartoon standing pose but must not replace the species face with an adult human face. An animal still plus human motion is not reliable mocap; `motionTransfer` needs a measured body-type/service gate and is not invented here. Complex or dangerous actions may be reduced to a simple fictional action; the compile does not claim the real animal performed it. A locked expression caption is preserved.

This increment officializes that bound in `packages/studio_vertical/lib/play_recipe.dart`:

- `PlayRecipeCompiler.compileAnimalHumanized` admits the official orange-cat `uprightCartoon` identity golden on the I2V route. The species face is not replaced. `claimsReliableMocap` and `claimsRealAnimalActed` stay false. A locked caption is preserved. Compile does not submit.
- Missing animal reference or required slots is `SLOT_COUNT`. Missing image license, or a human voice without separate authorization, is `RIGHTS_REQUIRED`.
- `clothingOnly` forced to an upright body, or an adult human face replacement, is `MEDIA_COMBINATION`. `clothingOnly` compiles stay `clothingOnly`.
- Requested motion transfer, a reliable-mocap claim, and auto-segmentation are `CAPABILITY_UNSUPPORTED`. A dangerous action is downgraded to a simple fictional action.

This increment adds:

- `compileAnimalHumanized` / `AnimalHumanizedRequest` in `packages/studio_vertical/lib/play_recipe.dart`
- `packages/studio_vertical/test/vertical/all_scenarios/i038_animal_humanized_play_recipe_test.dart` (3)

The Increment 2.42 fixture (3), 2.43 hug (3), and 2.44 miniature (3) suites were re-run, not rewritten.

## Consequences

The leftover I-038 remainingScope item for the `animalHumanized@1.0.0` slot/identity bound is officialized. `babyDance`, WorkflowCoordinator quote/apply, SQL `vertical.v1`, paid generation, and full s8m prompt layering remain unopened. I-038 stays partial. 87-task counts stay 0 complete / 41 partial / 33 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i038-animal-humanized-play-recipe/`.

## Follow-up

Next honest Linux/Web increment: a narrowly specified leftover I-038 PlayRecipe bound (`babyDance@1.0.0` safety/guardian refusals, for example) only if that slice is already specified and does not invent motion capture, adult-motion retargeting, auto-segmentation, or paid generation. Otherwise pick the next still-doable planned or remaining-partial work from the four planning documents. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037 complete. Do not start signed-pack import, claim production FTS/RAG, merge SQL `vertical.v1` or workspace SQLite w5, or start quote/apply.
