# ADR 0109 — Official coverage of overwrite-crop and effectIds.* locks for admitted clip gain Effects

## Status

Accepted for Increment 2.06 as a bounded official-coverage slice of already-admitted I-009 clip gain Effect persist (Increment 2.02). I-009 stays partial. This increment does not open I-007 remapping or nest, does not start I-060/V-024 limiter, does not change InversePatch (`restoreSnapshot`), does not change I-023 clock/queue/timeout/assertion, and does not claim I-023 complete. Increment 1.17/1.18 stay open.

## Context

Increment 2.02 admitted `SetClipGain` / `SetGainKeyframe` / `RemoveGainKeyframe`, overwrite/split/trim crop via `cropGainPoints` (`param` `gainDb`), and `lockedFields` prefix matching for `effects.*` / `effectIds.*`. Two official cases were recorded as coverage gaps that did not block merge: there was no dedicated official overwrite-crop test asserting `param=gainDb`, and `effectIds.*` was implemented with `startsWith` but had no dedicated official case (2.02 covered `effects`, `effectIds`, `gain`, and `effects.gain` only).

## Decision

Add two official document tests in a new file, without rewriting the frozen 2.02 test file and without changing production algebra. Overwrite paste of an admitted gain curve must crop the destination remnant and rebind the incoming copy with `param=gainDb` and the already-admitted boundary values. `lockedFields` values starting with `effectIds.` must refuse user gain edits (`FIELD_LOCKED`), official analysis (`MANUAL_LOCKED`), and an overwrite paste that would crop the locked clip (`FIELD_LOCKED`), leaving the document unchanged.

## Consequences

Independent audio import, bus Effect/limiter, I-007, new-track, invert-matrix rows, caption export, and cross-device/RTC remain unopened. I-009 remains partial.

## Evidence

`docs/implementation/evidence/clip-gain-overwrite-effectids-lock/`.
