# ADR 0216 — Official s5c web external download and file handle are independent publication and must not reuse POSIX semantics (I-020 leftover)

## Status

Accepted for Increment 3.17 as a distinct already-specified s5c leftover on I-020: an external download or file handle is an independent publication and must not reuse POSIX semantics. I-020 stays partial and is not marked complete. Existing I-020 remainingAcceptance labels (60秒roundtrip时长≤1帧误差, 同工程与原生金样命令语义一致) are not silently rewritten or cleared, and those measurements are not claimed. Increment 2.37 / ADR 0136 WebMediaPort codec refusal, the official s5c OPFS eviction hint, and “canceling a file picker is not a save” are not re-qualified. A real OPFS/IndexedDB runtime, a StoragePort runtime, and a Flutter widget tree are not invented. A 60s WebCodecs/OPFS roundtrip and a V-007 production lock are not claimed. ffmpeg.wasm is not made the default, and native FFmpeg is not invented as a general Web path. `apps/studio_web` is not rewritten. Workspace SQLite w5 is not merged. Increment 3.16 FutureMajorAdmission, Increment 3.15 IdentityCollisionAdmission, and an I-014 RestoreService are not re-qualified or invented. I-014 “ID重映射” was surveyed and is not officialized here, because the registered-fork remapper, no text-guessing, preserved hashes/pins, and no job-resume binding bounds are already official in ADR 0017 / ADR 0018 and must not be re-qualified. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. I-014, I-011, I-003, I-012, I-013, I-005, I-026, I-040, I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, I-020, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s5c states that the running database and CAS use a selected browser-supported OPFS/IndexedDB transaction after capability probe; that an external download or file handle is an independent publication and must not reuse POSIX semantics; that a missing persist grant shows the official eviction hint; that canceling a file picker is not a save; and that concrete browser crash/flush guarantees still require per-version acceptance. The persist-hint and cancel-picker clauses are already official in Increment 2.37 / ADR 0136 and are not re-qualified. A real OPFS/IndexedDB runtime and a measured browser crash/flush qualification are not taken.

This increment officializes only the independent-publication bound as a DEV-PURE compiler at the official entry path `packages/studio_web_publication_probe/lib/web_publication_admission.dart`:

- `externalDownload` and `fileHandle` are admitted as independent publication (`independentPublication=true`, `posixSemantics=false`).
- An unknown kind is `WEB_PUBLICATION_KIND_UNKNOWN`.
- Claiming POSIX replace+fsync / `localDurable` semantics for that path is `POSIX_SEMANTICS_NOT_REUSED`.
- `webMediaPortRequalified`, `v007Claimed`, `sixtySecondRoundtripClaimed`, `opfsRuntimeInvented`, `storagePortInvented`, `flutterWidgetTreeInvented`, `futureMajorRequalified`, `i014RestoreInvented`, and `ffmpegWasmDefaulted` stay false.

`tools/spikes/web_publication/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s5c web independent-publication bound is officialized at this admission. I-020 remainingAcceptance measurement labels stay listed, so I-020 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i020-web-publication/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this web-publication admission, Increment 2.37 / ADR 0136 WebMediaPort, or claim a 60s WebCodecs/OPFS roundtrip or a V-007 production lock. Do not invent an OPFS/IndexedDB runtime or a StoragePort runtime. Do not re-qualify Increment 3.16 FutureMajorAdmission, “不支持feature只读保留”, Increment 3.15 IdentityCollisionAdmission, Increment 2.51, or already-official I-014 conclusions. Do not invent an I-014 RestoreService. I-014 “ID重映射” should not be taken if that would re-qualify ADR 0017 / ADR 0018 registered-fork remapping. “旧版本恢复新rev” must not be taken by inventing a RestoreService. Do not take the restricted s5c DISK_FULL, OPFS runtime, or IO_ERROR / PUBLICATION_UNCERTAIN rows if that would re-qualify I-011 unique-copy, V-007, or AtomicFilePublisher.
