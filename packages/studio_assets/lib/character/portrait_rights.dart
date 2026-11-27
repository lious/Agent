/// Live rights decision for a character operation. Pinning a pack version
/// freezes content, not permission.
final class RightsDecision {
  const RightsDecision.allow({
    required this.rightsId,
    required this.epoch,
    this.existingOutputsPolicy,
    this.leaseUntil,
    this.checkedAt,
  }) : allowed = true,
       code = null;

  const RightsDecision.deny(
    this.code, {
    this.rightsId,
    this.epoch,
    this.existingOutputsPolicy,
    this.leaseUntil,
    this.checkedAt,
  }) : allowed = false;

  final bool allowed;
  final String? code;
  final String? rightsId;
  final String? epoch;
  final String? existingOutputsPolicy;
  final String? leaseUntil;
  final String? checkedAt;
}

final class RevocationReport {
  const RevocationReport({
    required this.rightsId,
    required this.epoch,
    required this.state,
    required this.newGenerations,
    required this.cacheHits,
    required this.existingOutputsPolicy,
    this.cancelledTasks = 0,
    this.isolatedTasks = 0,
  });

  final String rightsId;
  final String epoch;
  final String state;
  final int newGenerations;
  final int cacheHits;
  final String existingOutputsPolicy;
  final int cancelledTasks;
  final int isolatedTasks;
}

/// Context for a dispatch-time rights evaluation. Cloud real-person
/// generation requires a fresh online check when the offline lease is
/// missing or expired. The check is an injectable port, not a network call.
final class DispatchContext {
  const DispatchContext({
    this.cloud = false,
    this.offline = false,
    this.onlineCheck,
  });

  final bool cloud;
  final bool offline;
  final FreshOnlineRightsCheck? onlineCheck;
}

/// Injectable freshness port. Implementations must not call a paid or
/// commercial network service. Tests inject a stub.
abstract interface class FreshOnlineRightsCheck {
  FreshOnlineCheckResult inspect({
    required String rightsId,
    required String epoch,
    required DateTime now,
  });
}

final class FreshOnlineCheckResult {
  const FreshOnlineCheckResult({
    required this.fresh,
    this.leaseUntil,
    this.checkedAt,
    this.epoch,
    this.state = 'active',
  });

  final bool fresh;
  final DateTime? leaseUntil;
  final DateTime? checkedAt;
  final String? epoch;
  final String state;
}

/// In-memory stub used by official tests. It never opens a socket or pays
/// for a commercial rights API.
final class ScriptedOnlineRightsCheck implements FreshOnlineRightsCheck {
  ScriptedOnlineRightsCheck({
    this.fresh = true,
    this.leaseUntil,
    this.state = 'active',
  });

  bool fresh;
  DateTime? leaseUntil;
  String state;
  int callCount = 0;

  /// Always false: this port is a local stub.
  bool get invokedPaidNetwork => false;

  @override
  FreshOnlineCheckResult inspect({
    required String rightsId,
    required String epoch,
    required DateTime now,
  }) {
    callCount++;
    return FreshOnlineCheckResult(
      fresh: fresh,
      leaseUntil: leaseUntil,
      checkedAt: now.toUtc(),
      epoch: epoch,
      state: state,
    );
  }
}

const existingOutputsRetainAllowed = 'retainAllowed';
const existingOutputsBlockUse = 'blockUse';
const existingOutputsReviewRequired = 'reviewRequired';

final class ExistingOutputRecord {
  const ExistingOutputRecord({
    required this.outputId,
    required this.rightsId,
    required this.path,
    this.bodyHash,
  });

  final String outputId;
  final String rightsId;
  final String path;
  final String? bodyHash;
}

final class ExistingOutputUse {
  const ExistingOutputUse({
    required this.outputId,
    required this.path,
    required this.disposition,
    required this.fileRetained,
  });

  final String outputId;
  final String path;
  final String disposition;
  final bool fileRetained;
}

/// Policy application for already-created user outputs. Files are never
/// deleted by revocation or GC in this slice.
final class ExistingOutputsDisposition {
  const ExistingOutputsDisposition({
    required this.policy,
    required this.outputs,
    this.deletedAny = false,
  });

  final String policy;
  final List<ExistingOutputUse> outputs;
  final bool deletedAny;
}

final class ExportPin {
  const ExportPin({
    required this.exportId,
    required this.libraryId,
    required this.entityId,
    required this.version,
    required this.packHash,
    this.kind = 'character',
  });

  final String exportId;
  final String libraryId;
  final String entityId;
  final String version;
  final String packHash;
  final String kind;
}

final class CandidateTaskPin {
  const CandidateTaskPin({
    required this.taskId,
    required this.libraryId,
    required this.entityId,
    required this.version,
    required this.packHash,
    this.kind = 'character',
    this.state = 'processing',
  });

  final String taskId;
  final String libraryId;
  final String entityId;
  final String version;
  final String packHash;
  final String kind;
  final String state;
}

/// Result of the candidate arrival/completion gate.
///
/// A late result for a revoked rightsId, or for a task already cancelled
/// after revoke, is isolated and is not accepted as a normal ready output.
final class CandidateArrivalReport {
  const CandidateArrivalReport({
    required this.taskId,
    required this.state,
    required this.isolated,
    required this.outputAccepted,
    this.code,
    this.rightsId,
  });

  final String taskId;
  final String state;
  final bool isolated;
  final bool outputAccepted;
  final String? code;
  final String? rightsId;
}

final class HeadDeleteReport {
  const HeadDeleteReport({
    required this.libraryId,
    required this.entityId,
    this.deletedHeadVersion,
    required this.remainingVersions,
  });

  final String libraryId;
  final String entityId;
  final String? deletedHeadVersion;
  final List<String> remainingVersions;
}

final class RecycleReport {
  const RecycleReport({
    required this.recycled,
    required this.retryable,
    this.code,
    this.referenceCount = 0,
  });

  final bool recycled;
  final bool retryable;
  final String? code;
  final int referenceCount;
}

/// Operations that must consult live authority/epoch at dispatch time.
const characterDispatchOperations = {
  'referenceGeneration',
  'training',
  'upload',
};

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
