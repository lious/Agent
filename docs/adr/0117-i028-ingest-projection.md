# ADR 0117 — I-028 attachment ingest, analysis artifacts, and evidence projection

## Status

Accepted for Increment 2.18 as the first Linux/Web-exercisable slice of I-028. I-028 moves from planned to partial. `fullTaskComplete` stays false. This is not V-025 multimodal-analysis qualification and not real OCR/ASR/VLM inference.

## Decision

`packages/studio_context` lands the planned entry points: `AttachmentIngestor` (`lib/ingest.dart`), `AnalysisArtifact` / `AnalysisExecutor` / `AnalysisCache`, and `ProjectionCompiler`. Official suite: `test/context/attachments/i028_ingest_projection_test.dart` (6).

Over-limit inputs throw `OVER_LIMIT` and are not stored as a silently truncated complete body. Text attachments that fit are paginated with page and byte locators. `EvidenceUnit` kinds `observation` and `inference` stay separate; an inference must point at input evidence (`INFERENCE_WITHOUT_EVIDENCE` otherwise). Locators carry page, bbox, or PTS and appear in projection citations. The analysis cache key includes blob hash, extractor, parameters, and question; a repeated request is reused and a new question misses. `read` / `analyze` / `uploadSubset` do not imply one another. Upload without `uploadSubset` throws `UPLOAD_CONSENT_REQUIRED` and performs zero network requests; a license warning cannot exempt that gate. A tight projection budget returns a partial projection with `omittedIds` and cannot be marked complete (`SILENT_TRUNCATE_FORBIDDEN`). Unsupported formats and unconfigured visual/temporal analysis fail closed.

This increment does not download model packs, does not attach blobs through I-004, and does not change the core project store `user_version` (stays 9).

## Consequences

87-task counts become 0 complete / 34 partial / 40 planned / 13 blocked. `fullTasksCompleted` stays 0. Official new suite: 6 tests. Analyzer exit 0.

## Evidence

`docs/implementation/evidence/i028-ingest-projection/`.

## Follow-up

Real OCR/ASR/VLM pipelines, I-004 attach, and V-025 remain open. Next honest Linux/Web increments include I-033 approval/budget reservation/idempotent posting, I-050 encryption and CharacterRepository wiring (clone inference stays unavailable), I-026 graphics-library store, and further play-protocol software tests without physical two-device E2E.
