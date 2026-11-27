# ADR 0119 — I-050 embedding encryption and CharacterRepository wiring

## Status

Accepted for Increment 2.20 as the remaining Linux/Web-exercisable I-050 leftover after Increment 2.14. I-050 stays partial. `fullTaskComplete` stays false. Real clone inference is not claimed.

## Decision

`VoiceStore` encrypts embeddings at rest with `EmbeddingCipher` (HMAC-SHA256 keystream and MAC, 32-byte key, 16-byte nonce). `putEmbedding` stores ciphertext; `readSealed` returns plaintext; archive and log exports still carry only ids and traces. A wrong key fails as `EMBEDDING_MAC_MISMATCH`. The default `VoiceStore()` uses an ephemeral key, so the frozen 2.14 leak suite stays valid. This is not a hardware HSM.

`CharacterRepository.dispatch(operation: 'voiceClone')` is no longer `FEATURE_NOT_IMPLEMENTED`. `requestVoiceClone` loads the published pack, refuses a revoked portrait (`RIGHTS_REVOKED`), requires `cloningAllowed` and a voice-rights record that includes `voiceClone` (`RIGHTS_REQUIRED` otherwise), then runs `CloneJob` against the injected `VoiceConsentLedger` / `VoiceStore` / `CloneBackend` (default `FakeCloneBackend`). Missing consent is `CONSENT_REQUIRED`. The fail-closed backend throws `CLONE_INFERENCE_UNAVAILABLE`, does not increment successful executions, and does not write an embedding. An approval or pack flag is not a permission grant.

`studio_assets` depends on `studio_voice` for this wiring. The core project store `user_version` stays 9. Library workspace stays 6.

## Consequences

87-task counts stay 0 complete / 35 partial / 39 planned / 13 blocked. `fullTasksCompleted` stays 0. Official new suites: 6 tests. Frozen studio_voice suites re-run. Analyzer exit 0.

Two frozen I-036 `fts5Enabled == false` assertions already fail at Increment 2.19 (80caa6f) on this host because the linked SQLite reports FTS5 enabled. Those tests were not rewritten.

## Evidence

`docs/implementation/evidence/i050-encryption-wiring/`.

## Follow-up

Real clone inference remains unavailable; no model packs are downloaded. Next honest Linux/Web increments include I-026 template UI / graphics-library store, remaining art/workbench visual language, and further play-protocol software tests without physical two-device E2E or schema v10 / XD-010 claims.
