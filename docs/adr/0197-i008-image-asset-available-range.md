# ADR 0197 — Document-semantics repair: image asset clips are not refused by video availableRange (I-008 leftover)

## Status

Accepted for Increment 2.98 as the narrowly scoped later document-semantics repair called out after Increment 2.96: an `Asset.kind=image` clip with `streamId=null` is not refused by video stream `availableRange` lookup in `project_semantics.dart`. I-008 stays partial and is not marked complete. Frozen I-008 suites are not rewritten. Increment 2.96 StillImageClipAdmission is not re-qualified and is not rewritten. ADR 0108 Ken Burns transform keyframes and I-026 leftovers are not re-qualified. An unregistered plugin is not invented. A V-003 measurement is not claimed. Increment 2.97 RenderNodeGraphAdmission, Increment 2.90 RenderRecipeAdmission, and Increment 2.92 PreviewExportConsistencyAdmission are not re-qualified. A FrameLease is not invented. `local_admission.dart` is not rewritten; write-path stream lookup and `VIDEO_STREAM_REQUIRED` for non-audio assets remain unopened in this slice. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. Increments 2.74–2.97 already-landed slices are not re-qualified. I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. No paid API is called. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s4 requires that an image Asset clip uses `streamId=null` and a synthesized `[0, Clip.duration)` static 1x domain, and must not be refused by video `availableRange` rules. Increment 2.96 officialized that bound at `StillImageClipAdmission`. Document semantics still applied video stream lookup to every `source.kind=asset` clip, so an `Asset.kind=image` clip with `streamId=null` was `SOURCE_STREAM_MISMATCH`.

This increment repairs only that document-semantics path in `packages/studio_document/lib/project_semantics.dart`:

- When the referenced asset is `kind=image` and `streamId` is null, video stream `availableRange` lookup is not applied.
- A non-null `streamId` on an image asset clip is still `SOURCE_STREAM_MISMATCH`.
- Video and audio asset clips keep the existing stream-matching and `SOURCE_OUT_OF_RANGE` rules.

Official tests are `packages/studio_document/test/media/still/i008_image_asset_available_range_test.dart`. Frozen I-008 suites, Increment 2.96 probe tests, and `local_admission.dart` are not rewritten.

## Consequences

Document validation no longer refuses a well-formed image asset still clip by video `availableRange` lookup. The write-path in `local_admission.dart` still looks up a stream for every asset clip and still requires a video stream on non-audio assets; that path is not this slice and is not claimed. I-008 stays partial. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i008-image-asset-available-range/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this semantics repair, Increment 2.96 StillImageClipAdmission, ADR 0108 Ken Burns, or frozen I-008 suites. A later write-path repair in `local_admission.dart` so image asset clips are not refused by stream lookup / `VIDEO_STREAM_REQUIRED` may be taken only if it does not rewrite frozen I-008 suites or Increment 2.96.
