# ADR 0154 — Official I-046 ASR CaptionProposal refusals without inference

## Status

Accepted for Increment 2.55 as the first I-046 slice. I-046 moves planned → partial and is not marked complete. V-009 stays blocked; this increment does not claim on-device ASR inference or a CER/WER score. I-010 caption-table leftovers are not re-qualified. I-051, I-054, and I-029 are not re-qualified. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, V-020, I-054, and I-051 stay partial and are not marked complete. V-021 stays blocked. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. This increment does not invent a real ASR engine, does not download a Whisper pack, does not start cloud ASR, and does not default to stem separation or diarization.

## Decision

s8r defines `SubtitleService.transcribe(ASRSpec) -> CaptionProposal` (not a direct caption-table UPDATE) and `accept(proposalHash, expectedRevision, lockedCueIds) -> CommandReceipt`. Whisper-base windows are 16 kHz mono, 30 s with a 29 s hop. Silence or music is marked suspected via VAD / no-speech / repetition signals and must not invent dialogue or be auto-accepted. Overlap dedup checks overlapping time and text together; an approximate conflict keeps both evidence rows and does not invent a new sentence. `speakerId` stays null; diarization is not a default capability. Re-recognition only proposes diffs; locked or hand-edited cues must not be overwritten. A deleted source or a late cancel must not hang a cue. Quality shortfalls may be edited by hand; they must not automatically go to a cloud recognizer. s8a says a missing audio track is `noAudio` and must not invent a transcript.

This increment officializes that bound as a DEV-PURE compiler in `packages/studio_audio_tools/lib/asr/transcription_job.dart`:

- `TranscriptionJob.transcribe` does not write the caption table. Silence or music windows, including invented text, are emitted as `suspectedHallucination` with empty text and `autoAccepted=false`. Auto-accepting them is `HALLUCINATION_NOT_AUTO_ACCEPTED`. `noAudio` returns an empty proposal. Requested diarization is `UNSUPPORTED_EDIT_TECHNIQUE`. Requested cloud ASR is `TOOL_NOT_ALLOWED`. `speakerId` stays null. Real inference is not claimed.
- A window that overlaps a locked or hand-edited cue is omitted from the proposal. `accept` with that cue in `lockedCueIds` is `FIELD_LOCKED`. Accept records a planned `expectedRevision+1` and does not write a document.
- Identical overlapping 30 s / 29 s windows keep one cue. Conflicting overlap keeps both cues with `conflictWithId` and does not invent a merged sentence. A deleted source is `SOURCE_DELETED`; a cancelled proposal is `PROPOSAL_CANCELLED`. `attachLate` after delete or cancel leaves `lateResultAttached=false` and `hungCues=0`.

A real Whisper runtime, V-009 qualification, and I-010 source-interval crop / MP4 burn-in remain unopened.

## Consequences

The first I-046 leftover acceptance items (silence/music hallucination is not auto-accepted, locked cues are not overwritten, window overlap is deduped, and a deleted source or late cancel does not hang a cue) are officialized at this proposal-compiler bound. V-009 stays blocked, so I-046 stays partial and is not marked complete. 87-task counts become 0 complete / 46 partial / 28 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i046-asr-proposal/`.

## Follow-up

Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial work from the four planning documents. Do not invent a real ASR engine or claim V-009. Do not re-qualify I-046, I-051, I-054, I-029, or I-010 leftovers. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not start I-035 as a product loop or claim a V-020 precision/recall achievement. Do not claim a 60s WebCodecs/OPFS roundtrip or pin a V-007 production lock. Do not start quote/apply, paid generation, or SQL `vertical.v1` unless a narrowly specified protocol slice is already written. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, or I-046 complete.
