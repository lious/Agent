I-013 / s5a history-availability admission (Increment 3.26) lives
in `packages/studio_history_availability_probe` as
`HistoryAvailabilityAdmission`.

When history is not selected, the package keeps only the current
revision snapshot. Old references are marked unavailable rather
than retargeted at the current content.

This directory does not host a history-selected packer, an
ImportMap runtime, an I-014 RestoreService, or PatchGroup
cherry-pick. ADR 0018 “no imported history,” no
historical-revision / session / job-resume binding, and
fork-new-projectId are not re-qualified. Increment 3.25
PackageStagingAdmission and Increment 3.24 SessionExportAdmission
stay closed. I-013 stays partial. Existing I-013
remainingAcceptance wording is not cleared.
