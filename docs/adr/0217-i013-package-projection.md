# ADR 0217 — Official s5c package projection is not a second source of truth and must not overwrite the snapshot body (I-013 leftover)

## Status

Accepted for Increment 3.18 as a distinct already-specified s5c leftover on I-013: `models/references`, index, and thumbnail are snapshot projections, not a second source of truth; a mismatch with the real snapshot must fail rebuild as `PACKAGE_PROJECTION_MISMATCH`; and a projection must not overwrite the snapshot body. I-013 stays partial and is not marked complete. Existing I-013 remainingAcceptance wording (运行job归档固定rev并报告pending still unofficial, Increment 2.50 unpackable-manifest / packMode, 取消无半包发布, 保留策略不删可达blob, Increment 3.06 ArtifactKindAdmission) is not silently rewritten or cleared. Increment 2.50 packMode / sourceCompleteness, Increment 3.06 ArtifactKindAdmission, `MANIFEST_SNAPSHOT_MISMATCH` in `project_archive.dart`, and “missing models must not auto-download” are not re-qualified. The PENDING_MEDIA / RESOURCE_MISSING “do not mislabel a complete archive or final render” half of the same s5c row is not officialized here, because it would re-qualify Increment 2.50 packMode / sourceCompleteness. Job archival, a muxer, a Flutter widget tree, and an I-014 RestoreService are not invented. Increment 3.17 WebPublicationAdmission, Increment 2.37 / ADR 0136, a 60s WebCodecs/OPFS roundtrip, and a V-007 production lock are not re-qualified or claimed. I-014 “ID重映射” is not taken. Schema v10 is not merged. Project `user_version` stays 9. InversePatch kind stays `restoreSnapshot`. I-020, I-014, I-011, I-003, I-012, I-013, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5c states that `PENDING_MEDIA` and `RESOURCE_MISSING` may save an incomplete project with a manifest and must not be mislabeled as a complete archive or final render, and that a projection that disagrees with the real snapshot must fail rebuild and must not overwrite the snapshot body. s5a states that `models/references.json`, index, and thumbnail are snapshot projections, not a second source of truth, and that inconsistent mirror fields report `PACKAGE_PROJECTION_MISMATCH`. The PENDING_MEDIA / RESOURCE_MISSING complete-archive sentence and “missing models must not auto-download” are not taken here.

This increment officializes only the projection-versus-snapshot bound as a DEV-PURE compiler at the official entry path `packages/studio_package_projection_probe/lib/package_projection_admission.dart`:

- `modelsReferences`, `index`, and `thumbnail` are admitted as projections that are not a second source of truth (`projectionIsNotTruth=true`, `snapshotBodyPreserved=true`).
- An unknown kind is `PACKAGE_PROJECTION_KIND_UNKNOWN`.
- A projection that does not match the real snapshot is `PACKAGE_PROJECTION_MISMATCH`.
- Overwriting the snapshot body with a projection is `SNAPSHOT_BODY_OVERWRITE_FORBIDDEN`.
- `packModeRequalified`, `artifactKindRequalified`, `manifestSnapshotMismatchRequalified`, `modelsAutoDownloadRequalified`, `pendingMediaCompleteArchiveRequalified`, `webPublicationRequalified`, `jobArchivalInvented`, `muxerInvented`, `restoreInvented`, and `flutterWidgetTreeInvented` stay false.

`tools/spikes/package_projection/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened. Existing `project_archive.dart` and `i013_unpackable_manifest_test.dart` are not rewritten.

## Consequences

The s5c package-projection bound is officialized at this admission. I-013 remainingAcceptance job-archival, packMode, cancel, retention, and artifact-kind wording stay listed, so I-013 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i013-package-projection/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this package-projection admission, Increment 2.50 packMode, Increment 3.06 ArtifactKindAdmission, or `MANIFEST_SNAPSHOT_MISMATCH`. Do not invent job archival, a muxer, or an I-014 RestoreService. Do not take the PENDING_MEDIA complete-archive sentence if that would re-qualify Increment 2.50. Do not re-qualify Increment 3.17 WebPublicationAdmission or Increment 2.37 / ADR 0136, and do not claim a 60s WebCodecs/OPFS roundtrip or a V-007 production lock. Do not take I-014 “ID重映射” or invent a RestoreService for “旧版本恢复新rev.” s5b Save As / named-version may be considered only if it can be bounded without re-qualifying `CHECKPOINT_NAME_EXISTS`, fork-new-projectId, Increment 3.10 ExplicitSaveAdmission, or Increment 3.11 CheckpointIdentityAdmission.
