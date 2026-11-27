# ADR 0196 — Official s4 RenderNode closed-union protocol (I-022 leftover)

## Status

Accepted for Increment 2.97 as a distinct already-specified s4 leftover on I-022: RenderNode is a closed union; each node must publish extent, pixelFormat, color, and alphaMode; the graph is acyclic; node fingerprints participate in the cache key, which must not be only the source filename. I-022 stays partial and is not marked complete. A V-003 pixel, duration, or seek measurement is not claimed. A FrameLease, muxer, and LUT runtime are not invented. `decoderLease` and `lutHash` are identity fields from the closed union, not a FrameLease or LUT runtime, and not the I-022 leftover “free only after GPU/encoder consume / 100-cancel no frame leak”. Increment 2.90 RenderRecipeAdmission and Increment 2.92 PreviewExportConsistencyAdmission are not re-qualified and are not rewritten. Increment 2.96 StillImageClipAdmission and ADR 0108 Ken Burns are not re-qualified. `project_semantics.dart` is not rewritten. I-024 export suites and Increment 2.72 ExportService are not rewritten. This is not `PREVIEW_SCREENSHOT_NOT_EXPORT`. ADR 0023/0024 CPU consumers are not re-qualified. Increments 2.74–2.96 already-landed slices are not re-qualified. CompatibilityStore / ModelLease are not started. I-061, I-055, I-059, I-060, I-035, and V-024 stay planned or closed as already recorded. I-008, I-010, I-023, I-022, V-006, I-021, I-004, I-005, I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, I-058, V-004, I-024, V-005, V-002, I-007, I-042, and V-023 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. `run_probe.py` and `run_qualification.py` are not opened as a claimed qualification.

## Decision

s4 “RenderNode封闭联合” requires a closed union of `SourceNode`, `ImageNode`, `ColorNode`, `EffectNode`, `CompositeNode`, `TextNode`, `AudioMixNode`, and `OutputNode`, each with the listed identity fields; node outputs `extent`, `pixelFormat`, `color`, and `alphaMode` are required; the graph is acyclic; node fingerprints participate in `cacheKey`, which must not be only the source filename.

This increment officializes that bound as a DEV-PURE compiler at the official entry path `packages/studio_render_node_probe/lib/render_node_graph_admission.dart`:

- A closed-union acyclic graph with required outputs, whose cache key contains every node fingerprint, is admitted (`closedUnion`, `acyclic`, `fingerprintInCacheKey`).
- An unknown kind is `RENDER_NODE_UNKNOWN`.
- A missing kind-specific identity field is `RENDER_NODE_IDENTITY_REQUIRED`.
- A missing output field is `RENDER_NODE_OUTPUT_REQUIRED`.
- A cycle is `RENDER_GRAPH_CYCLE`. An unknown input id is `RENDER_GRAPH_INPUT_UNKNOWN`.
- A filename-only cache key, or a key that omits a node fingerprint, is `CACHE_KEY_FILENAME_ONLY`.
- This is not a renderer, V-003 off-screen golden, or FrameLease.
- `v003Claimed`, `frameLeaseInvented`, `lutRuntimeInvented`, `renderRecipeRequalified`, `previewExportRequalified`, `stillImageRequalified`, `muxerInvented`, `i024Rewritten`, and `paidApiCalled` stay false.

A renderer, FrameLease, and LUT runtime remain unopened. `tools/spikes/render_node_union/README.md` points at the Dart admission; `run_probe.py` and `run_qualification.py` are not opened.

## Consequences

The s4 “RenderNode封闭联合” protocol bound is officialized at this admission. V-003 tolerance sampling, free-only-after-GPU/encoder-consume, and 100-cancel no-frame-leak stay unclaimed, so I-022 stays partial and is not marked complete. 87-task counts stay 0 complete / 62 partial / 12 planned / 13 blocked. T-4 and the overall program stay not done.

## Evidence

`docs/implementation/evidence/i022-render-node-union/`.

## Follow-up

The next increment should pick a still-doable leftover that is not already officialized and does not invent a deferred runtime. Do not re-qualify this RenderNode closed-union admission, Increment 2.90 RenderRecipeAdmission, or Increment 2.92 PreviewExportConsistencyAdmission. Do not invent a FrameLease, and do not claim a V-003 measurement. I-022’s remaining leftovers (V-003 tolerance sampling, free only after GPU/encoder consume, 100-cancel no frame leak) are not a clean next slice. A later document-semantics repair so `Asset.kind=image` clips are not refused by video stream `availableRange` lookup may be taken only if it does not rewrite frozen I-008 suites and does not re-qualify Increment 2.96 StillImageClipAdmission.
