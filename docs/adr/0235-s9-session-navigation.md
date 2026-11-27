# ADR 0235 — Official s9 leaving a screen is not a cancel, and switching sessions must not cancel a run or reset the playhead

## Status

Accepted for Increment 3.36 as a distinct already-specified s9 leftover, looked up more broadly after I-013 packing / archive slices, I-002 measurement claims, Increment 3.32 license-execution, and Increment 3.35 license-provenance: leaving a screen is not a cancel, and switching sessions must not cancel a running job or reset the playhead. This is not an I-013 packing or archive slice, not an I-002 measurement claim, and not a license leftover already officialized in Increments 3.32 or 3.35. I-027 remainingAcceptance wording is kept at the start and is not silently rewritten or cleared; a session-navigation note is appended only. I-013 remainingAcceptance wording (including the Increment 3.32 and 3.35 appends) is not rewritten. I-002 remainingAcceptance wording (including Increments 3.31 / 3.33 / 3.34) is not rewritten. I-033, I-058, I-053, I-004, I-005, I-029, and I-040 task-status are not rewritten. Increment 3.04 JobCancelAdmission is not re-qualified: that bound is that a failed export or cloud-generation cancel must not undo already-completed user edits, which is distinct from navigation not being a cancel. ADR 0028 gesture cancel and close-discard-ghosts are not re-qualified. A Flutter widget tree, WorkflowCoordinator, PatchGroup cherry-pick, chat workbench UI, or workspace SQLite w5 is not invented. I-013 job archival is not invented. The s9 recycle-bin / 30-day project-deletion sentences, FTS search, “clip删除后scope invalid,” ResumeBranch tool resend, fork-approval copy, and “会话恢复不会复活已撤销审批” sentences are not officialized here. Increments 3.31–3.35 already-landed slices are not re-qualified. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. Production FTS/RAG is not claimed. I-002, I-013, I-011, I-014, I-012, I-020, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, I-027, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s9 states that switching sessions must not cancel a running job or reset the playhead, and that a user leaving the screen is not a cancel. Nearby s9 sentences about recycle-bin recovery, FTS, scope invalid, resume/fork approvals, and session restore not reviving revoked approvals are not taken here.

This increment officializes only those navigation bounds as a DEV-PURE compiler at the official entry path `packages/studio_session_navigation_probe/lib/session_navigation_admission.dart`:

- `sessionNavigation` that leaves a screen or switches sessions without canceling a run or resetting the playhead is admitted (`runCancelled=false`, `playheadReset=false`).
- An unknown kind is `SESSION_NAVIGATION_KIND_UNKNOWN`.
- Leaving a screen and canceling a run is `LEAVE_SCREEN_NOT_CANCEL`.
- Switching sessions and canceling a run is `SWITCH_SESSION_NOT_CANCEL`.
- Switching sessions and resetting the playhead is `SWITCH_SESSION_NOT_RESET_PLAYHEAD`.
- `jobCancelRequalified`, `adr0028Requalified`, `licenseExecutionRequalified`, `licenseProvenanceRequalified`, `errorClassRequalified`, `dropFrameRequalified`, `llmPathRequalified`, `flutterTreeInvented`, `workflowCoordinatorInvented`, `cherryPickInvented`, `chatWorkbenchInvented`, `jobArchivalInvented`, and `recycleBinInvented` stay false.

`tools/spikes/session_navigation/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing I-005 JobCancelAdmission and ADR 0028 suites are not rewritten.

## Consequences

The s9 session-navigation bounds are officialized at this admission. I-027 remains partial; this increment does not mark I-027 complete and does not invent PatchGroup cherry-pick, a chat workbench, or workspace SQLite w5. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i027-session-navigation/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this session-navigation admission, Increment 3.04 JobCancelAdmission, or ADR 0028. Do not invent a Flutter widget tree or a WorkflowCoordinator. Do not re-qualify Increments 3.32 or 3.35 license admissions, or Increments 3.31–3.34 I-002 admissions. Do not claim the remaining I-002 measurement labels. Do not return to the exhausted I-013 packing / session / omitted-history cluster or Increments 3.27–3.30 archive-bound slices. Do not invent I-013 job archival. Do not start quote/apply or paid APIs. Remaining s9 sentences such as “删除聊天不删除时间线已引用的素材,” “project删除与session删除不同,” and “generation完成只发布candidate.ready，不执行accept” stay unofficial and should be taken only if they can be bounded without re-qualifying I-004, I-029, I-040, ADR 0018, or the recycle-bin path.
