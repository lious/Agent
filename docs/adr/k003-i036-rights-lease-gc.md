# ADR K003 — Third I-036 offline lease, revocation gates, and library GC slice

## Status

Accepted for Increment 2.13 as the third acceptable local DEV-PURE slice of I-036. The source evidence/ADR identifier remains K.3; that label is remapped only on this feature-branch commit. Official 8E `PortraitRightsGate`, `PortraitRevocationCoordinator`, offline-lease / fresh-online-check gating for real-person new cloud generation, dispatch-time deny, existing-output policy, known-revocation denylist, and `CharacterLibraryGc` are landed in `packages/studio_assets`. I-036 remains partial. `fullTaskComplete` stays false.

## Decision

This is the next official I-036 step after Increment 2.04 / K.1 (closed Schema/DDL, library versions, project pin, revoke, import-export) and Increment 2.08 / K.2 (`@` mention, resolver, injector, in-project materialize). It is not a new planning item.

`PortraitRightsGate.evaluate(characterRef, operation, provider, region, now)` consults live authority/epoch. A project pin freezes pack content only; it never freezes permission. Fictional characters and synthetic rights continue to use the existing `PortraitRights` / epoch records. Real-person new cloud generation requires a fresh `FreshOnlineRightsCheck` when the offline lease is missing or expired. Being offline with an expired or missing lease is denied as `FRESH_ONLINE_CHECK_REQUIRED`. The check itself is an injectable port/stub; this slice does not invent an online commercial rights API and does not call a paid network service. A still-valid lease can satisfy the freshness window; a known revocation always wins, including when a lease would otherwise still have been valid.

`CharacterRepository.dispatch` is the dispatch-time gate for `referenceGeneration`, `training`, and `upload`. After `PortraitRevocationCoordinator.revoke(rightsId, expectedEpoch)`, those operations are denied as `RIGHTS_REVOKED`, derived semantic caches are cleared (post-revoke hits stay 0), in-flight candidate tasks are requested cancelled, and late arrivals are isolated. Existing user outputs are classified by `existingOutputsPolicy` as `retainAllowed`, `blockUse`, or `reviewRequired`. Revocation and GC never delete user files. Voice cloning (I-049 / I-050) is not opened; `voiceClone` is refused as `FEATURE_NOT_IMPLEMENTED`.

A known-revocation denylist records the rights id, pack hash, and evidence hash. Restoring an old pack into the same namespace, or attempting `putLiveRights(..., state: active)` for a denylisted rights id, cannot bypass the recorded revocation. Live rights on the restored import stay `revoked`.

`CharacterLibraryGc` treats project pins, export pins, and candidate-task pins as GC roots. `exportPack` records an export pin. `deleteHead` removes the library head pointer and does not delete `library_versions` still referenced by old projects. A version may be recycled only when it has zero GC-root references and is not in a retain or revocation-cleanup plan. The current head must be deleted first (`HEAD_PRESENT`). A revocation-cleanup hold is retryable: physical GC may be attempted again after the plan is released. These ledgers are library-workspace application tables; they are not official T57 DDL, not Project root tables, and they do not bump the library workspace number (stays 6) or the core project store `user_version` (stays 9). Closed Character fields are unchanged.

This increment does not invent I-004 `AssetRepository`, `RelinkProposal`, or `FileToken`, and does not attach library reference blobs as project Assets. It does not open I-049, I-050, LoRA training or weight download, `craft_fts` / FTS5, or replace frozen SQLite 3.54.1.

New official suite: `packages/studio_assets/test/assets/character_versions/i036_character_rights_lease_test.dart` (6). The frozen 2.04 suite `i036_character_pack_library_test.dart` (7) and the frozen 2.08 suite `i036_character_binding_test.dart` (6) are not rewritten. Selected runner: `tools/acceptance/cases/i036.py`. `tools/acceptance/run_task.py` routing is not changed.

## Consequences

I-036 remainingAcceptance stays empty (the four 2.04 / K.1 clauses remain officialized). remainingScope is narrowed: offline lease / real-person fresh-online-check gating, dispatch-time revoke, existing-output policy, and library GC are now in implementedScope. appearanceRef attach of library reference blobs, I-049/I-050, LoRA training/download, and craft_fts on this frozen SQLite build remain listed. The fresh online check remains a stub/port; no paid or commercial rights API is connected. I-036 stays partial. 87-task counts stay 0 complete / 27 partial / 47 planned / 13 blocked.

C.1–C.3, A.1, M.1–M.3, Increment 2.00, Increment 2.04 / K.1, and Increment 2.08 / K.2 evidence hashes are not modified. The frozen native library is not touched. Official 505 and Increments 1.83–2.09 / C.1–C.3 / A.1 / K.1 / K.2 new-counts are not mixed into this increment's new-count of 7 tests (studio_assets).

## Evidence

`docs/implementation/evidence/i036-rights-lease/`.

## Follow-up

Independent verification of `71a67dc` required an arrival/completion gate: `revoke` already cancels in-flight `processing` pins and isolates already-`ready` pins, but a result that arrives after revoke must also be isolated and must not be accepted as a normal ready output. `PortraitRevocationCoordinator.arriveCandidateResult` is that gate. The official suite adds one case (processing → revoke becomes cancelled → late arrival is isolated, not ready). The valid-lease offline dispatch behavior is unchanged. `CharacterLibraryGc.recycle` still only removes metadata/index rows and does not claim CAS physical reclamation.

The feature-branch commit replays unique source range 3c45983..cb05ec8 onto 076e620. Source-freeze hashes describe the source clone, not these documentation splices.
