I-013 / s5c package-projection admission (Increment 3.18) lives in
`packages/studio_package_projection_probe` as
`PackageProjectionAdmission`.

models/references, index, and thumbnail are snapshot projections,
not a second source of truth. A mismatch with the real snapshot
must fail rebuild as `PACKAGE_PROJECTION_MISMATCH`, and a
projection must not overwrite the snapshot body.

This directory does not host a muxer, job-archival coordinator, or
I-014 RestoreService. Increment 2.50 packMode,
Increment 3.06 ArtifactKindAdmission, and
`MANIFEST_SNAPSHOT_MISMATCH` are not re-qualified. The
PENDING_MEDIA / RESOURCE_MISSING complete-archive sentence is not
officialized here. I-013 stays partial. Existing I-013
remainingAcceptance wording is not cleared.
