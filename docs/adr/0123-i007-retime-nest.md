# ADR 0123 — I-007 RetimeMap / NestResolver (DEV-PURE)

## Status

Accepted for Increment 2.24 as the first Linux/Web software slice of I-007. This is not V-003 playback qualification. `fullTasksCompleted` stays 0. I-006 remaining scope (track lock / syncLock / link / unlink / multi-track boundaries, and field-aware invert of Slip / Roll / Slide) is not closed.

## Decision

`RetimeMap` officializes P1 linear rate and piecewise-linear TimeMap sampling in exact `Q` arithmetic. `sourceAt(u)` maps clip-local time to a source offset relative to `sourceRange.start`. Inverse mapping bisects on `v` and is the only admitted locator for caption source anchors — frame indexes are not used. A split inserts the same mapping point on both segments; the right map restarts at `(0,0)`.

Optical-flow and other non-linear interpolation modes are `RETIME_INTERP_UNSUPPORTED` and cannot steal duration. Reverse, freeze, and smooth curves stay phase-2 and are `RETIME_DIRECTION_UNSUPPORTED` (or `RETIME_NON_MONOTONE` / `RETIME_ENDPOINT_MISMATCH` when a map would violate the P1 endpoint or strictly increasing contract). They are not masqueraded as a positive rate.

`NestResolver` validates a nest DAG: cycles are `NEST_CYCLE`, depth greater than 8 is `NEST_DEPTH`. `sourceAt` composes a stack of TimeMaps, outer first. MakeCompound persist, UpgradeNest fit/trim/ripple, and version auto-follow are not opened.

## Consequences

I-007 becomes partial. Official new suite: 8 tests. Frozen `time_test.dart` (6) is re-run, not rewritten. Analyzer exit 0. 87-task counts become 0 complete / 36 partial / 38 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i007-retime-nest/`.

## Follow-up

MakeCompound persist (external links must be unlinked or all included), UpgradeNest duration-change policy, P2 reverse/freeze/smooth implementation, and V-003 real playback remain open. Optical-flow frame interpolation stays refused. I-006 remaining scope stays open. Leftover I-008 transform2d remainingAcceptance and other still-doable Linux/Web planned work can follow.
