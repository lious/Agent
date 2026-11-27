# ADR 0111 — Official random undo/hash coverage of admitted clip gain commands

## Status

Accepted for Increment 2.10 as a bounded official-coverage slice of already-admitted I-009 clip gain Effect persist (Increment 2.02) and the 2.06 coverage follow-on. I-009 stays partial. This increment does not open I-007 remapping or nest, does not start I-060/V-024 limiter, does not change InversePatch (`restoreSnapshot`), does not add field-level invert of gain or of Slip/Roll/Slide, does not change I-023 clock/queue/timeout/assertion, and does not claim I-023 complete. Increment 1.17/1.18 stay open. Core store `user_version` stays 9.

## Context

Increment 2.02 admitted `SetClipGain`, `SetGainKeyframe`, and `RemoveGainKeyframe`. Increment 2.06 officialized overwrite-crop (`param=gainDb`) and `effectIds.*` locks, and recorded that gain commands were still not registered in a random undo generator. The existing Increment 1.38 / 1.88 official random-undo suites must not be rewritten to recount those titles as gain coverage.

## Decision

Add a new official document test file that generates only the three already-admitted gain commands, plus already-admitted refusal cases (off-sample key, out-of-range dB, missing key, video-clip target). Legal random sequences walk immutable before-snapshots — the official InversePatch kind `restoreSnapshot` — back to the start content hash (revision leaf omitted). A refusal leaves the document unchanged (no half-write). The suite asserts that all three command families are actually drawn; a 1000-sequence pass that never issued a gain command would not count as this coverage. Frozen Increment 1.88 / I-005 files and the frozen 2.02 / 2.06 gain tests are left unchanged. Production algebra is unchanged.

## Consequences

Independent audio import, bus Effect/limiter, I-007, new-track, invert-matrix rows, caption export, and cross-device/RTC remain unopened. I-009 remains partial.

## Evidence

`docs/implementation/evidence/clip-gain-random-undo/`.
