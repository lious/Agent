# ADR 0120 — I-026 template editor session and graphics-library store

## Status

Accepted for Increment 2.21 as the leftover I-026 Linux/Web slice after Increment 2.15's ten official layered templates. I-026 stays partial. `fullTaskComplete` stays false. This is not V-003 image-render qualification.

## Decision

A dedicated `graphics-library/1` database is opened beside the package at `store/graphics_library.sql`. Official tables `graphic_versions`, immutable-version triggers, and `graphic_heads` match the 4A contract. `workspace_features` hosts the official `graphics_library` / `1.0.0` / `graphics-library/1` row. A `studio.graphics-library.v1` pin index (`graphics_library_pins`) records project pins; this is not a Project 2.0 root field and does not change the core project store `user_version` (stays 9). The private library document number is 1.

`GraphicRepository.publish` / `search` / `renameOrRefine` officialize: expected-head CAS; numeric version comparison; namespace-first search; casefold tag dedup; empty or too-long name refusal (`NAME_REJECTED`); immutable versions (`IMMUTABLE_GRAPHIC_VERSION`). Publishing `@2` does not move existing project pins; only an explicit `upgradeProject` does. `GraphicRetention.planDelete` of a pinned version is `GRAPHIC_IN_USE`; deleting a head leaves earlier pinned versions loadable.

Shared publish requires redistributable rights (`RIGHTS_REQUIRED` otherwise). Selecting or pinning a graphic does not grant redistribution. `TemplateEditorSession` is the planned template-edit UI controller: instantiate official packs, rebind a photo without flattening or changing text/ids/transforms, allow a required empty slot as a draft, block delivery with `REQUIRED_SLOT_EMPTY`, and refuse unknown template metadata (`UNKNOWN_TEMPLATE`) for upgrade/rebind. It is not a Flutter widget tree. `TemplateService.instantiate` gained an `allowDraft` flag that defaults to false so the frozen 2.15 suite is unchanged.

Ten official templates from Increment 2.15 are not rewritten.

## Consequences

87-task counts stay 0 complete / 35 partial / 39 planned / 13 blocked. `fullTasksCompleted` stays 0. Official new suite: 8 tests. Frozen 2.15 suite (7) re-run. Analyzer exit 0.

## Evidence

`docs/implementation/evidence/i026-graphics-library-store/`.

## Follow-up

I-004 AssetRepository attach, V-003 GPU image-render qualification, and a Flutter widget tree remain open. Next honest Linux/Web increments include remaining art/workbench visual language, and further play-protocol software tests without physical two-device E2E or schema v10 / XD-010 claims.
