I-003 / s5b SQL-commit cloud-side-effect admission (Increment 3.08)
lives in `packages/studio_sql_cloud_side_effect_probe` as
`SqlCloudSideEffectAdmission`.

A workspace SQLite commit transaction must not start a cloud side
effect.

This directory does not host a cloud client, quote/apply, paid
generation, or a WorkflowCoordinator. `run_probe.py` and
`run_qualification.py` are not opened. Increment 3.07
CloseCheckpointAdmission, Increment 3.05 PackageAutoUpdateAdmission,
Increment 3.06 ArtifactKindAdmission, ADR 0098 I-012 leftovers, I-003
revision tests, I-033, I-040, and I-011 crash leftovers are not
rewritten. I-003 stays partial.
