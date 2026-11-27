# ADR 0212 — Official s5b explicit shared library requires the same protocol and namespace authorization (I-003 leftover)

## Status

Accepted for Increment 3.13 as a distinct already-specified s5b leftover on I-003: an explicit shared library (spec s5b names App Group as the example) must use the same protocol and namespace authorization. This is the leftover fencing clause after Increment 3.12, not a re-qualification of existing cross-App private-workspace isolation already official in `workspace_test.dart` (cited by ADR 0105). I-003 stays partial and is not marked complete. I-003 revision tests are not rewritten. Existing I-003 remainingAcceptance labels (100 concurrent same-baseRevision, undo creates a new revision, no half-write, namespace isolation) are not silently cleared; this slice is share-authorization, not the `namespace越界读写=0` measurement. Increment 3.12 PreparedStageAdmission, Increment 3.09 WriterFenceAdmission, Increment 3.08 SqlCloudSideEffectAdmission, Increment 3.11 CheckpointIdentityAdmission, I-032 PlanGraph fencing, and I-011 crash leftovers are not re-qualified. An OS lock runtime, an App Group runtime, a PlanGraph manual-lock API, crash takeover, pending-publication reconciliation, and a publish-path serial coordinator are not invented. SQLite WAL recovery remains as already recorded in ADR 0003 and is not disabled. Store journal pragmas are not changed. A Flutter widget tree, a StoragePort runtime, a SAF or iCloud adapter, I-013 job archival, a muxer, and an I-014 RestoreService are not invented. The s5b “不能盲重试生成”, “保存中编辑/合并”, and “生成中的资源” rows are not taken. Remaining s3 error-table rows are not taken. Increments 2.74–3.12 already-landed slices are not re-qualified. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-003, I-012, I-013, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5b states that different apps do not share a private workspace, and that an explicit App Group shared library must still use the same protocol and namespace authorization. The first half is already official in `packages/studio_sdk/test/workspace_test.dart` (two host AppProfiles share implementation, never session/project scope) and is not rewritten or re-qualified here.

This increment officializes only the explicit shared-library authorization bound as a DEV-PURE compiler at the official entry path `packages/studio_shared_library_probe/lib/shared_library_admission.dart`:

- An explicit shared library is admitted when it uses the same protocol and is namespace-authorized (`admitted=true`, `sharedLibraryAuthorized=true`).
- A path that is not an explicit shared library is `EXPLICIT_SHARED_LIBRARY_REQUIRED`.
- An explicit shared library without the same protocol is `SHARED_LIBRARY_PROTOCOL_REQUIRED`.
- An explicit shared library without namespace authorization is `SHARED_LIBRARY_NAMESPACE_UNAUTHORIZED`.
- This does not invent an App Group or OS lock runtime, and does not clear the I-003 `namespace越界读写=0` measurement label.
- `preparedStageRequalified`, `writerFenceRequalified`, `sqlCloudSideEffectRequalified`, `workspaceIsolationRequalified`, `i003RevisionTestsRewritten`, `i003NamespaceLabelsCleared`, `osLockRuntimeInvented`, `appGroupRuntimeInvented`, `crashTakeoverOfficialized`, and `i032PlanGraphFenceRequalified` stay false.

`tools/spikes/shared_library/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s5b explicit shared-library authorization bound is officialized at this admission. I-003 remainingAcceptance measurement and isolation labels stay listed, so I-003 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i003-shared-library/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this shared-library admission, existing `workspace_test.dart` cross-App isolation, Increment 3.12 PreparedStageAdmission, Increment 3.09 WriterFenceAdmission, Increment 3.08 SqlCloudSideEffectAdmission, I-003 revision tests, I-032 PlanGraph fencing, or I-011 crash leftovers. Do not invent an OS lock runtime, an App Group runtime, crash takeover, pending-publication reconciliation, or a publish-path serial coordinator. Do not silently clear I-003 namespace-isolation labels. s5b fencing leftovers are now largely officialized; prefer the next still-doable leftover from the four planning documents that is not already officialized. Do not take s5b “不能盲重试生成”, “保存中编辑/合并”, or “生成中的资源” if that would re-qualify I-033, I-040, I-011, ADR 0098, I-004 attach, I-013 archival, or I-024.
