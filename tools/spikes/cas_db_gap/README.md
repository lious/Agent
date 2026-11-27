I-011 / s5c CAS-to-DB gap admission (Increment 3.14) lives in
`packages/studio_cas_db_gap_probe` as `CasDbGapAdmission`.

The DB must not reference a ready asset before CAS is on disk, and
file rename plus SQLite must not be claimed as one atomic
transaction. Crash-after-CAS orphan claim/GC and ACK-lost receipt
retry are not officialized here.

This directory does not host a CAS runtime, crash injection, or a
receipt-query path. `run_probe.py` and `run_qualification.py` are not
opened. I-011 crash leftovers, AtomicFilePublisher, files_test, and
save_crash_test are not rewritten. I-011 stays partial. Existing
I-011 remainingAcceptance labels are not cleared.
