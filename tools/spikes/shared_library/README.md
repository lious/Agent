I-003 / s5b explicit shared-library admission (Increment 3.13) lives
in `packages/studio_shared_library_probe` as `SharedLibraryAdmission`.

An explicit shared library (spec s5b names App Group as the example)
must use the same protocol and namespace authorization. Existing
cross-App private-workspace isolation in `workspace_test.dart` is not
re-qualified.

This directory does not host an OS lock runtime, an App Group
runtime, crash takeover, or a publish-path serial coordinator.
`run_probe.py` and `run_qualification.py` are not opened. Increment
3.12 PreparedStageAdmission, Increment 3.09 WriterFenceAdmission,
Increment 3.08 SqlCloudSideEffectAdmission, I-003 revision tests,
I-032, and I-011 crash leftovers are not rewritten. I-003 stays
partial. Existing I-003 remainingAcceptance labels, including
namespace isolation, are not cleared.
