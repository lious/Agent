import 'package:studio_contracts/studio_contracts.dart';

enum EntitlementState { active, grace, expired, revoked, unknown }

enum StoreProofKind {
  verifiedStore,
  pending,
  cancelled,
  unverified,
  clientSigned,
}

/// DEV-PURE I-053 store proof. This is not a StoreKit or Play SDK
/// integration and not a payment vendor.
final class StoreProof {
  StoreProof({
    required this.store,
    required this.appId,
    required this.transactionKey,
    required this.kind,
    this.productId = 'product-1',
    this.authorityVersion = 1,
    this.priceKnown = true,
  }) {
    requireId(store);
    requireId(appId);
    requireId(transactionKey);
    requireId(productId);
  }

  final String store, appId, transactionKey, productId;
  final StoreProofKind kind;
  final int authorityVersion;
  final bool priceKnown;
}

final class DeliveryReceipt {
  DeliveryReceipt({
    required this.id,
    required this.transactionKey,
    required this.granted,
  });

  final String id, transactionKey;
  final bool granted;
}

final class EntitlementSnapshot {
  EntitlementSnapshot({
    required this.productId,
    required this.state,
    this.validUntil,
    this.offlineUntil,
    this.units = 0,
  });

  final String productId;
  final EntitlementState state;
  final int? validUntil, offlineUntil;
  final int units;
}

/// Official I-053 EntitlementLedger. Server truth is not a client-signed
/// cache, and this is not a rewrite of I-033 SubmissionReconciler.
final class EntitlementLedger {
  int grantCount = 0;
  int projectRevision = 0;
  int documentWrites = 0;
  final _deliveries = <String, DeliveryReceipt>{};
  final _revoked = <String>{};
  final _units = <String, int>{};
  final _lastKnownServerTime = <int>[];

  bool get paidApiCalled => false;
  bool get vendorInvented => false;
  bool get defaultDomesticPaymentVendor => false;
  bool get v022Claimed => false;
  bool get storeSdkConnected => false;
  bool get submitted => false;
  bool get cacheInProjectPack => false;
  bool get cacheInCharacterPack => false;
  bool get cacheInSessionArchive => false;
  bool get realtimeRemoteRevokeClaimed => false;

  String _key(StoreProof proof) =>
      '${proof.store}/${proof.appId}/${proof.transactionKey}';

  /// Verified store proofs deliver once per store+app+transactionKey.
  /// PENDING, cancelled, unverified, and client-signed proofs grant nothing.
  DeliveryReceipt verifyAndDeliver(StoreProof proof) {
    if (proof.kind == StoreProofKind.clientSigned) {
      throw const StudioException('UNTRUSTED_PROOF', 'clientSigned');
    }
    if (!proof.priceKnown) {
      throw const StudioException('PRICE_UNKNOWN', 'offer');
    }
    final key = _key(proof);
    if (_revoked.contains(key)) {
      throw const StudioException('ENTITLEMENT_REVOKED', 'deliver');
    }
    final existing = _deliveries[key];
    if (existing != null) {
      documentWrites = 0;
      return existing;
    }
    final grant = proof.kind == StoreProofKind.verifiedStore;
    final receipt = DeliveryReceipt(
      id: 'receipt-$key',
      transactionKey: proof.transactionKey,
      granted: grant,
    );
    _deliveries[key] = receipt;
    if (grant) {
      grantCount += 1;
      _units[key] = (_units[key] ?? 0) + 1;
    }
    documentWrites = 0;
    return receipt;
  }

  /// Successful finish/ack retry must not grant again.
  DeliveryReceipt acknowledge(StoreProof proof) => verifyAndDeliver(proof);

  void revoke(StoreProof proof) {
    final key = _key(proof);
    _revoked.add(key);
    _units[key] = 0;
    documentWrites = 0;
  }

  /// A known refund is effective immediately. Canceling renewal is not
  /// the same as immediate expiry.
  EntitlementSnapshot current({
    required String productId,
    required EntitlementState state,
    int? expiresAt,
    bool renewalCancelled = false,
    bool treatCancelAsImmediateExpiry = false,
  }) {
    requireId(productId);
    if (treatCancelAsImmediateExpiry && renewalCancelled) {
      throw const StudioException(
        'UNSUPPORTED_EDIT_TECHNIQUE',
        'renewalCancel',
      );
    }
    documentWrites = 0;
    return EntitlementSnapshot(
      productId: productId,
      state: state,
      validUntil: expiresAt,
    );
  }

  /// Offline clients cannot mint units. Clock rollback is refused.
  void addOfflineUnits({required bool fromClient, int units = 1}) {
    if (fromClient) {
      throw const StudioException('OFFLINE_FORGERY', 'units');
    }
  }

  void advanceClock(int now) {
    if (_lastKnownServerTime.isNotEmpty && now < _lastKnownServerTime.last) {
      throw const StudioException('CLOCK_ROLLBACK', 'offline');
    }
    _lastKnownServerTime.add(now);
  }

  /// Unknown or unverified entitlements cannot start a new paid cloud task.
  void startPaidCloudTask({
    required EntitlementState state,
    required bool licenseWarningExemptsFee,
    required bool subscriptionLiftsYuEOrPortraitOrVoice,
    required bool paidShowsUninstalledCapability,
  }) {
    if (state == EntitlementState.unknown ||
        state == EntitlementState.revoked) {
      throw const StudioException('APPROVAL_REQUIRED', 'paidCloud');
    }
    if (licenseWarningExemptsFee) {
      throw const StudioException('WARNING_DOES_NOT_EXEMPT', 'cloudFee');
    }
    if (subscriptionLiftsYuEOrPortraitOrVoice) {
      throw const StudioException('WARNING_DOES_NOT_EXEMPT', 'rights');
    }
    if (paidShowsUninstalledCapability) {
      throw const StudioException('CAPABILITY_UNSATISFIED', 'paidButMissing');
    }
  }

  /// Cross-app unlock by email or packed IDs is not inherited.
  void inheritAcrossApp({required bool byEmailOrPackedIds}) {
    if (byEmailOrPackedIds) {
      throw const StudioException('ENTITLEMENT_NOT_TRANSFERABLE', 'crossApp');
    }
  }

  Map<String, Object?> exportProjectPack() => {
    'entitlementCache': const <String>[],
    'secrets': const <String>[],
  };

  int unitsFor(StoreProof proof) => _units[_key(proof)] ?? 0;
}
