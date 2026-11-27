I-012 / s5b package auto-update admission (Increment 3.05) lives in
`packages/studio_package_auto_update_probe` as
`PackageAutoUpdateAdmission`.

Package auto-update defaults to off and must disclose that the project
is auto-saved locally while the external package is still pending.
Provider, network, or OS-sync-hosted targets must not background
auto-overwrite, and a path must not be assumed to be a plain file with
no upload. An authorized local auto-update must not re-copy CAS
originals.

This directory does not host a SAF or iCloud adapter, a StoragePort
publisher, or a claimed V-005 qualification. `run_probe.py` and
`run_qualification.py` are not opened. ADR 0098 I-012 leftovers,
Increment 2.73 provider-restriction admission, AtomicFilePublisher,
and official I-024 export suites are not rewritten. I-012 stays
partial.
