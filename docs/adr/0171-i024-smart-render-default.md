# ADR 0171 — Official I-024 no-default-smart-render and export-policy protocol

## Status

Accepted for Increment 2.72 as a distinct I-024 leftover slice. I-024 stays partial and is not marked complete. Already-official I-024 acceptance items — revision is pinned during export, failed or cancelled export is not a damaged fake success, and the 60s / 1-frame / 20ms / black-or-dropped-frame qualification suites in `audio_export_test.dart` / `local_video_test.dart` and the 60s offline tool — are not re-qualified and those files are not rewritten. This increment does not invent a muxer or a smart-render engine. V-003 stays unclaimed. 1-frame duration, 20ms A/V, and no-black-frame measurements are not claimed here. V-004 Pulse audio-sink work and the Increment 2.71 drop-disclosure slice are not re-qualified. I-058, I-049, I-050, I-028, I-042, V-006, I-053, V-007, I-001, I-011, and I-015 leftovers are not re-qualified. I-059 stays planned until V-006=advanced-color is honestly met. I-061 and I-055 are not started. A limiter is not invented. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, and V-004 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called.

## Decision

s6 requires that P1 editorial output is re-encoded; smart render and mixed stream-copy are disabled, so a preview texture screenshot is not an export. The I-024 remainingScope requires that smart render is not the default. The I-024 decision requires an explicit failure when no encoder is available or the disk is full, and a new approval when HDR, fps, or upload changes.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_export/lib/export_service.dart`:

- `smartRenderDefault` stays false. Enabling smart render, or constructing a service with it on, is `SMART_RENDER_NOT_DEFAULT`. Mixed stream-copy is `STREAM_COPY_DISABLED`. A default plan reports `reencodeRequired=true`.
- Exporting by screenshot of a preview texture is `PREVIEW_SCREENSHOT_NOT_EXPORT`. A missing encoder is `ENCODER_UNAVAILABLE`. A full disk is `DISK_FULL`.
- Changing HDR, fps, or upload without a new approval is `APPROVAL_REQUIRED`. `muxerInvented`, `v003Claimed`, `durationClaimed`, `avSyncClaimed`, `cancelSuiteRequalified`, and `revisionSuiteRequalified` stay false.

A real muxer, a 60s delivery golden, and a V-003 export-render qualification remain unopened.

## Consequences

The I-024 leftover “不默认smart-render”, together with the already-specified s6 stream-copy / preview-screenshot prohibition and the explicit no-encoder / disk-full / new-approval decision, is officialized at this ExportService bound. Already-official cancel, revision, and timing suites are not re-qualified, so I-024 stays partial and is not marked complete. 87-task counts stay 0 complete / 61 partial / 13 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i024-smart-render-default/`.

## Follow-up

Do not start I-059 until V-006=advanced-color numeric and appearance qualifications are honestly met. Do not start I-061 or I-055. Do not invent a limiter. Do not re-qualify this smart-render slice or the already-official I-024 export suites, and do not re-qualify V-004, I-058, I-049, I-050, I-028, I-042, V-006, I-053, V-007, I-001, I-011, or I-015 leftovers. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not claim I-016–I-019 hardware ports, a 20ms A/V achievement, or store-release as passed. Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial leftover that is not already officialized and does not invent a deferred runtime. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, or I-024 complete.
