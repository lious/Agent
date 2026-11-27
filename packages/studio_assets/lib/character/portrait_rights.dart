/// Live rights decision for a character operation. Pinning a pack version
/// freezes content, not permission.
final class RightsDecision {
  const RightsDecision.allow({
    required this.rightsId,
    required this.epoch,
    this.existingOutputsPolicy,
  }) : allowed = true,
       code = null;

  const RightsDecision.deny(
    this.code, {
    this.rightsId,
    this.epoch,
    this.existingOutputsPolicy,
  }) : allowed = false;

  final bool allowed;
  final String? code;
  final String? rightsId;
  final String? epoch;
  final String? existingOutputsPolicy;
}

final class RevocationReport {
  const RevocationReport({
    required this.rightsId,
    required this.epoch,
    required this.state,
    required this.newGenerations,
    required this.cacheHits,
    required this.existingOutputsPolicy,
  });

  final String rightsId;
  final String epoch;
  final String state;
  final int newGenerations;
  final int cacheHits;
  final String existingOutputsPolicy;
}

/// DEV-PURE derived semantic cache. A hit after revocation must be 0.
final class CharacterDerivedCache {
  final Map<String, _CacheEntry> _entries = {};
  int _hits = 0;

  int get hits => _hits;

  void put({
    required String rightsId,
    required String packHash,
    required String lookId,
    required String value,
  }) {
    _entries[_key(rightsId, packHash, lookId)] = _CacheEntry(
      rightsId: rightsId,
      value: value,
    );
  }

  String? lookup({
    required String rightsId,
    required String packHash,
    required String lookId,
    required bool revoked,
  }) {
    if (revoked) {
      return null;
    }
    final entry = _entries[_key(rightsId, packHash, lookId)];
    if (entry == null) {
      return null;
    }
    _hits++;
    return entry.value;
  }

  void invalidateRights(String rightsId) {
    _entries.removeWhere((key, entry) => entry.rightsId == rightsId);
  }

  void resetCounters() {
    _hits = 0;
  }

  static String _key(String rightsId, String packHash, String lookId) =>
      '$rightsId\u0000$packHash\u0000$lookId';
}

class _CacheEntry {
  _CacheEntry({required this.rightsId, required this.value});
  final String rightsId;
  final String value;
}

/// DEV-PURE generation counter. No model inference or paid API is invoked.
final class CharacterGenerationLedger {
  int _dispatched = 0;
  int get dispatched => _dispatched;

  void reset() {
    _dispatched = 0;
  }

  void recordDispatch() {
    _dispatched++;
  }
}
