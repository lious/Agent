I-013 / s5a–s5d session-export admission (Increment 3.24) lives in
`packages/studio_session_export_probe` as `SessionExportAdmission`.

When session content is not included, contentRefs are redacted
placeholder IDs and body blobs are not retained. Command bodies
are not exported. Runs are historical or interruptedOnExport,
not live.

This directory does not host a session-archive runtime, job
archival, an I-014 RestoreService, or PatchGroup cherry-pick.
Increment 1.92 / ADR 0099 default session exclusion, Increment
3.22 AuditJournalAdmission, and ADR 0018 no job-resume binding
are not re-qualified. Production FTS/RAG is not claimed. I-013
stays partial. Existing I-013 remainingAcceptance wording is
not cleared.
