# ADR 0169 — Official I-058 unverified-feature and store-release gate protocol

## Status

Accepted for Increment 2.70 as the first I-058 slice. I-058 moves planned → partial and is not marked complete. The V-022=public-release gate is not met and is not claimed; V-022 stays blocked. Store-release is not claimed as passed. This increment does not invent a payment vendor, IAP, store registration, a deployed receipt verifier, or a signed store bundle. I-053 leftovers are not re-qualified. I-055 is not started and stays planned. I-059 stays planned until V-006=advanced-color numeric and appearance qualifications are honestly met. I-061 stays planned. I-049, I-050, I-028, I-042, V-006, I-054, I-056, V-007, I-001, I-011, and I-012 leftovers are not re-qualified. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, and V-006 stay partial and are not marked complete. V-009, V-010, V-012, V-013, V-014, V-015, V-016, V-017, V-018, V-019, and V-021 stay blocked or unclaimed as already recorded. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. No paid API is called. A limiter is not invented. V-003 stays unclaimed.

## Decision

s13 states that a passing synthetic test does not mean the app is complete, and must not be used to present a real device, model, or store capability as already supported. The I-058 work item requires that unverified capabilities are not shown as supported, that a paid release also satisfies I-053, that optional capabilities are not forced online, and that a commercial-license warning is not turned into a hard block for this task — and also does not exempt the V-022 public-release gate.

This increment officializes that bound as a DEV-PURE compiler in a new workspace package `packages/studio_release_probe`, entry file `lib/release_qualifier.dart`. `tools/release/qualify/README.md` points at this admission. `run_qualification.py` is not opened. I-055 is not started. Offline dual-app isolation (I-001 leftover) and durable-edit zero-loss (I-011 / V-005 leftover) are not re-qualified in this slice.

- `preview` refuses any unverified or deferred feature that is `displayedAsSupported` (`FEATURE_UNVERIFIED`). Marking an unverified capability as supported is `FEATURE_UNVERIFIED`.
- Forcing a deferred optional capability online is `OPTIONAL_NOT_FORCED`.
- `submitPaidStoreRelease` without `v022Met` is `V022_GATE_UNMET`. Without `i053Complete` it is `I053_REQUIRED`. I-053 is still partial, so paid store release stays refused.
- Claiming that all real enabled-feature fixtures have passed is `FIXTURES_UNQUALIFIED` unless that measurement actually exists. Treating a commercial-license warning as a hard I-058 block is `WARNING_IS_NOT_HARD_BLOCK`. Treating that warning as a V-022 exemption is `WARNING_DOES_NOT_EXEMPT`.
- Starting I-055 is `FEATURE_NOT_IMPLEMENTED`. `storeReleaseInvented`, `storeRegistrationInvented`, `paymentVendorInvented`, `iapInvented`, `receiptVerifierDeployed`, `sbomClaimedComplete`, `v022Claimed`, and `i055Started` stay false.

A real store submission, V-022 qualification, signed SBOM / store materials, and an I-055 accessibility product surface remain unopened.

## Consequences

The first I-058 leftover acceptance items (unverified capabilities are not shown as supported, and a paid release must also satisfy I-053) are officialized at this ReleaseQualifier bound. Real enabled-feature fixtures, offline dual-app isolation, and durable-edit zero-loss remain unopened in this slice and are not claimed. The V-022=public-release gate remains unmet, so I-058 stays partial and is not marked complete. 87-task counts become 0 complete / 61 partial / 13 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i058-release-qualify/`.

## Follow-up

Do not start I-059 until V-006=advanced-color numeric and appearance qualifications are honestly met. Do not start I-061 or claim V-026=gltf-preview. Do not start I-055 unless a narrow already-specified LocaleCatalog/semantics slice is required. Do not invent a limiter (V-024 / I-060 stay closed). Do not re-qualify I-058, I-049, I-050, I-028, I-042, V-006, I-053, V-007, I-001, or I-011 leftovers. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not claim I-016–I-019 hardware ports or store-release as passed. Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial leftover that is not already officialized and does not invent a deferred runtime. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006, or I-058 complete.
