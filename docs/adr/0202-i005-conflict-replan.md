# ADR 0202 — Official s3 conflict retain, replan, and no auto-retry overwrite (I-005 leftover)

## Status

Accepted for Increment 3.03 as a distinct already-specified s3 leftover on I-005: after `REVISION_CONFLICT`, `READSET_STALE`, or `FIELD_LOCKED`, the candidate is retained; a later submit is allowed only after a new plan and a new preview; an automatic retry must not overwrite. I-005 stays partial and is not marked complete. Remaining I-005 remainingAcceptance labels are not silently cleared. A TrimPlanner, PlanGraph, IntentReducer, and Flutter widget tree are not invented. Video/caption muted/solo, OS clipboard, auto-close, and mobile gestures stay closed. Increment 3.02 CommandClampAdmission, Increment 2.82 0.02s link-offset work, the frozen s3 1/30s suite, I-003 revision tests, and I-025 leftovers closed by ADR 0104 are not re-qualified and are not rewritten. Increments 2.74–3.02 already-landed slices are not re-qualified. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s3 states that `REVISION_CONFLICT`, `READSET_STALE`, and `FIELD_LOCKED` keep the candidate, show the conflict fields and current revision, allow a later submit only after a new plan and a new preview, and must not auto-retry as an overwrite.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_conflict_replan_probe/lib/conflict_replan_admission.dart`:

- After one of the official conflict codes, a submit is admitted only when the candidate was retained and a new plan has been previewed (`submitted=true`, `candidateRetained=true`).
- An automatic overwrite retry is `AUTO_RETRY_OVERWRITE_FORBIDDEN`.
- A dropped candidate is `CANDIDATE_NOT_RETAINED`.
- A submit without a new plan and a new preview is `REPLAN_PREVIEW_REQUIRED`.
- An unknown conflict code is `CONFLICT_CODE_UNKNOWN`.
- This does not invent a conflict-field widget, a PlanGraph, or an IntentReducer, and does not rewrite Increment 3.02 clamp admission or I-003 `REVISION_CONFLICT` transaction tests.
- `commandClampRequalified`, `linkOffsetRequalified`, `frozenS3SuiteRewritten`, `trimPlannerInvented`, `flutterWidgetTreeInvented`, `videoMutedSoloOpened`, `osClipboardInvented`, `autoCloseInvented`, `planGraphInvented`, `intentReducerInvented`, `i003Requalified`, and `i025Requalified` stay false.

`tools/spikes/conflict_replan/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. “Replan” here is the s3 command-planning step after a timeline conflict, not I-032 dynamic PlanGraph replan.

## Consequences

The s3 conflict retain / replan / no-auto-retry bound is officialized at this admission. Other I-005 remainingAcceptance labels stay listed and are not silently cleared, so I-005 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i005-conflict-replan/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this conflict-replan admission, Increment 3.02 CommandClampAdmission, Increment 2.82 0.02s link-offset work, or the frozen s3 1/30s suite. Do not invent a TrimPlanner, PlanGraph, or Flutter widget tree, and do not silently clear remaining I-005 remainingAcceptance labels.
