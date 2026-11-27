# ADR 0166 — Official I-047 stem / denoise lock and no-auto-accept protocol

## Status

Accepted for Increment 2.67 as the first I-047 slice. I-047 moves planned → partial and is not marked complete. The V-010=audio-restore gate is not met and is not claimed; V-010 stays blocked. This increment does not invent a real RNNoise or stem-separation engine, a limiter, or a real ASR engine. V-009 is not claimed. I-046 leftovers are not re-qualified and I-046 official tests are not rewritten. I-045, I-044, and I-043 leftovers are not re-qualified. I-061 stays planned; V-026=gltf-preview and preview consistency are not claimed. I-039 and I-038 leftovers are not re-qualified. I-035 stays planned. I-055 is not started. I-048 is not started. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, and I-045 stay partial and are not marked complete. V-009, V-012, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. Optical-flow and V-003 stay unclaimed.

## Decision

s8r requires that stem and denoise outputs are derived `AudioCandidate` assets with provenance. The original audio stays independent and is never overwritten. Four-stem labels are drums/bass/other/vocals under a shared gain policy; residual energy is reported and is not guaranteed to be zero. OLA admits only present chunks with non-zero boundary weights; missing chunks, NaN, or clip are errors and are not silently padded with silence; a crossfade must not become a shorter file; latency must not be double-compensated. A DenoiseState is a sustained lease, not recreated every frame, and is released on cancel. Changing a preprocess candidate invalidates the ASR cache key but must not rewrite locked captions. Vocal separation is not speaker separation and is not denoise. Insufficient local resources only pause or downgrade the proposal; the original remains editable. V-010 reconstruction / clip / delay qualification is a gate, not a default accept.

This increment officializes that bound as a DEV-PURE compiler in `packages/studio_audio_tools/lib/restore/audio_candidate.dart`, exported alongside the existing I-046 TranscriptionJob (which is not rewritten):

- `preview` emits official stem labels with residual reported and not claimed zero, keeps the original hash, does not overwrite the original, and does not auto-accept. Insufficient resources pause the proposal; `downgradeProposal` likewise leaves the original editable. Per-stem peak-normalize, residual-is-zero claims, treating separation as denoise or speaker split, and overwriting the original are `UNSUPPORTED_EDIT_TECHNIQUE`.
- 100 `cancel` calls each release a `DenoiseStateLease`. `liveStates` returns to 0. Using a released state is `STATE_RELEASED`. Recreating state every frame is `UNSUPPORTED_EDIT_TECHNIQUE`. Late cancel does not attach a candidate to the timeline or overwrite the original.
- `changePreprocess` invalidates the ASR cache and leaves locked caption text unchanged. Overwriting a locked caption is `FIELD_LOCKED`. `autoAcceptRestore` without `v010Met` is `V010_GATE_UNMET`. A missing qualified pack is `MODEL_ABI_UNVERIFIED`. Treating VAD as word-level confidence is `UNSUPPORTED_EDIT_TECHNIQUE`.
- `admitOla` refuses a shorter output (`CROSSFADE_SHORTENS`), a missing chunk (`OLA_CHUNK_MISSING`), NaN (`OLA_NAN_OUTPUT`), clip (`OLA_CLIP`), a zero boundary weight (`OLA_ZERO_BOUNDARY_WEIGHT`), and double latency compensation (`DOUBLE_LATENCY_COMPENSATION`). `rnnoiseEngineInvented`, `stemEngineInvented`, `v010Claimed`, `v009Claimed`, and `limiterInvented` stay false.

A real RNNoise / DeepFilterNet3 / htdemucs runtime, V-010 qualification, and automatic NLE attach remain unopened.

## Consequences

The first I-047 leftover acceptance items (100 cancels release State; changing preprocess invalidates the ASR cache but does not change locked captions; reconstruction / clip / delay must not auto-accept unless V-010 is met) are officialized at this AudioRestoreSession bound. The V-010=audio-restore gate and a real RNNoise or stem-separation engine remain unopened, so I-047 stays partial and is not marked complete. 87-task counts become 0 complete / 58 partial / 16 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i047-stem-denoise-lock/`.

## Follow-up

Next honest Linux/Web increment: prefer a narrowly specified I-048 upscale / denoise lock protocol if it is already written and does not invent a real SR/denoise runtime, does not claim V-013, and does not auto-apply failed frames or treat generated detail as fact. Otherwise pick the next still-doable planned or remaining-partial work from the four planning documents. Do not start I-061 or claim V-026=gltf-preview. Do not start I-055 unless a narrow already-specified LocaleCatalog/semantics slice is required. Do not start I-035 or claim a V-020 precision/recall achievement. Do not invent a limiter, a real RNNoise or stem engine, a temporal inpaint engine, a real tracker, or auto-segmentation. Do not claim V-010, V-011, V-012, or V-013. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not re-qualify I-047, I-046, I-045, I-044, or I-043 leftovers. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, or I-047 complete.
