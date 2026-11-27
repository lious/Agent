I-012 / s5b Save As and named-version admission (Increment 3.19)
lives in `packages/studio_save_as_named_version_probe` as
`SaveAsNamedVersionAdmission`.

Save As must not silently overwrite an existing file. A named
version is a label pin of an immutable checkpoint, not a fork or
a rollback.

This directory does not host a Flutter widget tree, a StoragePort
runtime, or an I-014 RestoreService. `CHECKPOINT_NAME_EXISTS`,
fork-new-projectId, Increment 3.10 ExplicitSaveAdmission, and
Increment 3.11 CheckpointIdentityAdmission are not re-qualified.
The “new project copy defaults to a new projectId” and “keep the
id and explicitly switch binding” clauses are not officialized
here. I-012 stays partial. Existing I-012 remainingAcceptance
wording is not cleared.
