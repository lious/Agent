I-014 / s5a audit-journal admission (Increment 3.22) lives in
`packages/studio_audit_journal_probe` as `AuditJournalAdmission`.

An audit journal is CommandArchive metadata only. It must not
carry original payload, a newFileToken, or an executable body,
must not be replayed on import, must not execute an old Undo
as-is, and a new project's undo stack starts empty.

This directory does not host an I-014 RestoreService, PatchGroup
cherry-pick, workspace SQLite w5, or a schema migrator.
Increment 1.92 / ADR 0099 default command-journal exclusion,
Increment 3.21 ArchiveLimitConsentAdmission, and Increment 3.16
FutureMajorAdmission are not re-qualified. I-014 stays partial.
Existing I-014 remainingAcceptance wording is not cleared.
