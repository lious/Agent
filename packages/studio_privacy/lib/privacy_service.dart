import 'package:studio_contracts/studio_contracts.dart';

/// Official s12b PermissionBroker scopes and decisions.
enum PermissionScope {
  pick,
  savePhoto,
  recordMic,
  readExternal,
  modelDownload,
  cloudUpload,
}

enum PermissionDecision { grant, denied, cancelled }

enum ImportSourceKind { localFile, photoProvider, documentProvider }

enum PrivacySurface { fts, rag, summary, archive, diagnostic }

/// DEV-PURE I-054 permission request. This is not a real OS grant.
final class PermissionRequest {
  PermissionRequest({
    required this.scope,
    required this.userGestureId,
    this.resourceRefs = const [],
    this.purpose = 'edit',
    this.offlineMode = false,
    this.userInformedMic = false,
    this.treatSystemGrantAsProviderConsent = false,
  }) {
    requireId(userGestureId);
    for (final ref in resourceRefs) {
      requireId(ref);
    }
  }

  final PermissionScope scope;
  final String userGestureId, purpose;
  final List<String> resourceRefs;
  final bool offlineMode, userInformedMic, treatSystemGrantAsProviderConsent;
}

final class PermissionOutcome {
  PermissionOutcome(
    this.decision, {
    this.grantId,
    this.writtenToProjectPack = false,
  });

  final PermissionDecision decision;
  final String? grantId;
  final bool writtenToProjectPack;

  bool get granted => decision == PermissionDecision.grant;
}

/// DEV-PURE I-054 import handle. A cloud-album fetch is not a
/// strict-offline claim.
final class ImportHandle {
  ImportHandle({
    required this.id,
    required this.sourceKind,
    required this.state,
    this.strictlyOfflineClaimed = false,
  }) {
    requireId(id);
  }

  final String id;
  final ImportSourceKind sourceKind;
  final String state;
  final bool strictlyOfflineClaimed;
}

/// Official s12b PermissionBroker. Denied photos or microphone scopes
/// do not block local file import. This is not I-029 DeletionBarrier
/// and not a rewrite of I-027 session search.
final class PermissionBroker {
  final _denied = <PermissionScope>{};
  final _grants = <PermissionScope, String>{};
  var projectRevision = 0;
  int documentWrites = 0;

  void deny(PermissionScope scope) => _denied.add(scope);

  PermissionOutcome request(PermissionRequest request) {
    if (request.treatSystemGrantAsProviderConsent) {
      throw const StudioException('UPLOAD_CONSENT_REQUIRED', 'providerConsent');
    }
    if (request.scope == PermissionScope.cloudUpload && request.offlineMode) {
      return PermissionOutcome(PermissionDecision.denied);
    }
    if (request.scope == PermissionScope.recordMic &&
        !request.userInformedMic) {
      return PermissionOutcome(PermissionDecision.denied);
    }
    if (_denied.contains(request.scope)) {
      return PermissionOutcome(PermissionDecision.denied);
    }
    final grantId = 'grant-${request.scope.name}';
    _grants[request.scope] = grantId;
    documentWrites = 0;
    // Grants stay in the local broker; they are not written into a pack.
    return PermissionOutcome(PermissionDecision.grant, grantId: grantId);
  }

  /// Local file pick stays allowed after a photos or microphone denial.
  ImportHandle importLocalFile(String id) {
    if (_denied.contains(PermissionScope.pick)) {
      throw const StudioException('PERMISSION_DENIED', 'pick');
    }
    documentWrites = 0;
    return ImportHandle(
      id: id,
      sourceKind: ImportSourceKind.localFile,
      state: 'localReady',
    );
  }

  /// Export to a local FileToken does not require album write permission.
  void exportToFileToken() {
    documentWrites = 0;
  }

  /// Denoise or clone cannot open the microphone without a grant.
  /// Capture state is not a Project revision bump.
  void startCapture({required bool denoiseOrClone}) {
    if (!_grants.containsKey(PermissionScope.recordMic) ||
        _denied.contains(PermissionScope.recordMic)) {
      throw const StudioException('PERMISSION_DENIED', 'recordMic');
    }
  }

