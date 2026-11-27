I-014 / s5c archive-limit consent admission (Increment 3.21) lives
in `packages/studio_archive_limit_consent_probe` as
`ArchiveLimitConsentAdmission`.

Raising an archive size limit requires one-time explicit consent
and must not disable path, permission, or hash checks.

This directory does not host a schema migrator, an I-014
RestoreService, or a Flutter widget tree. Default
`ProjectArchive` limits are not changed. `files_test` zip-slip,
zip-bomb `ARCHIVE_LIMIT`, and symlink refusal are not
re-qualified. Increment 3.16 FutureMajorAdmission and
“不支持feature只读保留” are not re-qualified. I-014 stays partial.
Existing I-014 remainingAcceptance wording is not cleared.
