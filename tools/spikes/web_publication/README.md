I-020 / s5c web-publication admission (Increment 3.17) lives in
`packages/studio_web_publication_probe` as `WebPublicationAdmission`.

An external download or file handle is an independent publication
and must not reuse POSIX semantics. Increment 2.37 / ADR 0136
WebMediaPort, the OPFS eviction hint, and “canceling a file picker
is not a save” are not re-qualified.

This directory does not host a real OPFS/IndexedDB runtime or a
StoragePort runtime. `run_probe.py` and `run_qualification.py` are
not opened. A 60s WebCodecs/OPFS roundtrip and a V-007 production
lock are not claimed. ffmpeg.wasm is not made the default. I-020
stays partial. Existing I-020 remainingAcceptance measurement
labels are not cleared.
