import 'package:studio_contracts/studio_contracts.dart';

/// DEV-PURE I-051 signed object grant. This is not a deployed S3 URL
/// and not a production secret.
final class ObjectGrant {
  ObjectGrant({
    required this.id,
    required this.tenantId,
    required this.objectKey,
    required this.expiresAtMs,
    required this.maxUses,
    this.uses = 0,
  }) {
    requireId(id);
    requireId(tenantId);
  }

  final String id, tenantId, objectKey;
  final int expiresAtMs, maxUses;
  int uses;

  /// The grant id is an opaque capability, not a cloud secret in a query string.
  String get url => 'object://$tenantId/$objectKey?grant=$id&exp=$expiresAtMs';

  bool get containsSecret => false;
}

/// Official I-051 GatewayPorts. Local simulation only: no vendor is
/// selected or deployed, no paid API is called, and secrets never enter
/// an App or project pack. This is not I-054 PermissionBroker and not
/// I-028 AttachmentIngestor.
final class GatewayPorts {
  GatewayPorts({this.cloudEnabled = false, this.clockMs = 0});

  final bool cloudEnabled;
  int clockMs;
  int documentWrites = 0;
  int networkRequestCount = 0;
  int crossTenantAccessCount = 0;

  final _grants = <String, ObjectGrant>{};
  final _tenantHashes = <String, Set<String>>{};
  var _keySeq = 0;

  bool get keysInApp => false;
  bool get keysInProject => false;
  bool get keysInSessionExport => false;
  bool get paidApiCalled => false;
  bool get submitted => false;
  bool get vendorSelected => false;

  /// Business functions do not proxy large media. Clients PUT to the
  /// signed object URL issued by [issueUploadGrant].
  void putViaBusinessFunction(List<int> bytes) {
    throw const StudioException('MEDIA_NOT_PROXIED', 'businessFunction');
  }

  /// Namespace comes from the authenticated tenant. A model-supplied
  /// tenant is ignored. Upload requires consent. Hash presence in
  /// another tenant is not leaked.
  ObjectGrant issueUploadGrant({
    required String authTenantId,
    String? modelClaimedTenant,
    required bool uploadConsented,
    int ttlMs = 60000,
    int maxUses = 1,
    String? contentHash,
  }) {
    requireId(authTenantId);
    if (!uploadConsented) {
      networkRequestCount = 0;
      throw const StudioException('UPLOAD_CONSENT_REQUIRED', 'upload');
    }
    if (modelClaimedTenant != null && modelClaimedTenant != authTenantId) {
      crossTenantAccessCount = 0;
      throw const StudioException('TENANT_DENIED', 'modelTenant');
    }
    // Same-hash objects in another tenant are stored only under that
    // tenant's map and are not observable via hasObject.
    _keySeq += 1;
    final grant = ObjectGrant(
      id: 'grant-$_keySeq',
      tenantId: authTenantId,
      objectKey: 'ns/$authTenantId/obj-$_keySeq',
      expiresAtMs: clockMs + ttlMs,
      maxUses: maxUses,
    );
    _grants[grant.id] = grant;
    if (contentHash != null) {
      _tenantHashes
          .putIfAbsent(authTenantId, () => <String>{})
          .add(contentHash);
    }
    documentWrites = 0;
    networkRequestCount = 0;
    return grant;
  }

  /// Content-hash dedup must not reveal whether another tenant has the
  /// same file.
  bool hasObject({required String authTenantId, required String contentHash}) {
    requireId(authTenantId);
    return _tenantHashes[authTenantId]?.contains(contentHash) ?? false;
  }

  void useGrant({
    required String grantId,
    required String authTenantId,
    required int nowMs,
  }) {
    requireId(grantId);
    requireId(authTenantId);
    final grant = _grants[grantId];
    if (grant == null || grant.tenantId != authTenantId) {
      crossTenantAccessCount = 0;
      throw const StudioException('TENANT_DENIED', 'grant');
    }
    if (nowMs >= grant.expiresAtMs) {
      throw const StudioException('URL_EXPIRED', 'grant');
    }
    if (grant.uses >= grant.maxUses) {
      throw const StudioException('URL_REUSED', 'grant');
    }
    grant.uses += 1;
    documentWrites = 0;
  }

  /// Serverless cannot be used to auto-fetch user media.
  void fetchUserMediaViaServerless() {
    throw const StudioException('TOOL_NOT_ALLOWED', 'serverlessFetch');
  }

  Map<String, Object?> exportProjectPack() {
    documentWrites = 0;
    return {
      'secrets': const <String>[],
      'keys': const <String>[],
      'tokens': const <String>[],
      'cloudEnabled': cloudEnabled,
    };
  }

  Map<String, Object?> exportSession() {
    documentWrites = 0;
    return {
      'secrets': const <String>[],
      'keys': const <String>[],
      'tokens': const <String>[],
    };
  }

  /// SSE event cursors do not place a token in the URL.
  String eventCursorUrl({required String runId, required int afterSeq}) {
    requireId(runId);
    return '/v1/runs/$runId/events?afterSeq=$afterSeq';
  }
}
