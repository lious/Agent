# ADR 0208 — Official s5b live writer lock is not stolen by expiry, and stale workers are STALE_WRITER (I-003 leftover)

## Status

Accepted for Increment 3.09 as a distinct already-specified s5b leftover on I-003: a live project writer lock must not be stolen merely because a timer expired, and a stale worker result is `STALE_WRITER` and must not mutate head or the publish target. This is the project editor writer fence, not I-032 PlanGraph or harness lease fencing (`LEASE_FENCED`). A PlanGraph manual-lock API is not invented. I-032 leftovers are not re-qualified. Crash takeover and pending-publication reconciliation are not officialized here and are not used to re-qualify I-011 crash leftovers. I-003 stays partial and is not marked complete. I-003 revision tests are not rewritten. Existing I-003 remainingAcceptance labels (100 concurrent same-baseRevision, undo creates a new revision, no half-write, namespace isolation) are not silently cleared. Increment 3.08 SqlCloudSideEffectAdmission, Increment 3.07 CloseCheckpointAdmission, Increment 3.05 PackageAutoUpdateAdmission, Increment 3.06 ArtifactKindAdmission, ADR 0098 I-012 leftovers, I-033, and I-040 are not re-qualified. Quote/apply and paid generation are not started. No paid API is called. An OS lock runtime is not invented. The s5b “不能盲重试生成”, “保存中编辑/合并”, and “生成中的资源” rows are not taken. Increments 2.74–3.08 already-landed slices are not re-qualified. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-003, I-012, I-013, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5b states that a live writer lock must not be taken over merely because an expiry elapsed, and that a stale worker result is reported as `STALE_WRITER` and must not touch head or the publish target.

This increment officializes only those two bounds as a DEV-PURE compiler at the official entry path `packages/studio_writer_fence_probe/lib/writer_fence_admission.dart`:

- The current owner of a live project writer lock is admitted (`admitted=true`, `headMutated=false`, `publishTargetMutated=false`).
- Stealing that live lock only because a timer expired is `STEAL_LIVE_LOCK_FORBIDDEN`.
- A stale worker result is `STALE_WRITER`, including when it would mutate head or the publish target.
- This is not I-032 `LEASE_FENCED` on `finishHarnessTask`, not a PlanGraph manual-lock API, and not crash takeover after the OS releases a lock.
- `sqlCloudSideEffectRequalified`, `i032PlanGraphFenceRequalified`, `planGraphManualLockInvented`, `i011CrashRequalified`, `i003RevisionTestsRewritten`, `closeCheckpointRequalified`, `quoteApplyStarted`, `paidApiCalled`, and `osLockRuntimeInvented` stay false.

`tools/spikes/writer_fence/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s5b live-lock and `STALE_WRITER` bounds are officialized at this admission. I-003 remainingAcceptance measurement and isolation labels stay listed, so I-003 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i003-writer-fence/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this writer-fence admission, Increment 3.08 SqlCloudSideEffectAdmission, I-003 revision tests, I-032 PlanGraph fencing, or I-011 crash leftovers. Do not invent a PlanGraph manual-lock API or an OS lock runtime. Do not take s5b “不能盲重试生成”, “保存中编辑/合并”, or “生成中的资源” if that would re-qualify I-033, I-040, I-011, ADR 0098, I-004 attach, I-013 archival, or I-024.
