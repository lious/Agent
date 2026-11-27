import 'package:studio_contracts/studio_contracts.dart';

import 'vertical_brief.dart';

/// Trusted confirmed product fact. An LLM setting confirmed=true is not
/// authorization and cannot enter this ledger by itself.
final class ConfirmedFact {
  ConfirmedFact({
    required this.id,
    required this.sku,
    required this.productId,
    this.expiresAt,
  }) {
    requireId(id);
    requireId(sku);
    requireId(productId);
  }

  final String id, sku, productId;
  final DateTime? expiresAt;
  bool get confirmed => true;

  bool isExpired(DateTime now) => expiresAt != null && !expiresAt!.isAfter(now);
}

/// s8n FactLedger. Confirmation IDs are looked up here; compile does
/// not trust a model-claimed confirmed flag.
final class FactLedger {
  final Map<String, ConfirmedFact> _byId = {};

  void recordConfirmed(ConfirmedFact fact) {
    _byId[fact.id] = fact;
  }

  /// LLM or unsigned payload claiming confirmed=true is ignored.
  void ignoreUntrustedClaim({
    required String id,
    required bool claimedConfirmed,
  }) {
    requireId(id);
    // Deliberately no insert. claimedConfirmed cannot authorize.
    if (claimedConfirmed && !_byId.containsKey(id)) {
      return;
    }
  }

  ConfirmedFact requireConfirmed({
    required String id,
    required String productId,
    required DateTime now,
  }) {
    final fact = _byId[id];
    if (fact == null || !fact.confirmed) {
      throw StudioException(unconfirmedFact, id);
    }
    if (fact.isExpired(now)) {
      throw StudioException(factExpired, id);
    }
    if (fact.productId != productId) {
      throw StudioException(factSkuMismatch, id);
    }
    return fact;
  }
}
