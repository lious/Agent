# ADR 0206 — Official s5b close requests a checkpoint and must not wait or pretend an external file was written (I-012 leftover)

## Status

Accepted for Increment 3.07 as a distinct already-specified s5b leftover on I-012: background, project-switch, or close must request a checkpoint immediately and must not wait for a long generation or a ZIP; an unfinished external package must not be claimed as written; a desktop exit keeps the local recovery point; a mobile OS expiry may promise only work that already has a local ACK, not an unbounded background task. I-012 stays partial and is not marked complete. Existing I-012 remainingAcceptance wording is not silently rewritten. Increment 3.05 PackageAutoUpdateAdmission, Increment 3.06 ArtifactKindAdmission, ADR 0098 I-012 userSavedRevision leftovers, virtual-clock / coalesce / durable-receipt items already officialized in `save_test.dart`, Increment 2.73 V-005 provider-restriction admission, AtomicFilePublisher, official I-024 export suites, and ADR 0028 gesture cancel are not re-qualified and are not rewritten. A SAF or iCloud adapter and a Flutter widget tree are not invented. A finished V-005 provider qualification is not claimed. The 30s idle / 120s max-attempt figures in s5b remain design defaults and are not claimed as a measured qualification. I-013 job archival, a muxer, and an I-014 RestoreService commit path are not invented. The s5b close-path draft confirmation widget is not officialized here; ADR 0028 already covers discarding pending ghosts on close and is not re-qualified. The s5b “生成中的资源” row and remaining s3 error-table rows are not taken. Increments 2.74–3.06 already-landed slices are not re-qualified. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-013, I-012, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5b states that background, project-switch, or close must request a checkpoint immediately and must not wait for a long generation or a ZIP; that a desktop exit with an unfinished external package may wait or cancel packing, must keep the local recovery point, and must not claim the external file was written; and that a mobile OS expiry may promise only work that already has a local ACK and must not rely on an unbounded background task.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_close_checkpoint_probe/lib/close_checkpoint_admission.dart`:

- `background`, `projectSwitch`, `close`, `desktopExit`, and `mobileOsExpiry` are admitted when a checkpoint is requested immediately and the path does not wait for a long generation or a ZIP (`checkpointRequested=true`, `externalFileWritten=false`).
- Waiting for a long generation or a ZIP is `CLOSE_MUST_NOT_WAIT`.
- A close path that does not request a checkpoint immediately is `CHECKPOINT_REQUIRED_IMMEDIATELY`.
- Claiming that an unfinished external package was written is `EXTERNAL_FILE_NOT_WRITTEN`.
- A desktop exit with an unfinished package and no local recovery point is `LOCAL_RECOVERY_POINT_REQUIRED`.
- An unbounded background task on mobile OS expiry is `UNBOUNDED_BACKGROUND_TASK_FORBIDDEN`.
- An unknown trigger is `CLOSE_TRIGGER_UNKNOWN`.
- This does not invent a close or draft-confirmation widget, and does not rewrite Increment 3.05 package auto-update or Increment 3.06 artifact-kind admissions.
- `packageAutoUpdateRequalified`, `artifactKindRequalified`, `i012UserSavedRevisionRequalified`, `gestureCancelRequalified`, `safIcloudInvented`, `flutterWidgetTreeInvented`, `v005QualificationClaimed`, `jobArchivalInvented`, `muxerInvented`, and `i014RestoreInvented` stay false.

`tools/spikes/close_checkpoint/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s5b close-checkpoint bound is officialized at this admission. I-012 product remainingScope stays open, so I-012 stays partial and is not marked complete. Existing I-012 remainingAcceptance wording is left listed and is not silently rewritten. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i012-close-checkpoint/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this close-checkpoint admission, Increment 3.05 PackageAutoUpdateAdmission, Increment 3.06 ArtifactKindAdmission, ADR 0098 I-012 leftovers, or official I-024 export suites. Do not invent a SAF/iCloud adapter, a Flutter widget tree, I-013 job archival, or an I-014 RestoreService. Do not take s5b “生成中的资源” if that would re-qualify I-004 attach, I-013 archival, I-024, or I-040. Remaining s3 error-table rows should not be taken if they would re-qualify I-004 / Increment 2.86, I-011, or I-033.
