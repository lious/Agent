# ADR 0170 — Official V-004 preview-drop disclosure and queue-bound protocol

## Status

Accepted for Increment 2.71 as a distinct V-004 leftover slice. V-004 stays partial and is not marked complete. The existing Linux Pulse audio-sink work (bounded ring, pause/seek/rebind, underrun diagnostics) is not rewritten and is not re-qualified as a 20ms A/V, no-underrun, or 20-minute thermal achievement. The 20ms A/V, sustained-underrun, OOM/deadlock, 5% drop-rate, and 3-video/2-audio 20-seek 20-minute thermal measurements are not claimed. V-003 stays unclaimed. This increment does not invent a hardware clock, a limiter, or I-016–I-019 hardware ports. I-059 stays planned until V-006=advanced-color is honestly met. I-061 and I-055 are not started. I-058, I-049, I-050, I-028, I-042, V-006, I-053, V-007, I-001, I-011, and I-015 leftovers are not re-qualified. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, and I-058 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. Existing `preview_proxy.dart` and `frame_proxy_test.dart` suites are not rewritten.

## Decision

s7 requires that a frame late by more than one output deadline drops display only and continues necessary reference-frame decode; audio samples are not deleted to catch up with video. The V-004 work item requires that dropped frames are not hidden as success, that an unmet preview drop-rate target only downgrades the preview proxy and discloses the drop, that a load failure may limit concurrency or switch to a proxy or repair the clock but must not change output time, and that a configured queue upper bound is not exceeded. The ≤20ms A/V, no-sustained-underrun, and ≤5% drop targets remain measurement gates, not a default accept. Silently stretching output audio on underrun is refused.

This increment officializes that bound as a DEV-PURE compiler in a new workspace package `packages/studio_clock_probe`, entry file `lib/clock_budget.dart`. `tools/spikes/clock_load/README.md` points at this admission. `run_probe.py` is not opened.

- Hiding dropped frames as success is `DROP_HIDDEN_AS_SUCCESS`. Changing output time to hide load is `OUTPUT_TIME_IMMUTABLE`. Deleting audio samples to catch up with video is `AUDIO_SAMPLES_NOT_DROPPED`. Silently stretching audio on underrun is `UNSUPPORTED_EDIT_TECHNIQUE`.
- When `v004Met` is false or `dropRate` exceeds the 0.05 target, `preview` returns `proxyDowngraded` with `dropDisclosed=true` and `claimedSuccess=false`. Claiming the drop target is met is `V004_GATE_UNMET`. Downgrading the proxy without disclosure is `PROXY_DOWNGRADE_UNDISCLOSED`.
- A queue use above `queueBound` is `QUEUE_BOUND_EXCEEDED`. Claiming 20ms A/V or resolved underrun is `V004_GATE_UNMET`. `v004Claimed`, `avSyncClaimed`, `underrunResolvedClaimed`, `thermalLoadClaimed`, `hardwareClockInvented`, and `v003Claimed` stay false.

A measured 20-minute thermal / 20-seek device qualification, a real hardware clock, and I-016–I-019 ports remain unopened.

## Consequences

The V-004 leftover acceptance items “预览drop率目标≤5%，未达只降预览代理并披露”, “不把吞帧隐藏成成功”, “队列不超配置上界”, and “失败不能改输出时间” are officialized at this ClockBudgetSession bound. The 20ms A/V, no-sustained-underrun, no-OOM, 5% drop, and 20-minute thermal gates remain unmet, so V-004 stays partial and is not marked complete. 87-task counts stay 0 complete / 61 partial / 13 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/v004-clock-budget/`. The earlier `evidence/audio-sink/` Pulse work remains listed and is not re-qualified.

## Follow-up

Do not start I-059 until V-006=advanced-color numeric and appearance qualifications are honestly met. Do not start I-061 or I-055. Do not invent a limiter (V-024 / I-060 stay closed). Do not re-qualify V-004 Pulse audio-sink work or this drop-disclosure slice, and do not re-qualify I-058, I-049, I-050, I-028, I-042, V-006, I-053, V-007, I-001, I-011, or I-015 leftovers. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not claim I-016–I-019 hardware ports, a 20ms A/V achievement, or store-release as passed. Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial leftover that is not already officialized and does not invent a deferred runtime. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, or V-004 complete.
