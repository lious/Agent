# ADR 0238 — Official s9 project deletion and session deletion are different kinds

## Status

Accepted for Increment 3.39 as a distinct already-specified s9 leftover, looked up more broadly after I-013 packing / archive slices, I-002 measurement claims, Increments 3.32 / 3.35 license leftovers, Increment 3.36 session-navigation, and Increments 3.37 / 3.38 s10 leftovers: project deletion and session deletion are different kinds and must not be treated as each other. This sentence sits in the s9 归档/删除/恢复 row, not in the session-navigation sentences officialized in Increment 3.36. This is not an I-013 packing or archive slice, not an I-002 measurement claim, not a license leftover already officialized in Increments 3.32 or 3.35, not a session-navigation leftover already officialized in Increment 3.36, and not a model-context or offline-capability leftover already officialized in Increments 3.37 or 3.38. Existing I-027 remainingAcceptance wording (including the Increment 3.36 append) is kept at the start and is not silently rewritten or cleared; a delete-kind note is appended only. The project-deletion recycle-bin path and the 30-day figure are not officialized and are not claimed as a measured timer. A recycle-bin runtime or countdown timer is not invented. Increment 3.28 ArchiveCountdownAdmission is not re-qualified: that bound is that a library or portable archive must not start the project-deletion recycle-bin countdown, which is distinct from session delete and project delete being different kinds. Increment 3.36 SessionNavigationAdmission is not re-qualified. I-004 remainingAcceptance labels, I-029 DeletionBarrier, and ADR 0018 are not re-qualified and their task-status is not rewritten. “删除聊天不删除时间线已引用的素材,” “generation完成只发布candidate.ready，不执行accept,” “会话恢复不会复活已撤销审批,” FTS search, scope invalid, and resume/fork approval copy are not officialized here. I-013, I-002, I-030, and I-034 remainingAcceptance wording is not rewritten. I-033, I-058, I-053, I-004, I-005, I-029, and I-040 task-status are not rewritten. Increments 3.31–3.38 already-landed slices are not re-qualified. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. I-002, I-013, I-027, I-034, I-030, I-011, I-014, I-012, I-020, I-003, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s9 states that project deletion and session deletion are different. Nearby sentences about not deleting timeline-referenced media when deleting a chat, recycle-bin recovery, session restore not reviving revoked approvals, and generation complete only publishing `candidate.ready` are not taken here.

This increment officializes only that kind distinction as a DEV-PURE compiler at the official entry path `packages/studio_delete_kind_probe/lib/delete_kind_admission.dart`:

- `deleteKind` with matching `target` and `treatedAs` of `session` or `project` is admitted (`sessionTreatedAsProject=false`, `projectTreatedAsSession=false`).
- An unknown kind, target, or treatedAs is `DELETE_KIND_UNKNOWN`.
- Treating a session delete as a project delete is `SESSION_DELETE_NOT_PROJECT`.
- Treating a project delete as a session delete is `PROJECT_DELETE_NOT_SESSION`.
- `sessionNavigationRequalified`, `archiveCountdownRequalified`, `i004Requalified`, `i029Requalified`, `adr0018Requalified`, `recycleBinInvented`, `countdownTimerInvented`, `thirtyDayClaimed`, `jobArchivalInvented`, `flutterTreeInvented`, `offlineCapabilityRequalified`, and `modelContextRequalified` stay false.

`tools/spikes/delete_kind/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing I-027 SessionNavigationAdmission, Increment 3.28, I-004, and I-029 suites are not rewritten.

## Consequences

The s9 project-versus-session delete-kind bound is officialized at this admission. I-027 remains partial; this increment does not mark I-027 complete and does not invent PatchGroup cherry-pick, a chat workbench, workspace SQLite w5, or a recycle-bin runtime. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i027-delete-kind/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this delete-kind admission, Increment 3.36 SessionNavigationAdmission, or Increment 3.28 ArchiveCountdownAdmission. Do not invent a recycle-bin runtime or claim the 30-day figure as a measured timer. Do not officialize “删除聊天不删除时间线已引用的素材” if that would re-qualify I-004 or “保留策略不删可达blob.” Do not officialize “generation完成只发布candidate.ready，不执行accept” if that would re-qualify I-040. Do not take “会话恢复不会复活已撤销审批” (ADR 0018). Do not re-qualify Increments 3.32 or 3.35 license admissions, Increment 3.37 ModelContextAdmission, or Increment 3.38 OfflineCapabilityAdmission. Do not claim the remaining I-002 measurement labels. Do not return to the exhausted I-013 packing / session / omitted-history cluster or Increments 3.27–3.30 archive-bound slices. Do not invent I-013 job archival. Do not start quote/apply or paid APIs.
