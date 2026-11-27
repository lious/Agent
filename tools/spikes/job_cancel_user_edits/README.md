I-005 / s3 job-cancel admission (Increment 3.04) lives in
`packages/studio_job_cancel_probe` as `JobCancelAdmission`.

Canceling a failed export or a cloud generation must not undo
already-completed user edits.

This directory does not host a WorkflowCoordinator, quote/apply, or an
I-014 RestoreService. `run_probe.py` and `run_qualification.py` are
not opened. Increment 3.03 ConflictReplanAdmission, Increment 3.02
CommandClampAdmission, ADR 0028 gesture cancel, and official I-024
export suites are not rewritten. I-005 stays partial. Remaining I-005
remainingAcceptance labels are not silently cleared.
