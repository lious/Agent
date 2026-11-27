# ADR 0162 — Official V-026 untrusted-resource refusals

## Status

Accepted for Increment 2.63 as the first V-026 slice. V-026 moves planned → partial and is not marked complete. This increment does not invent a glTF runtime and does not claim preview consistency or the V-026=gltf-preview gate. I-061 stays planned; writing this ADR does not start or complete I-061. NeRF/3DGS training and editing stay closed. I-039 and I-038 leftovers are not re-qualified. I-035 stays planned. I-055 is not started. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, and I-039 stay partial and are not marked complete. V-009, V-016, V-017, V-018, V-019, V-021, and V-022 stay blocked. V-003 leftovers are not re-qualified. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called.

## Decision

V-026 acceptance requires that automatic external URL fetches stay at zero, that 100 damaged inputs do not escape or crash, and that unsupported extensions are explicitly refused. s2 requires that unknown nodes are not silently dropped. A later I-061 archive must not pull external links, but I-061 is not opened here. The remaining V-026 acceptance item — three fixtures previewing and reopening from an archive consistently — is not claimed. The work-item decision is that a failed or incomplete 3D preview stays experimental, and I-061 runs only when it is explicitly taken into a version after the preview gate is met.

This increment officializes the untrusted-resource refusal bound as a DEV-PURE admission compiler in `packages/studio_gltf_probe/lib/untrusted_resource.dart`:

- `UntrustedGltfAdmission.admit` never fetches. An `http(s)`, `file`, `ftp`, `ws(s)`, protocol-relative, or path-traversal `uri` is `EXTERNAL_URL_FORBIDDEN` with `networkRequestCount=0`.
- An `extensionsRequired` or `extensionsUsed` name outside the empty first-slice allowlist is `EXTENSION_UNSUPPORTED` and is not silently dropped. An unknown top-level node is retained on the report rather than discarded, and is not executed.
- 100 damaged inputs (truncated JSON, wrong types, negative or oversize buffer lengths, explicit null collections) return `admitted=false` with `DAMAGED_INPUT` and do not escape or crash the caller.
- A local core document with only an embedded `data:` buffer may be admitted for later review, but `previewed`, `previewConsistencyClaimed`, `runtimeInvented`, `v026GltfPreviewClaimed`, and `i061Started` stay false.

A glTF renderer, library lock, feature flag, and three-fixture preview/archive round-trip remain unopened. `tools/spikes/gltf/run_probe.py` is not opened.

## Consequences

The first V-026 leftover acceptance items (external URL auto-fetch stays at zero, 100 damaged inputs do not escape or crash, and unsupported extensions are explicitly refused) are officialized at this admission bound. Preview consistency and a runtime lock remain unopened, so V-026 stays partial and is not marked complete. The V-026=gltf-preview gate is not claimed, so I-061 stays planned. 87-task counts become 0 complete / 54 partial / 20 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/v026-untrusted-resource/`.

## Follow-up

Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial work from the four planning documents. Do not invent a glTF runtime or claim preview consistency. Do not start I-061 or claim V-026=gltf-preview. Do not start I-055 unless a narrow already-specified LocaleCatalog/semantics slice is required. Do not start I-035 or claim a V-020 precision/recall achievement. Do not invent a limiter. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not re-qualify I-039, I-038, I-052, I-040, or I-033 leftovers. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, or V-026 complete.
