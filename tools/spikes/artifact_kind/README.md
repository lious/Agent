I-013 / s5b artifact-kind admission (Increment 3.06) lives in
`packages/studio_artifact_kind_probe` as `ArtifactKindAdmission`.

Backup, logical archive, portable archive, finished export, and sync
are distinct artifacts. A finished export must not stand in for an
editable project. A provider-written receipt is not a remote device
sync acknowledgment.

This directory does not host I-013 job archival, a muxer, or
`packMode=proxyOnly`. `run_probe.py` and `run_qualification.py` are
not opened. Increment 2.50 packMode, Increment 2.86
ProxyDeliveryAdmission, Increment 3.05 PackageAutoUpdateAdmission,
official I-024 export suites, and an I-014 RestoreService are not
rewritten. I-013 stays partial.
