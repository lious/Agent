# ADR 0203 — Official s3 export/generation cancel must not undo user edits (I-005 leftover)

## Status

Accepted for Increment 3.04 as a distinct already-specified s3 leftover on I-005: canceling a failed export or a cloud generation must not undo already-completed user edits. I-005 stays partial and is not marked complete. Remaining I-005 remainingAcceptance labels are not silently cleared. Increment 3.03 ConflictReplanAdmission, Increment 3.02 CommandClampAdmission, Increment 2.82 0.02s link-offset work, the frozen s3 1/30s suite, ADR 0028 gesture cancel, and official I-024 export suites are not re-qualified and are not rewritten. A WorkflowCoordinator, quote/apply, and an I-014 RestoreService commit path are not invented. No paid API is called. The remaining s3 error-table rows (`MISSING_MEDIA` default export / private transcode, `CANCELED`/`DISK_FULL`, `APPROVAL_STALE` / timeout-as-repay) are not taken. The s3 clause that restoring an old DB must not overwrite later hand edits is left for I-014 and is not officialized here. Increments 2.74–3.03 already-landed slices are not re-qualified. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s3 states that canceling a failed export or a cloud generation must not undo already-completed user edits. This is distinct from ADR 0028, which officialized that canceling a gesture after a successful commit is not undo.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_job_cancel_probe/lib/job_cancel_admission.dart`:

- Canceling an `exportJob` or `cloudGeneration` is admitted and keeps already-completed user edits (`cancelled=true`, `userEditsRetained=true`).
- A cancel that would undo committed user edits is `USER_EDITS_MUST_BE_RETAINED`.
- An unknown job kind is `JOB_CANCEL_KIND_UNKNOWN`.
- This does not rewrite official I-024 export suites, ADR 0028 gesture cancel, Increment 3.03 conflict-replan admission, or Increment 2.51 I-014 restore-event-seq work.
- `conflictReplanRequalified`, `commandClampRequalified`, `gestureCancelRequalified`, `i024ExportRequalified`, `i014RestoreInvented`, `workflowCoordinatorInvented`, `quoteApplyStarted`, `paidApiCalled`, `trimPlannerInvented`, and `flutterWidgetTreeInvented` stay false.

`tools/spikes/job_cancel_user_edits/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s3 export/generation-cancel bound is officialized at this admission. Other I-005 remainingAcceptance labels stay listed and are not silently cleared, so I-005 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i005-job-cancel-user-edits/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this job-cancel admission, Increment 3.03 ConflictReplanAdmission, Increment 3.02 CommandClampAdmission, ADR 0028 gesture cancel, or official I-024 export suites. Do not invent a WorkflowCoordinator or an I-014 RestoreService, and do not silently clear remaining I-005 remainingAcceptance labels. Remaining s3 error-table rows should not be taken if they would re-qualify I-004 / Increment 2.86, I-011, or I-033.
