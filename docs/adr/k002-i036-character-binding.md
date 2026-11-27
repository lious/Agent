# ADR K002 — Second I-036 @ mention, resolver, injector, and in-project materialize slice

## Status

Accepted for Increment K.2 as the second acceptable local DEV-PURE slice of I-036. Official 8E `@` mention search over the currently authorized library, `ProjectCharacterResolver`, `CharacterPromptInjector`, and in-project materialize of `Project.Character` name/constraints plus `Project.extensions["studio.character-library.v1"]` are landed in `packages/studio_assets`. I-036 remains partial. `fullTaskComplete` stays false.

## Decision

This is the next official I-036 step after Increment 2.04 / K.1 (closed Schema/DDL, library versions, project pin / local wardrobe, revoke, import-export). It is not a new planning item.

`ProjectCharacterMentionSearch` scans published `library_versions` in the current repository namespace only. A leading `@` is stripped and matching is a case-insensitive substring over name, tags, description, and look labels. This slice does not use FTS5 and does not instantiate `craft_fts`. The approved SQLite 3.54.1 binary is not replaced. After the user selects asset/version/look, `CharacterMentionSession.select` generates a `ProjectCharacterRef` and records the locked `pinnedVersion`. The session stores only the ref and selectors; pack images are not copied or uploaded.

`ProjectCharacterResolver.resolve(ProjectCharacterRef, scope, liveRights)` returns a `ResolvedCharacter` for the pinned pack and selected look. Legal overrides may only fold wardrobe / era / stateDescription / hairStyle into the effective appearance. Selected reference refs are library-side `EntityRef` values (reference id + pinned pack version), not project Asset ids. `voicePlanRef` is always null in this slice; voice cloning (I-049 / I-050) is not opened. Live permission is not frozen by the pin: a revoked store row fails closed as `RIGHTS_REVOKED`, including when a stale allow snapshot is supplied.

`CharacterPromptInjector.compile(resolvedCharacter, shot, providerCapability)` returns a `CharacterBindingPlan` that injects only this shot's effective appearance, wardrobe, action, and anti-drift constraints, not the whole character encyclopedia. If the provider has only one first-frame slot and a character reference would conflict with a product first-frame, the injector throws `REFERENCE_SLOT_CONFLICT` and does not silently drop either side. Identity consistency is always `IDENTITY_SOFT_CONSTRAINT`. The plan never marks a pixel lock.

`ProjectCharacterMaterializer` writes `name` and `constraints` onto the in-project `Project.Character` entity and stores only `refs` / `portablePackHashes` (plus closed `schemaVersion`) under `Project.extensions["studio.character-library.v1"]`. `Character.version` is the in-project entity version and is incremented independently of the external `pinnedVersion`. No new Project root table is added, already-closed Character fields are not changed, and the core project store `user_version` is not bumped to v10.

`appearanceRef` is written only when an already-admitted project Asset `EntityRef` is supplied and present in `project.assets`. A bare Asset ID from the external character library is refused. Attaching a library reference blob as a project Asset would require I-004 `AssetRepository`, `RelinkProposal`, and `FileToken`. Those surfaces are not invented here. When no admitted project Asset is supplied, `appearanceRef` stays null and the result lists those missing surfaces.

This increment does not open offline lease, real-person online cloud rights checks, library GC, I-049, I-050, LoRA training or weight download, I-037, remaining I-010 items, I-046, or I-055. Fictional characters and synthetic rights records only.

New official suite: `packages/studio_assets/test/assets/character_versions/i036_character_binding_test.dart` (6). The frozen 2.04 suite `i036_character_pack_library_test.dart` (7) is not rewritten. Selected runner: `tools/acceptance/cases/i036.py`. `tools/acceptance/run_task.py` routing is not changed.

## Consequences

I-036 remainingAcceptance stays empty (the four 2.04 / K.1 clauses remain officialized at the library/pin/rights/import-export bound). remainingScope is narrowed: `@` mention search, resolver, injector, and name/constraints/extension materialize are now in implementedScope. appearanceRef attach of library reference blobs, offline lease / online realPerson cloud checks, library GC, I-049/I-050, LoRA training/download, and craft_fts on this frozen SQLite build remain listed. I-036 stays partial. 87-task counts stay 0 complete / 27 partial / 47 planned / 13 blocked.

C.1–C.3, A.1, M.1–M.3, Increment 2.00, and Increment 2.04 / K.1 evidence hashes are not modified. The frozen native library is not touched. Official 505 and Increments 1.83–2.05 / C.1–C.3 / A.1 / K.1 new-counts are not mixed into this increment's new-count of 6 tests (studio_assets).

## Evidence

`docs/implementation/evidence/i036-character-binding/`.
