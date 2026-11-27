# ADR 0114 — I-026 ImageDocument and ten official layer templates

## Status

Accepted for Increment 2.15 as the first Linux/Web-exercisable slice of I-026 (engineering spec and art/design plan). I-026 moves from planned to partial. `fullTaskComplete` stays false. This is not V-003 image-render GPU qualification and not a template edit UI.

## Decision

`packages/studio_image_editor` lands `ImageDocument`, layered `ImageLayer` (image, graphic, text, mask, decoration), `TemplatePack` / `TemplateSlot` / `TemplateInstance`, `OfficialTemplateCatalog` of ten original templates in the photo-card, paper-collage, and brand-card families plus caption-poster and product-frame, and `TemplateService` instantiate / rebind / roundTrip / applyReferenceGrade.

Round-trip of all ten templates preserves layer count, ids, kinds, and structure hash; flattening is refused as `FLATTEN_FORBIDDEN`. Rebinding a photo slot updates the current source and leaves the original recorded hash, other text, decorations, and transforms unchanged. Batch reference grade skips locked layers. Missing fonts and effects are explicit `MISSING_FONT` / `MISSING_EFFECT` degrades and are not stripped from the layer. Inferred color cannot be written as an original-image fact; a style suggestion can be refused without mutation. The core project store `user_version` stays 9; no graphics-library SQL or Project root fields are added.

This is not a sticker product: user work remains a complete layered `ImageDocument`.

## Consequences

87-task counts become 0 complete / 33 partial / 41 planned / 13 blocked. `fullTasksCompleted` stays 0. Official new suite: 7 tests. Analyzer exit 0. Increment 2.14 evidence hashes are not modified.

## Evidence

`docs/implementation/evidence/i026-layer-templates/`.

## Follow-up

Template edit UI, graphics-library store, rights for shared packs, I-004 attach, and V-003 qualification remain open. Continue under t154u cadence without marking T-4 or the program done.
