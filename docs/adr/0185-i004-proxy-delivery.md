# ADR 0185 — Official s4 proxy-edit and explicit proxy-delivery export (I-004 leftover)

## Status

Accepted for Increment 2.86 as a distinct already-specified s4 / I-004 leftover: a proxy is enough to edit, but a default export without the original is refused; only an explicit “以代理交付” confirmation produces a marked degraded export record. I-004 stays partial and is not marked complete. Other I-004 remainingAcceptance labels (同hash多引用仅1blob、错hash重链接拒绝、撤销引用不删仍可达原件) stay listed and are not silently cleared. This increment does not rewrite `files_test`, `audio_export_test`, `local_video_test`, or Increment 2.72 `ExportService`. A muxer is not invented, and V-003 is not claimed. I-013 archive `packMode=proxyOnly` is not invented or re-qualified. Increment 2.85 recording-drift admission, Increment 2.84 VFR audio-duration admission, Increment 2.83 varispeed-and-pitch admission, Increment 2.80 media retention, and I-021 seek/VFR/PTS suites are not re-qualified. Increment 2.82 I-005 0.02s link-offset work, Increment 2.81 V-023 PressureAdmission, and Increments 2.74–2.79 are not re-qualified. CompatibilityStore / ModelLease are not started. I-059 stays planned. I-061 and I-055 are not started. I-013 stays partial. I-014 stays partial. I-035 stays planned. I-023, I-021, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` is not opened as a claimed qualification.

## Decision

s4 requires that a proxy may be edited when the original is missing, that a default final export without the original is refused, and that only an explicit “以代理交付” confirmation produces a marked degraded export record. I-004 remainingAcceptance includes “部分导入不可导出”.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_proxy_delivery_probe/lib/proxy_delivery_admission.dart`:

- Editing is allowed when the original or a proxy is present.
- A default export without the original is `MISSING_ORIGINAL_EXPORT`, even if a proxy is present.
- An explicit proxy-delivery export without a proxy is `PROXY_UNAVAILABLE`. An explicit proxy-delivery export that is not marked degraded is `DEGRADED_EXPORT_UNMARKED`.
- An explicit proxy-delivery export with a proxy and a degraded mark is admitted and reports `degraded=true`. An export that still has the original is not degraded.
- `i024Requalified`, `i013Requalified`, `filesTestRequalified`, `muxerInvented`, `v003Claimed`, `packModeProxyOnlyInvented`, and `paidApiCalled` stay false.

A real muxer and a `packMode=proxyOnly` archive mode remain unopened. `tools/spikes/proxy_delivery/README.md` points at the Dart admission; `run_probe.py` is not opened.

## Consequences

The s4 “代理存在时可编辑但最终导出默认拒绝缺原件；用户明确以代理交付才生成标记降质的导出记录” and I-004 “部分导入不可导出” bounds are officialized at this admission. Other I-004 labels stay listed, so I-004 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i004-proxy-delivery/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this proxy-delivery admission, Increment 2.72 ExportService, I-013 packMode, or I-024 export suites. Do not invent a muxer, and do not claim V-003.
