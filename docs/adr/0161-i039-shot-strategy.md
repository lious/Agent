# ADR 0161 — Official I-039 animatic duration, invalidation, and no fake TTS

## Status

Accepted for Increment 2.62 as the first I-039 slice. I-039 moves planned → partial and is not marked complete. The V-020=narrative-qa gate is not met and is not claimed. This increment does not invent a WorkflowCoordinator, a real TTS engine, or paid generation. It does not start quote/apply or SQL `vertical.v1`. It does not invent IntentReducer or DependencyIndex as a product surface, and it is not a rewrite of I-038 Prompt / PlayRecipe compilers or `change_dependency` tests. I-035 stays planned. I-052, I-040, I-033, I-057, I-037, I-056, I-054 default-diagnostic exclusions, and I-029 DeletionBarrier are not re-qualified. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-055 is not started. I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, and I-052 stay partial and are not marked complete. V-009, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called.

## Decision

s8x defines an official 15-second, 24 fps, 48 kHz, 9:16 four-shot animatic: S1 `[0,72)` (3 s, 2D pan, not 2.5D), S2 `[72,168)` (4 s, VO fixture 105600/48000=2.2 s), S3 `[168,264)` (4 s, i2v_micro), S4 `[264,360)` (4 s), totaling 360 frames. s8v requires that `layered_2_5d` is claimed only when mask/depth-or-planes, occluded-background fill, and a registered layered renderer are present; missing assets are `BLOCKED_LAYER_ASSETS` and may be replaced by a user-confirmed 2D fallback, not disguised as 2.5D or silently paid-inpainted. An i2v_micro shot may propose a still substitute but must not silently degrade. Unselected TTS must not invent a voice-over: the preview is labeled `未配音预演`, and a silent preview is not a voiced approval. Dialogue that does not fit the shot is not sped up. Native fps is resampled by PTS; changing fps to stretch duration is refused. Changing the lead or a line of dialogue invalidates only dependents; deleting a shot unplaces it and does not delete the source or withdraw a paid job. A later library character edition does not replace a frozen pin. Unconfirmed preview does not spend expensive generation.

This increment officializes that bound as a DEV-PURE compiler in `packages/studio_vertical/lib/shot_strategy.dart`, exported alongside the existing I-038 surfaces (which are not rewritten):

- `AnimaticBuilder.build(officialFifteenSecondShots())` yields 360 frames / 15 s with the official half-open ranges. S1 is `panZoom2d` and is not claimed as 2.5D. Compile does not submit or start paid generation.
- `invalidate(..., newLeadId: qinghe)` stales only S2 and S3. Removing S4 and targeting 12 s (288 frames) proposes a last-frame hold, keeps fps unchanged, and does not delete the source or withdraw a paid job. Changing S2 dialogue stales only S2. A library upgrade to v4 leaves the frozen v3 pin in place. Locked captions are kept.
- Missing 2.5D assets produce a fallback proposal and `forceClaim25d` is `BLOCKED_LAYER_ASSETS`. Silent degrade of i2v_micro is `STRATEGY_PREREQUISITE_MISSING`. With no TTS or recording selected, the label is `未配音预演` and treating the silent preview as voiced approval is `ANIMATIC_APPROVAL_STALE`. Dialogue overflow is `DIALOGUE_OVERFLOW`. Speeding up or changing fps to fit is `FRAME_CONSTRAINT_UNSUPPORTED`. `ttsEngineInvented`, `workflowCoordinatorInvented`, and `v020NarrativeQaClaimed` stay false.

A director workbench, real TTS/recording probe, and paid generation dispatch remain unopened.

## Consequences

The first I-039 leftover acceptance items (the 15-second four-shot total is exact, changing the lead or deleting a shot invalidates only dependents, missing 2.5D assets are explicitly degraded, and unselected TTS does not invent a voice-over) are officialized at this AnimaticBuilder bound. The V-020=narrative-qa gate, a director workbench, and real TTS remain unopened, so I-039 stays partial and is not marked complete. 87-task counts become 0 complete / 53 partial / 21 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i039-shot-strategy/`.

## Follow-up

Next honest Linux/Web increment: prefer a narrowly specified V-026 untrusted-resource refusal (no automatic external URL fetch, unsupported extensions refused, damaged input does not escape) if it does not invent a glTF runtime or claim preview consistency. Otherwise pick the next still-doable planned or remaining-partial work from the four planning documents. Do not start I-055 unless a narrow already-specified LocaleCatalog/semantics slice is required. Do not start I-035 or claim a V-020 precision/recall or narrative-qa achievement. Do not invent a limiter, a WorkflowCoordinator, a real TTS engine, or paid generation. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not re-qualify I-039, I-038, I-052, I-040, or I-033 leftovers. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, or I-039 complete.
