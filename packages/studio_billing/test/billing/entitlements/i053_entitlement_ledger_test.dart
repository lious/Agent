import 'package:studio_billing/studio_billing.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

/// Increment 2.58 official first I-053 slice: EntitlementLedger receipt
/// uniqueness and offline-forgery refusals. This file does not invent a
/// payment vendor, does not call a paid API, does not claim V-022, does
/// not default to a domestic payment vendor, does not connect StoreKit
/// or Play, does not rewrite I-033 SubmissionReconciler, does not
/// re-qualify I-040 leftovers, does not start I-035, and does not mark
/// I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, or I-040
/// complete. InversePatch kind stays restoreSnapshot. Project
/// user_version stays 9.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

StoreProof proof({
  StoreProofKind kind = StoreProofKind.verifiedStore,
  String transactionKey = 'txn-1',
  bool priceKnown = true,
}) => StoreProof(
  store: 'app-store',
  appId: 'studio.app',
  transactionKey: transactionKey,
  kind: kind,
  priceKnown: priceKnown,
);

void main() {
  test('a duplicate store receipt grants once; ack retry returns the same receipt; unverified, cancelled, or pending proofs grant nothing; project revision is unchanged', () {
    final ledger = EntitlementLedger();
    expect(ledger.defaultDomesticPaymentVendor, isFalse);
    expect(ledger.vendorInvented, isFalse);
    expect(ledger.storeSdkConnected, isFalse);
    expect(ledger.v022Claimed, isFalse);
    final first = ledger.verifyAndDeliver(proof());
    expect(first.granted, isTrue);
    expect(ledger.grantCount, 1);
    final again = ledger.verifyAndDeliver(proof());
    expect(again.id, first.id);
    expect(ledger.grantCount, 1);
    expect(ledger.acknowledge(proof()).id, first.id);
    expect(ledger.grantCount, 1);
    expect(ledger.projectRevision, 0);

    expect(
      ledger
          .verifyAndDeliver(
            proof(kind: StoreProofKind.pending, transactionKey: 'txn-p'),
          )
          .granted,
      isFalse,
    );
    expect(
      ledger
          .verifyAndDeliver(
            proof(kind: StoreProofKind.cancelled, transactionKey: 'txn-c'),
          )
          .granted,
      isFalse,
    );
    expect(
      ledger
          .verifyAndDeliver(
            proof(kind: StoreProofKind.unverified, transactionKey: 'txn-u'),
          )
          .granted,
      isFalse,
    );
    expect(ledger.grantCount, 1);
    expect(ledger.paidApiCalled, isFalse);
    expect(ledger.documentWrites, 0);
  });

  test('an offline client cannot forge additional units; entitlement cache is not packed; clock rollback and unknown entitlements cannot start a paid cloud task', () {
    final ledger = EntitlementLedger();
    ledger.verifyAndDeliver(proof());
    expect(ledger.unitsFor(proof()), 1);
    expect(
      () => ledger.addOfflineUnits(fromClient: true),
      code('OFFLINE_FORGERY'),
    );
    expect(ledger.unitsFor(proof()), 1);
    expect(
      () => ledger.verifyAndDeliver(
        proof(kind: StoreProofKind.clientSigned, transactionKey: 'txn-forge'),
      ),
      code('UNTRUSTED_PROOF'),
    );
    expect(ledger.cacheInProjectPack, isFalse);
    expect(ledger.cacheInCharacterPack, isFalse);
    expect(ledger.cacheInSessionArchive, isFalse);
    expect(ledger.exportProjectPack()['entitlementCache'], isEmpty);
    ledger.advanceClock(100);
    expect(() => ledger.advanceClock(50), code('CLOCK_ROLLBACK'));
    expect(
      () => ledger.startPaidCloudTask(
        state: EntitlementState.unknown,
        licenseWarningExemptsFee: false,
        subscriptionLiftsYuEOrPortraitOrVoice: false,
        paidShowsUninstalledCapability: false,
      ),
      code('APPROVAL_REQUIRED'),
    );
    expect(ledger.realtimeRemoteRevokeClaimed, isFalse);
    expect(ledger.paidApiCalled, isFalse);
  });

  test('refund or revoke does not grant again; renewal cancel is not immediate expiry; a license warning does not waive cloud fees or lift YuE/portrait/voice rights; unknown prices are not forged as free', () {
    final ledger = EntitlementLedger();
    ledger.verifyAndDeliver(proof());
    ledger.revoke(proof());
    expect(ledger.unitsFor(proof()), 0);
    expect(() => ledger.verifyAndDeliver(proof()), code('ENTITLEMENT_REVOKED'));
    expect(ledger.grantCount, 1);
    expect(ledger.projectRevision, 0);

    final snap = ledger.current(
      productId: 'sub-1',
      state: EntitlementState.active,
      expiresAt: 7,
      renewalCancelled: true,
    );
    expect(snap.state, EntitlementState.active);
    expect(snap.validUntil, 7);
    expect(
      () => ledger.current(
        productId: 'sub-1',
        state: EntitlementState.active,
        renewalCancelled: true,
        treatCancelAsImmediateExpiry: true,
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => ledger.startPaidCloudTask(
        state: EntitlementState.active,
        licenseWarningExemptsFee: true,
        subscriptionLiftsYuEOrPortraitOrVoice: false,
        paidShowsUninstalledCapability: false,
      ),
      code('WARNING_DOES_NOT_EXEMPT'),
    );
    expect(
      () => ledger.startPaidCloudTask(
        state: EntitlementState.active,
        licenseWarningExemptsFee: false,
        subscriptionLiftsYuEOrPortraitOrVoice: true,
        paidShowsUninstalledCapability: false,
      ),
      code('WARNING_DOES_NOT_EXEMPT'),
    );
    expect(
      () => ledger.startPaidCloudTask(
        state: EntitlementState.active,
        licenseWarningExemptsFee: false,
        subscriptionLiftsYuEOrPortraitOrVoice: false,
        paidShowsUninstalledCapability: true,
      ),
      code('CAPABILITY_UNSATISFIED'),
    );
    expect(
      () => ledger.verifyAndDeliver(
        proof(transactionKey: 'txn-free', priceKnown: false),
      ),
      code('PRICE_UNKNOWN'),
    );
    expect(
      () => ledger.inheritAcrossApp(byEmailOrPackedIds: true),
      code('ENTITLEMENT_NOT_TRANSFERABLE'),
    );
    expect(ledger.defaultDomesticPaymentVendor, isFalse);
    expect(ledger.v022Claimed, isFalse);
    expect(ledger.submitted, isFalse);
    expect(ledger.documentWrites, 0);
  });
}
