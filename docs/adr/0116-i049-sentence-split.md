# ADR 0116 — I-049 automatic sentence split

## Status

Accepted for Increment 2.17 as the next official I-049 slice after Increment 2.14. I-049 remains partial. `fullTaskComplete` stays false. This is not real TTS inference.

## Decision

`packages/studio_voice` adds `SentenceSplitter`, a rule-based splitter for Latin `.!?` and CJK `。！？` (and newlines) that builds a timed `DialoguePlan`. Durations scale with speed and have a minimum of 80 ms. Sentence ids are a stable function of index and text, so an unchanged earlier sentence keeps its id across a re-split and a rewritten sentence gets a new id. Empty text and non-positive speed are refused as `SENTENCE_INVALID`. The resulting plan splices through the existing `FakeSpeechBackend` at 24 kHz with sample counts equal to the planned sum.

This is not a linguistic parser, not abbreviation-aware NLP, and not a speech model. The frozen 2.14 I-049 / I-050 suites are not rewritten.

## Consequences

I-049 remainingScope is narrowed: automatic sentence split is now officialized alongside the 2.14 pre-split plan, phonemes, 24 kHz splice, locks, and resample. Real TTS inference and CharacterRepository wiring remain open, so I-049 stays partial. Counts stay 0 complete / 33 partial / 41 planned / 13 blocked. Official new suite: 4 tests. Analyzer exit 0.

## Evidence

`docs/implementation/evidence/i049-sentence-split/`.

## Follow-up

Next honest Linux/Web increments include I-028 / I-033 interface ports, I-026 graphics-library store, I-050 encryption and CharacterRepository wiring (clone inference stays unavailable), and further play-protocol software tests without physical two-device E2E.
