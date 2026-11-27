# ADR 0173 — Official s6c CompatibilityFallbackPlanner protocol

## Status

Accepted for Increment 2.74 as a distinct s6c CompatibilityFallbackPlanner slice, recorded on V-002 because that work item is the first s6c compatibility-probe contract. V-002 stays partial and is not marked complete. Already-official V-002 items — Linux AAC/H264 software probe evidence, P0 format processing, 10 cancel handles, and explicit unsupported-format reasons — are not re-qualified, and I-015 leftovers are not re-qualified. This increment does not invent a real encoder, muxer, cloud worker, or model runtime. V-004 Pulse audio-sink work and the Increment 2.71 drop-disclosure / proxy-downgrade slice are not re-qualified; `ClockBudgetSession` is not rewritten. The Increment 2.72 I-024 smart-render default slice and already-official I-024 export suites are not re-qualified; `ExportService` is not rewritten, and a missing encoder is not re-stated as `ENCODER_UNAVAILABLE`. The Increment 2.73 V-005 provider-restriction slice, `AtomicFilePublisher`, `files_test`, `save_crash_test`, and I-011 crash leftovers are not re-qualified. A SAF/iCloud adapter is not invented, and a finished V-005 provider qualification is not claimed. I-058, I-049, I-050, I-028, I-042, V-006, I-053, V-007, I-001, I-011, and I-015 leftovers are not re-qualified. I-059 stays planned until V-006=advanced-color is honestly met. I-061 and I-055 are not started. A limiter is not invented. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, and V-005 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` is not opened as a claimed qualification.

## Decision

s6c requires `CompatibilityFallbackPlanner.propose{sameFormatSoftware,lowerPreviewProxy,smallerQualifiedModel,selfOwnedWorker,approvedCloud,manual}`, with each item explaining time, quality, privacy, cost, and a new approval hash. Already-verified same-format software may fall back per the user's existing local preference and must be logged. Output size, HDR, model semantics, upload, or cost changes must be confirmed. A missing encoder must not be disguised as a CPU fallback. When no local path is available, the result is pending adaptation or unsupported, and cloud must not be selected silently.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_fallback_probe/lib/compatibility_fallback_planner.dart`:

- Each proposal carries `timeNote`, `qualityNote`, `privacyNote`, `costNote`, and `newApprovalHash`.
- Already-verified same-format software may be applied when the existing local preference allows it, and that apply is logged.
- Applying a fallback that changes output size, HDR, model semantics, upload, or cost without confirmation and an approval hash is `APPROVAL_REQUIRED`.
- Claiming a CPU encoder fallback when no encoder is available is `CPU_ENCODER_FALLBACK_FORBIDDEN`. This is not a re-statement of I-024 `ENCODER_UNAVAILABLE`.
- Auto-selecting `approvedCloud` when no local path is available is `SILENT_CLOUD_FORBIDDEN`. The plan then reports `pendingAdaptation` and `unsupported`.
- `v004ProxyRequalified`, `i024EncoderRequalified`, `encoderInvented`, `cloudCalled`, `paidApiCalled`, `muxerInvented`, `limiterInvented`, and `v005Requalified` stay false.

A real encoder, cloud worker, model runtime, V-004 drop-rate measurement, and I-024 export qualification remain unopened. `tools/spikes/compatibility/README.md` points at the Dart admission; `run_probe.py` is not opened.

## Consequences

The s6c CompatibilityFallbackPlanner contract is officialized at this planner bound. Already-official V-002 codec-probe leftovers, V-004 proxy downgrade, and I-024 no-encoder export refusal are not re-qualified, so V-002 stays partial and is not marked complete. 87-task counts stay 0 complete / 61 partial / 13 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/v002-fallback-planner/`.

## Follow-up

Do not start I-059 until V-006=advanced-color numeric and appearance qualifications are honestly met. Do not start I-061 or I-055. Do not invent a limiter. Do not re-qualify this CompatibilityFallbackPlanner slice, V-004 Pulse or drop-disclosure work, the Increment 2.72 smart-render slice, already-official I-024 export suites, the Increment 2.73 V-005 provider-restriction slice, AtomicFilePublisher, or I-011 / I-015 leftovers. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not invent a SAF/iCloud adapter, a real encoder, or a payment vendor. Do not claim I-016–I-019 hardware ports, a 20ms A/V achievement, store-release as passed, or a finished V-005 provider qualification. Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial leftover that is not already officialized and does not invent a deferred runtime. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, V-005, or V-002 complete.
