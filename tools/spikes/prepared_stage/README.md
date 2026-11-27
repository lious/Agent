I-003 / s5b prepared-stage admission (Increment 3.12) lives in
`packages/studio_prepared_stage_probe` as `PreparedStageAdmission`.

The save prepared stage must not hold a long SQLite write
transaction. This is a leftover fencing clause after Increment 3.09,
not a rewrite of WriterFenceAdmission.

This directory does not host an OS lock runtime, crash takeover,
pending-publication reconciliation, or a publish-path serial
coordinator. The leftover “different apps do not share a private
workspace” / App Group clause is not officialized here. `run_probe.py`
and `run_qualification.py` are not opened. Increment 3.09
WriterFenceAdmission, Increment 3.08 SqlCloudSideEffectAdmission,
I-003 revision tests, I-032, and I-011 crash leftovers are not
rewritten. I-003 stays partial. Existing I-003 remainingAcceptance
labels are not cleared.
