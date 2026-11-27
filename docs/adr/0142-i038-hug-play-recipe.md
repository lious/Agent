# ADR 0142 — Official I-038 hug@1.0.0 PlayRecipe slot and route refusals

## Status

Accepted for Increment 2.43 as a leftover I-038 PlayRecipe slice of the already-specified s8l `hug@1.0.0` slot/route bound. I-038 stays partial. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. I-037 is not marked complete. Auto-segmentation and paid generation are not invented. `miniature`, `animalHumanized`, and `babyDance` library entries stay unopened. Signed-pack import, production FTS/RAG, SQL `vertical.v1`, and workspace SQLite w5 stay unopened. A PlanGraph manual-lock API is not invented; `PLAN_CYCLE` is not re-qualified.

## Decision

s8l says `hug@1.0.0` has three variants: `onePersonImaginedPartner` (one authorized single image plus an explicitly chosen fictional partner), `twoPeoplePhoto` (one photo of two already-authorized people, I2V), and `twoImages` (two single-person references, R2V). `leftSubjectId` / `rightSubjectId` are stable and are not reordered by filename. An R2V single dual-person still cannot pretend to be a single-subject pair. A lone image cannot use the two-images template and invent a second photo; the form must name a fictional partner and change the route. Portrait scope is confirmed per person. A single-person image cannot be auto-paired with a real stranger. Matting, if needed, is a user mask or an already-registered ImageEditor — auto-segmentation is not invented. A minor still requires a verified provider child policy (`PROVIDER_CHILD_POLICY_UNVERIFIED`). The compiled shot carries the disclosure “AI合成互动，不表示人物真实相遇”. A locked disclaimer is not overwritten. Compile does not submit.

This increment officializes that bound in `packages/studio_vertical/lib/play_recipe.dart`:

- `PlayRecipeCompiler.compileHug` admits the official two-images golden for 岚 and 禾 on the R2V route.
- A missing second image on `twoImages` is `SLOT_COUNT`. Switching to `onePersonImaginedPartner` with an explicit fictional partner changes the route and does not pretend a second photo exists.
- Missing portrait consent is `PORTRAIT_CONSENT_REQUIRED`. Auto-pairing a real stranger, or a dual-person still used as a single-subject pair, is `MEDIA_COMBINATION`. Requested auto-segmentation is `CAPABILITY_UNSUPPORTED`. An unverified child policy is `PROVIDER_CHILD_POLICY_UNVERIFIED`.

This increment adds:

- `packages/studio_vertical/lib/play_recipe.dart`
- `packages/studio_vertical/test/vertical/all_scenarios/i038_hug_play_recipe_test.dart` (3)

The Increment 2.42 fixture suite (3) was re-run, not rewritten.

## Consequences

The leftover I-038 remainingScope item for the `hug@1.0.0` slot/route bound is officialized. `miniature` / `animalHumanized` / `babyDance`, WorkflowCoordinator quote/apply, SQL `vertical.v1`, paid generation, and full s8m prompt layering remain unopened. I-038 stays partial. 87-task counts stay 0 complete / 41 partial / 33 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i038-hug-play-recipe/`.

## Follow-up

Next honest Linux/Web increment: a narrowly specified leftover I-038 PlayRecipe bound (`miniature@1.0.0` slot/scale refusals, for example) only if that slice is already specified and does not invent auto-segmentation, geometric calibration, or paid generation. Otherwise pick the next still-doable planned or remaining-partial work from the four planning documents. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037 complete. Do not start signed-pack import, claim production FTS/RAG, merge SQL `vertical.v1` or workspace SQLite w5, or start quote/apply.
