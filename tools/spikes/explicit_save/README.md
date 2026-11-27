I-012 / s5b explicit-save admission (Increment 3.10) lives in
`packages/studio_explicit_save_probe` as `ExplicitSaveAdmission`.

Library-mode `saveManaged` writes a checkpoint and an explicit save
receipt and must not imply a `.studioproj` was written.
`saveBoundPackage` requires an external binding and may claim success
only after a StoragePort receipt.

This directory does not host a Flutter widget tree, a SAF or iCloud
adapter, a StoragePort runtime, or an I-014 RestoreService.
`run_probe.py` and `run_qualification.py` are not opened. Increment
3.07 CloseCheckpointAdmission, Increment 3.05
PackageAutoUpdateAdmission, Increment 3.06 ArtifactKindAdmission, and
ADR 0098 I-012 leftovers are not rewritten. The 30s/120s s5b figures
are not claimed as a measured qualification. I-012 stays partial.
