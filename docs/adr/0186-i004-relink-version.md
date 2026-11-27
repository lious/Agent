# ADR 0186 — Official s4 explicit-new-version relink (I-004 leftover)

## Status

Accepted for Increment 2.87 as a distinct already-specified s4 / I-004 leftover: a different hash may be adopted only as an explicit new version after duration, stream, and color differences are reviewed, and must not be auto-replaced by filename. I-004 stays partial and is not marked complete. Remaining I-004 labels (同hash多引用仅1blob、错hash重链接拒绝、撤销引用不删仍可达原件) stay listed and are not silently cleared. This increment does not rewrite `files_test`, `blob_store`, or Increment 2.86 `ProxyDeliveryAdmission`, and does not re-qualify `RELINK_HASH_MISMATCH` (that remains the refusal of a different hash as the same asset). RelinkProposal, FileToken, and AssetRepository are not invented as product surfaces. Increment 2.72 ExportService, I-024 export suites, and I-013 archive packMode are not re-qualified. A muxer and `packMode=proxyOnly` are not invented. V-003 is not claimed. Increment 2.85 recording-drift admission, Increment 2.84 VFR audio-duration admission, Increment 2.83 varispeed-and-pitch admission, Increment 2.80 media retention, and I-021 seek/VFR/PTS suites are not re-qualified. Increment 2.82 I-005 0.02s link-offset work, Increment 2.81 V-023 PressureAdmission, and Increments 2.74–2.79 are not re-qualified. CompatibilityStore / ModelLease are not started. I-059 stays planned. I-061 and I-055 are not started. I-013 stays partial. I-014 stays partial. I-035 stays planned. I-023, I-021, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` is not opened as a claimed qualification.

## Decision

s4 requires `Relink{assetId,newFileToken,expectedFingerprint}` to verify the hash, and that a different hash is allowed only as an explicit new version after duration / stream / color differences are checked, never by auto-replacing on filename.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_relink_version_probe/lib/relink_version_admission.dart`:

- A matching hash is the same asset (`newVersion=false`).
- Auto-replacing a different hash because the filename matches is `FILENAME_AUTOREPLACE_FORBIDDEN`.
- A different hash without an explicit new-version confirmation is `RELINK_VERSION_UNCONFIRMED`. This is not `RELINK_HASH_MISMATCH`.
- An explicit new version that has not reviewed duration, stream, and color differences is `RELINK_DIFFERENCES_UNREVIEWED`.
- An explicit new version with those differences reviewed is admitted as `newVersion=true`.
- `filesTestRequalified`, `proxyDeliveryRequalified`, `relinkProposalInvented`, `fileTokenInvented`, `assetRepositoryInvented`, and `paidApiCalled` stay false.

AssetRepository, RelinkProposal, and FileToken product surfaces remain unopened. `tools/spikes/relink_version/README.md` points at the Dart admission; `run_probe.py` is not opened.

## Consequences

The s4 “不同hash只允许显式新版本并检查时长/流/色彩差异，不按文件名自动替换” bound is officialized at this admission. Other I-004 labels stay listed, so I-004 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i004-relink-version/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this relink-version admission, Increment 2.86 ProxyDeliveryAdmission, `files_test` `RELINK_HASH_MISMATCH`, or invent RelinkProposal / FileToken / AssetRepository as a product surface. Do not silently clear the remaining I-004 labels unless honestly reconciling them with existing evidence.
