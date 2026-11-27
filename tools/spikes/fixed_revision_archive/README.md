I-013 / s5d fixed-revision portable-archive admission
(Increment 3.30) lives in
`packages/studio_fixed_revision_archive_probe` as
`FixedRevisionArchiveAdmission`.

A fixed-revision portable archive must not include pending-job
future outputs, must not be mutated when a later job completes,
must not cancel a paid job on the user's behalf, and must
disclose pending jobs when they exist. Edits during the archive
only affect a new revision.

This directory does not host I-013 job archival, a
WorkflowCoordinator, or a Flutter two-button UI. Increment 3.06
ArtifactKindAdmission and Increment 3.04 JobCancelAdmission are
not re-qualified. The PENDING_MEDIA complete-archive sentence is
not officialized. Quote/apply and paid APIs are not started.
I-013 stays partial. Existing I-013 remainingAcceptance wording
is not cleared.
