# ADR 0198 — Write-path repair: image asset clips are not refused by stream lookup or VIDEO_STREAM_REQUIRED (I-008 leftover)

## Status

Accepted for Increment 2.99 as the narrowly scoped later write-path repair called out after Increment 2.98: `requireLocalEditingWritable` in `local_admission.dart` no longer refuses an `Asset.kind=image` clip by stream lookup or `VIDEO_STREAM_REQUIRED`. I-008 stays partial and is not marked complete. Frozen I-008 suites are not rewritten. Increment 2.96 StillImageClipAdmission is not re-qualified and is not rewritten. Increment 2.98 document-semantics tests and `project_semantics.dart` are not rewritten. ADR 0108 Ken Burns transform keyframes and I-026 leftovers are not re-qualified. An unregistered plugin is not invented. A V-003 measurement is not claimed. Increment 2.97 RenderNodeGraphAdmission, Increment 2.90 RenderRecipeAdmission, and Increment 2.92 PreviewExportConsistencyAdmission are not re-qualified. A FrameLease is not invented. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. Increments 2.74–2.98 already-landed slices are not re-qualified. I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. No paid API is called. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s4 requires that an image Asset clip uses `streamId=null` and must not be refused by video `availableRange` / stream rules. Increment 2.96 officialized the protocol admission. Increment 2.98 repaired document semantics. The local write path still refused image assets: `FEATURE_NOT_IMPLEMENTED` for any asset kind other than video or audio, `VIDEO_STREAM_REQUIRED` for any non-audio asset without a video stream, and clip stream lookup (`REF_NOT_FOUND` / `SOURCE_OUT_OF_RANGE`) for every asset clip.

This increment repairs only that write path in `packages/studio_document/lib/local_admission.dart`:

- A ready, non-external `kind=image` asset is no longer `FEATURE_NOT_IMPLEMENTED` at the kind gate. Image assets do not carry preview proxies in this slice (same empty-`proxyRefs` rule as audio), and no image-proxy pipeline is invented.
- `VIDEO_STREAM_REQUIRED` is not applied to `kind=image`. The video-asset branch is unchanged.
- An image asset clip with `streamId=null` skips video stream `availableRange` lookup. A non-null `streamId` is `SOURCE_STREAM_MISMATCH`, not `VIDEO_STREAM_REQUIRED` or `REF_NOT_FOUND`.

Official tests are `packages/studio_document/test/media/still/i008_image_asset_local_admission_test.dart`. Frozen I-008 suites, Increment 2.96 probe tests, and Increment 2.98 semantics tests are not rewritten.

## Consequences

A well-formed image asset still clip can pass `requireLocalEditingWritable`. I-008 stays partial because unregistered plugins and V-003 remain unopened. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i008-image-asset-local-admission/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this write-path repair, Increment 2.98 document semantics, Increment 2.96 StillImageClipAdmission, ADR 0108 Ken Burns, or frozen I-008 suites.
