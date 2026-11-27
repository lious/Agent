# ADR K001 — First I-036 CharacterPack / Voice / Rights library slice

## Status

Accepted for Increment K.1 as the first acceptable local DEV-PURE slice of I-036. Official 8G CharacterPack / ProjectCharacterRef schemas and T57 library DDL, CharacterRepository, library versions, project pins, PortraitRights records, and pack import/export are landed in an isolated `packages/studio_assets` library workspace. I-036 remains partial. `fullTaskComplete` stays false.

## Decision

I-036 was planned / notStarted. This increment implements the work-item first slice: closed Schema/DDL, CharacterRepository, library version plus project pin, and rights import/export, against fictional characters and synthetic rights records only.

The official 8G schemas are copied unchanged from `docs/studio/reference/t57Schemas.json` / spec 8G. The official T57_LIBRARY_DDL text is copied unchanged. It is applied as library workspace w5 → w6 on a dedicated library database. This does not write or increment the core project store `user_version` (frozen at 9). Events and outbox stay on the original project store and are not reimplemented.

The official DDL text includes `CREATE VIRTUAL TABLE craft_fts USING fts5`. The approved SQLite 3.54.1 library in this checkout is compiled without `SQLITE_ENABLE_FTS5`. That virtual table is not instantiated, and the approved SQLite binary is not replaced or recompiled. I-037 craft FTS is not opened.

CharacterRepository follows the 8E API for createDraft / publish / forkVersion / exportPack / importPack. Publish is CAS-checked against `expectedHeadVersion` and fails closed as `HEAD_CONFLICT` with no half-published version. Published `library_versions` rows are immutable (`IMMUTABLE_VERSION`). Project pins record a pinned pack hash; publishing a later library head does not rewrite existing pins. CharacterUpgradePlanner may retain only wardrobe / era / stateDescription / hairStyle overrides and copies locked hand-edited captions and trims through unchanged. After `revoke`, live rights become `revoked`, derived cache entries are invalidated, and new generation plus cache hits are 0. Historical pack bytes are retained (`existingOutputsPolicy` is not a delete). Cross-App import rebuilds local IDs, validates pack hash and body schema, exports only rights declaration snapshots, and leaves live rights `unknown` until the receiving App records its own decision. Source-App approvals are not inherited; a revoke in one namespace does not rewrite the other.

Import admits only the 8E-specified rebuild-local-ID-mapping policy (`rebuildLocalIdMapping`). Other collision policies are not invented.

This increment does not open closed I-010 items, I-046, I-055, I-049, I-050, I-007, I-016/I-017/I-018, a full I-019 port, I-020, I-026, or I-060. It does not promise LoRA across base models or absolute identity lock, does not train or download weights, and does not call paid APIs. `@` mention search, CharacterPromptInjector, Project.Character materialize, offline lease / online realPerson cloud checks, and library GC remain unopened.

New official suite: `packages/studio_assets/test/assets/character_versions/i036_character_pack_library_test.dart` (7). Selected runner: `tools/acceptance/cases/i036.py`. `tools/acceptance/run_task.py` routing is not changed.

## Consequences

The four I-036 remainingAcceptance clauses — 全局升级不改旧项目pin；撤销后新生成/缓存命中=0；手调剪辑字幕不覆盖；跨App权限独立 — are officialized at this library / pin / rights / import-export bound. “手调剪辑字幕不覆盖” is officialized at CharacterUpgradePlanner and project-pin upgrade: locked caption and trim state passed into the planner is not written. This does not open I-010 source-interval crop, MP4/preview burn-in, or a new caption persist path.

I-036 remainingAcceptance is cleared for those four clauses. remainingScope stays listed. I-036 stays partial.

C.1–C.3, A.1, M.1–M.3, and Increments 1.83–2.00 evidence hashes are not modified. I-005 leftover section-3 rows, I-006 empty remainingAcceptance, I-007, I-008 leftovers, I-011 leftovers, I-012 leftovers, I-013 leftovers, I-014 leftovers, I-015 leftovers, I-021 leftovers, I-022 remainingAcceptance, I-024 remainingAcceptance, I-025 leftovers, I-027 leftovers, I-032 leftovers, and V-005 remainingAcceptance including 「durableRevision零丢失」 stay listed and are not silently cleared. Planned I-026 and I-020 are not started. I-016/I-017/I-018 and a full I-019 VAAPI port are not started. SQLite schema is not expanded to v10.

## Evidence

`docs/implementation/evidence/i036-character-pack-library/`.
