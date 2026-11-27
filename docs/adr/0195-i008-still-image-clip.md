# ADR 0195 — Official s4 still-image clip source domain (I-008 leftover)

## Status

Accepted for Increment 2.96 as a distinct already-specified s4 leftover on I-008: an `imageDocument` or image Asset clip has `streamId=null`, a synthesized `[0, Clip.duration)` static sampling domain, and linear 1x, and must not be refused by video `availableRange` rules. I-008 stays partial and is not marked complete. ADR 0108 Ken Burns transform keyframes are not re-qualified; Ken Burns remains transform keyframes, not video generation, and is not rewritten here. I-026 leftovers (I-004 asset attach, V-003 image render qualification, Flutter widget tree) are not re-qualified. I-008 leftover-acceptance and transform keyframe suites are not rewritten. A V-003 measurement is not claimed. An unregistered I-008 effect plugin is not invented. Increment 2.95 SystemFontLineBreakAdmission, Increment 2.94 CaptionSafeAreaAdmission, and I-010 sidecar/font-fallback work are not re-qualified. A text shaper is not invented. Source-interval crop and MP4/preview burn-in stay closed. Increments 2.74–2.95 already-landed slices are not re-qualified. CompatibilityStore / ModelLease are not started. I-061, I-055, I-059, I-060, I-035, and V-024 stay planned or closed as already recorded. I-010, I-023, I-022, V-006, I-021, I-004, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s4 EffectRegistry@1 “静态图/图片文档Clip” requires that when `source.kind` is `imageDocument` or an image Asset, `streamId` is null, `sourceRange` is the synthesized static sampling domain `[0, Clip.duration)`, the time map is linear 1x, and video `availableRange` rules must not refuse the still. The same row states that Ken Burns is transform keyframes, not video generation; that bound is already official in ADR 0108 and is not re-qualified here.

This increment officializes the still-source bound as a DEV-PURE compiler at the official entry path `packages/studio_still_image_clip_probe/lib/still_image_clip_admission.dart`:

- An `imageDocument` or image (`sourceKind=image`) clip with `streamId=null`, linear 1x, and a static `[0, Clip.duration)` domain is admitted.
- A non-null `streamId` is `SOURCE_STREAM_MISMATCH`.
- Applying video `availableRange` rules to a still is `VIDEO_AVAILABLE_RANGE_ON_STILL`.
- A non-1x time map, or a source range that is not the synthesized static domain, is `STATIC_SOURCE_DOMAIN_INVALID`.
- A source kind other than `image` or `imageDocument` is `STILL_IMAGE_KIND_REQUIRED`.
- `kenBurnsRequalified`, `i026Requalified`, `i008KeyframeRequalified`, `videoGenerationInvented`, `v003Claimed`, `unregisteredPluginInvented`, and `paidApiCalled` stay false.

This admission does not rewrite `project_semantics.dart`. Existing document semantics already require a null `streamId` for non-asset sources including `imageDocument`, and do not apply stream `availableRange` to `imageDocument`. Asset clips, including `Asset.kind=image`, still go through video stream lookup today; this slice officializes the protocol bound and does not silently repair that asset path. A document-semantics repair remains a possible follow-up and is not started here.

A renderer and a video generator remain unopened. `tools/spikes/still_image_clip/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s4 still-image clip source-domain bound is officialized at this admission. Unregistered plugins and V-003 stay unclaimed, so I-008 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i008-still-image-clip/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this still-image clip admission, ADR 0108 Ken Burns transform keyframes, or I-026 leftovers. Do not invent an unregistered plugin or claim a V-003 measurement. A document-semantics repair so `Asset.kind=image` clips are not refused by video stream `availableRange` lookup may be a later slice, and must not rewrite frozen I-008 suites if taken.
