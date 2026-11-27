# Increment 2.20 — I-050 embedding encryption and CharacterRepository wiring

Official suites: 3 tests in packages/studio_voice/test/i050_embedding_encryption_test.dart and 3 tests in packages/studio_assets/test/assets/character_versions/i050_character_voice_wiring_test.dart. Frozen 2.14/2.17 studio_voice suites were re-run (14 tests including the new 3). Analyzer exit 0 on studio_voice and studio_assets.

Embeddings are sealed at rest with a hash-based keystream plus HMAC-SHA256. CharacterRepository.requestVoiceClone / dispatch(voiceClone) checks pack cloningAllowed, voice rights, and VoiceConsentLedger, then the fail-closed FakeCloneBackend. Real clone inference is not claimed (CLONE_INFERENCE_UNAVAILABLE). Successful execution counts stay 0 on that failure. This is not a permission grant and not an HSM.

Two frozen I-036 assertions that `fts5Enabled` is false already fail at the Increment 2.19 tip (80caa6f) on this host; they were not rewritten and are not a 2.20 regression.
