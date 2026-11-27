I-013 / s5d package-staging admission (Increment 3.25) lives in
`packages/studio_package_staging_probe` as `PackageStagingAdmission`.

Each package is built from clean staging. A previous
session-containing directory must not be reused. Generic caches
are not packed casually. Analysis evidence is included only when
the user explicitly selects it as a production basis and
permission is granted.

This directory does not host a ZipPlanner, job archival, an
I-014 RestoreService, or a session-archive runtime. Increment
3.24 SessionExportAdmission, Increment 1.92 / ADR 0099, and
Increment 3.22 AuditJournalAdmission are not re-qualified.
Production FTS/RAG is not claimed. I-013 stays partial. Existing
I-013 remainingAcceptance wording is not cleared.
