# ADR 0115 — I-031 recoverable timeout, FIFO job queue, and steer

## Status

Accepted for Increment 2.16 as the next official I-031 slice after Increment 2.14. I-031 remains partial. `fullTaskComplete` stays false. This is not I-029 wiring and not on-device inference.

## Decision

`AgentScheduler` and a deadline-aware `AgentHarness.runTurn` officialize the remaining 2.14 leftover clauses: timeout produces a recoverable error, and steer / queue / job scheduling exist at the portable interface layer.

`ManualClock` is injectable so official tests do not sleep. Mid-generate and pre-generate deadlines throw `RECOVERABLE_TIMEOUT`, journal `{recoverable: true}`, and do not cancel the budget. A timeout before generate does not claim the command id. A later job or a retry with a fresh command id can still run. FIFO `enqueue` / `runNext` processes one job at a time. Cancelling a queued job that has not run leaves tool side effects at 0. `steer` attaches to a queued or running job and is applied as a trusted system segment on the next step; it cannot rewrite a finished receipt (`LATE_RESULT_DROPPED`).

The frozen Increment 2.14 suite `harness_loop_test.dart` (7) is not rewritten.

## Consequences

I-031 remainingAcceptance is cleared (the timeout clause is officialized). remainingScope is narrowed: turn/run/step/job, steer, queue, cancel, fail-closed middleware, and no persisted reasoning are now in implementedScope. Wiring to I-029 / production PlanGraph scheduling remains open, so I-031 stays partial. 87-task counts stay 0 complete / 33 partial / 41 planned / 13 blocked. Official new suite: 5 tests. Analyzer exit 0.

Increment 2.14 and 2.15 evidence hashes are not modified. Core project `user_version` stays 9.

## Evidence

`docs/implementation/evidence/i031-timeout-queue/`.

## Follow-up

Next honest Linux/Web increments include I-049 automatic sentence split, I-028 / I-033 interface ports, I-026 graphics-library store, I-050 encryption and CharacterRepository wiring (clone inference stays unavailable), and further play-protocol software tests without physical two-device E2E.
