I-012 / s5b checkpoint-identity admission (Increment 3.11) lives in
`packages/studio_checkpoint_identity_probe` as
`CheckpointIdentityAdmission`.

A product recovery checkpoint is not a SQLite WAL checkpoint and must
not recopy media. A lagging `checkpointRevision` does not mean those
edits are unsaved. SQLite WAL recovery remains as already recorded in
ADR 0003 and is not disabled here.

This directory does not host a WAL-checkpoint runtime, an I-014
RestoreService, or a Flutter widget tree. `run_probe.py` and
`run_qualification.py` are not opened. ADR 0003, Increment 3.07
CloseCheckpointAdmission, Increment 3.10 ExplicitSaveAdmission, ADR
0097 durableRevision, and ADR 0098 are not rewritten. I-012 stays
partial.
