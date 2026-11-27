I-003 / s5b project writer-fence admission (Increment 3.09) lives in
`packages/studio_writer_fence_probe` as `WriterFenceAdmission`.

A live project writer lock must not be stolen merely because a timer
expired. A stale worker result is `STALE_WRITER` and must not mutate
head or the publish target. This is the project editor writer fence,
not I-032 PlanGraph or harness lease fencing.

This directory does not host an OS lock runtime, a PlanGraph
manual-lock API, or crash takeover / pending-publication
reconciliation. `run_probe.py` and `run_qualification.py` are not
opened. Increment 3.08 SqlCloudSideEffectAdmission, I-003 revision
tests, I-032, and I-011 crash leftovers are not rewritten. I-003 stays
partial.
