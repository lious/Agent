# ADR 0113 — Portable local-agent contracts, I-049/I-050 interface gates, and limited play LAN protocol

## Status

Accepted for Increment 2.14 as a Linux/Web-exercisable slice against all four planning documents: the Studio 87-task engineering spec, the play-mode design, the art/design plan, and the independent iOS local-LLM Agent scheme. I-030, I-031, I-042, I-049, and I-050 move from planned to partial. `fullTaskComplete` stays false for each of them and for the overall program. This is not iOS device qualification, not real on-device or TTS/clone inference, not two-physical-device LAN E2E, and not I-016.

## Decision

The first four-document increment starts with portable interfaces that this Linux host can test, then continues under t154u cadence.

`packages/studio_agent` lands the N0 inventory table and the N1/N3 portable contracts for the iOS local-LLM Agent scheme: `ModelPackRegistry`, `LlmRuntimeAdapter`, `FakeLlmRuntime`, fail-closed `LlamaCppRuntimeAdapter` and `CloudTextAdapter`, `StreamAssembler`, `ContextBuilder`, `PlanValidator`, restricted `ToolRegistry`, `MessageLog`, `AgentJournal`, `BudgetController`, and `AgentHarness`. Untrusted prompt text is fenced and cannot register or execute shell, free network, payment, or delete tools. A missing pack leaves the agent unavailable; manual tools remain callable. Private reasoning is not journaled. No GGUF pack is downloaded. N2/N4/N5/N6 remain planned.

`packages/studio_voice` lands I-049/I-050 interface gates from the engineering spec and the art/design plan: `DialoguePlan`, `PhonemeLexicon`, `SpeechJob` with 24 kHz splice and deterministic `FakeSpeechBackend`, caption/clip locks, tempo-dependent invalidation, and a `VoiceConsentLedger` / sealed `VoiceStore` / fail-closed `FakeCloneBackend`. Real-person clone is allowed only with consent; third-party impersonation without consent is refused; this is not a blanket ban on real-person voices. `CharacterRepository.dispatch(voiceClone)` is unchanged and still returns `FEATURE_NOT_IMPLEMENTED`.

`packages/studio_play` addendum v1.9.3 lands a limited LAN protocol for two logical peers in one process (`LoopbackPlayLanFabric`). Permission, scope, sequence, and hash checks are officialized. Physical two-device E2E is explicitly unclaimed. `studio_store` schema remains capped at v9; schema v10 is not merged.

## Consequences

87-task counts become 0 complete / 32 partial / 42 planned / 13 blocked. `fullTasksCompleted` stays 0. T-4 / the overall program is not marked done. Official new suite: 40 tests. Analyzer exit code 0 on the touched packages.

C.1–C.3, A.1, M.1–M.3, K.1–K.3, and Increments 1.83–2.13 evidence hashes are not modified. The frozen native library is not touched. Core project `user_version` stays 9; library workspace stays 6.

## Evidence

`docs/implementation/evidence/agent-voice-lan-interfaces/`.

## Follow-up

Continue increment-by-increment on this Linux/Web host: remaining I-026 templates and workbench visual language, further I-008 registry/effects work that does not need a device, remaining I-031 steer/queue/timeout, I-049 automatic sentence split, I-050 encryption and CharacterRepository wiring, additional play-protocol software tests, and other planned interface work. Do not claim real-device, real-inference, paid-API, or store-release acceptance. Do not merge to main.