  /// A cloud-album fetch is not strictly offline and is not AI provider consent.
  ImportHandle materializeCloudAlbum(String id) {
    documentWrites = 0;
    return ImportHandle(
      id: id,
      sourceKind: ImportSourceKind.photoProvider,
      state: 'fetching',
      strictlyOfflineClaimed: false,
    );
  }
}

/// DEV-PURE I-054 privacy inventory. Tombstones are a protocol ledger,
/// not production FTS/RAG, and not the I-029 workspace intent barrier.
final class PrivacyService {
  var privacyEpoch = 0;
  var projectRevision = 0;
  int documentWrites = 0;
  final _live = <String, String>{};
  final _fingerprints = <String, String>{};
  final _purgedFingerprints = <String>{};
  final _purgedPhrases = <String>{};

  bool get productionFtsEnabled => false;
  bool get productionRagEnabled => false;
  bool get claimedRemoteErasure => false;
  bool get submitted => false;

  void put({
    required String id,
    required String phrase,
    required String fingerprint,
  }) {
    requireId(id);
    _live[id] = phrase;
    _fingerprints[id] = fingerprint;
  }

  void purge(List<String> ids) {
    privacyEpoch += 1;
    for (final id in ids) {
      final phrase = _live.remove(id);
      final fingerprint = _fingerprints.remove(id);
      if (phrase != null) _purgedPhrases.add(phrase);
      if (fingerprint != null) _purgedFingerprints.add(fingerprint);
    }
    documentWrites = 0;
  }

  /// Deleted content cannot be revived on FTS/RAG/summary/archive surfaces.
  bool visibleOn(PrivacySurface surface, String phrase) {
    if (_purgedPhrases.contains(phrase)) return false;
    return _live.containsValue(phrase);
  }

  /// Publishing a pre-purge summary after the privacy epoch changes is refused.
  void publishSummary({required int capturedEpoch, required String phrase}) {
    if (capturedEpoch != privacyEpoch || _purgedPhrases.contains(phrase)) {
      throw const StudioException('SNAPSHOT_PRIVACY_BARRIER', 'summary');
    }
  }

  /// An old archive that still carries a purged fingerprint cannot be
  /// imported back as live content.
  void importOldArchive({required String fingerprint}) {
    if (_purgedFingerprints.contains(fingerprint)) {
      throw const StudioException('SNAPSHOT_PRIVACY_BARRIER', 'archive');
    }
  }

  /// Default diagnostics exclude private text and source media.
  Map<String, Object?> exportDiagnostic({
    bool includePrivateText = false,
    bool includeSourceMedia = false,
    bool includeCredentials = false,
  }) {
    if (includePrivateText || includeSourceMedia || includeCredentials) {
      throw const StudioException('SNAPSHOT_PRIVACY_BARRIER', 'diagnostic');
    }
    documentWrites = 0;
    return {
      'schema': 'studio.diagnostic.v1',
      'privacyEpoch': privacyEpoch,
      'privateTextIncluded': false,
      'sourceMediaIncluded': false,
      'credentialsIncluded': false,
      'bodies': const <String>[],
    };
  }

  /// Production-basis export may include policy/facts/assessment, never
  /// credentials, private contracts, or deleted bodies. Default project
  /// packs keep sessionPolicy=excluded.
  Map<String, Object?> exportProductionBasis({
    required bool includePolicyFacts,
    required bool includeCredentials,
    required bool includeDeletedBodies,
    String sessionPolicy = 'excluded',
  }) {
    if (includeCredentials ||
        includeDeletedBodies ||
        sessionPolicy != 'excluded') {
      throw const StudioException('SNAPSHOT_PRIVACY_BARRIER', 'export');
    }
    documentWrites = 0;
    return {
      'policyFactsIncluded': includePolicyFacts,
      'credentialsIncluded': false,
      'deletedBodiesIncluded': false,
      'sessionPolicy': 'excluded',
      'sessionArchive': null,
    };
  }
}
