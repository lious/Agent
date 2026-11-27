I-005 / s3 conflict-replan admission (Increment 3.03) lives in
`packages/studio_conflict_replan_probe` as `ConflictReplanAdmission`.

After REVISION_CONFLICT, READSET_STALE, or FIELD_LOCKED, the candidate
is retained. A later submit is allowed only after a new plan and a new
preview. An automatic retry must not overwrite.

This directory does not host a PlanGraph, IntentReducer, TrimPlanner,
or Flutter widget tree. `run_probe.py` and `run_qualification.py` are
not opened. Increment 3.02 CommandClampAdmission, Increment 2.82
link-offset work, the frozen s3 1/30s suite, I-003 revision tests, and
I-025 leftovers closed by ADR 0104 are not rewritten. I-005 stays
partial. Remaining I-005 remainingAcceptance labels are not silently
cleared.
