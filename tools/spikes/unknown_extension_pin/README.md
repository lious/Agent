I-013 / s5d unknown-extension pin admission (Increment 3.29)
lives in `packages/studio_unknown_extension_pin_probe` as
`UnknownExtensionPinAdmission`.

When an unknown extension's references cannot be enumerated,
those bytes must be pinned conservatively and the archive must
not be claimed complete.

This directory does not host a BackupStore runtime, a 4MiB
chunker, or I-013 job archival. I-004 same-hash, ADR 0099, I-029
DeletionBarrier, Increment 2.50 packMode / sourceCompleteness,
and the unofficialized PENDING_MEDIA complete-archive sentence
are not re-qualified. Incremental blob dedup, private session-DB
backup exclusion, and privacy-immediate purge are not
officialized here. I-013 stays partial. Existing I-013
remainingAcceptance wording is not cleared. I-004
remainingAcceptance is not touched.
