# ADR 0157 — Official I-053 receipt uniqueness and offline-forgery refusals

## Status

Accepted for Increment 2.58 as the first I-053 slice. I-053 moves planned → partial and is not marked complete. V-022 stays blocked; this increment does not claim store-billing qualification, does not connect StoreKit or Play, and does not invent or default to a payment vendor. I-033 SubmissionReconciler leftovers are not re-qualified: this is a store-entitlement ledger, not a generation-job reconciler. I-040, I-041, I-009, I-046, I-051, I-054, I-029, and I-010 leftovers are not re-qualified. I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-035 stays planned. I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, and I-040 stay partial and are not marked complete. V-009, V-016, V-017, V-018, V-019, and V-021 stay blocked. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. Registration, IAP, and store review are not executed. A receipt-verifier service is not deployed.

## Decision

s12c defines `EntitlementService.verifyAndDeliver(storeProof, appId, subjectBinding) -> Receipt` and uniqueness on `store + app + transactionId` (a Play `purchaseToken` is a controlled identifier). A repeated notification returns the same delivery receipt. After a successful delivery, a finish/ack retry must not grant again. Unverified proofs and user cancellation grant nothing. Play PENDING does not grant. External transaction proof is not client-self-signed JSON. The server entitlement truth is separate from a local signed cache; that cache must not enter a `.studioproj`, CharacterPack, or session archive. An offline client cannot mint additional units. Clock rollback is refused. Unknown entitlements cannot start a new paid cloud task. A known refund or revoke is effective immediately and does not grant again. Canceling renewal is not immediate expiry. Offline mode cannot claim real-time remote revoke.

Buying a subscription does not lift YuE2, portrait, or voice licenses. A local commercial-license warning does not waive cloud fees or stand in as a grant. An uninstalled or unsupported capability must not appear available just because the user paid. Unknown prices must not be forged as free. Cross-app unlocks are not inherited from an email or packed IDs. Grant or revoke does not change Project revision. No default domestic payment vendor is selected.

This increment officializes that bound as a DEV-PURE compiler in `packages/studio_billing/lib/entitlement_ledger.dart`:

- `verifyAndDeliver` grants at most once per `store/app/transactionKey`. `acknowledge` returns the same receipt. PENDING, cancelled, and unverified proofs grant nothing. A client-signed proof is `UNTRUSTED_PROOF`. An unknown price is `PRICE_UNKNOWN`. Project revision stays unchanged.
- `addOfflineUnits(fromClient: true)` is `OFFLINE_FORGERY`. Clock rollback is `CLOCK_ROLLBACK`. An unknown or revoked entitlement cannot start a paid cloud task (`APPROVAL_REQUIRED`). The entitlement cache is not written into a project pack, CharacterPack, or session archive. Real-time remote revoke is not claimed.
- `revoke` then `verifyAndDeliver` is `ENTITLEMENT_REVOKED`. Treating renewal cancel as immediate expiry is `UNSUPPORTED_EDIT_TECHNIQUE`. Using a license warning to waive a cloud fee or to lift YuE/portrait/voice rights is `WARNING_DOES_NOT_EXEMPT` on this entitlement surface, not a rewrite of I-033 consent tests. A paid user with an uninstalled capability is `CAPABILITY_UNSATISFIED`. Cross-app inheritance is `ENTITLEMENT_NOT_TRANSFERABLE`. `defaultDomesticPaymentVendor`, `vendorInvented`, `storeSdkConnected`, `v022Claimed`, and `paidApiCalled` stay false.

A real StoreKit/Play adapter, V-022 qualification, and a deployed receipt verifier remain unopened.

## Consequences

The first I-053 leftover acceptance items (a duplicate receipt grants once, an offline client cannot forge additional units, refund or revoke does not grant again, and a local license warning does not waive cloud fees) are officialized at this ledger bound. V-022 stays blocked, so I-053 stays partial and is not marked complete. 87-task counts become 0 complete / 49 partial / 25 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i053-entitlement-ledger/`.

## Follow-up

Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial work from the four planning documents. Do not invent a payment vendor, connect StoreKit/Play, or claim V-022. Do not re-qualify I-053, I-033, I-040, I-041, I-009, I-046, I-051, I-054, I-029, or I-010 leftovers. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not start I-035 as a product loop or claim a V-020 precision/recall achievement. Do not claim a 60s WebCodecs/OPFS roundtrip or pin a V-007 production lock. Do not start quote/apply, paid generation, or SQL `vertical.v1` unless a narrowly specified protocol slice is already written. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, or I-053 complete.
