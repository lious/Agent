import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_gateway/studio_gateway.dart';
import 'package:test/test.dart';

/// Increment 2.54 official first I-051 slice: GatewayPorts local
/// simulation. This file does not select or deploy a vendor, does not
/// call a paid API, does not invent a PostgreSQL or object-store
/// schema, does not re-qualify I-054 or I-029, does not start I-035,
/// does not invent I-013 job archival or an I-014 RestoreService
/// commit path, does not mark I-037, I-038, V-007, V-020, or I-054
/// complete, and does not rewrite frozen I-036 fts5Enabled==false
/// assertions. InversePatch kind stays restoreSnapshot. Project
/// user_version stays 9. V-021 stays blocked.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('keys never enter the App, a project pack, or a session export; business functions do not proxy large media; serverless cannot auto-fetch user media', () {
    final gateway = GatewayPorts(cloudEnabled: false);
    expect(gateway.keysInApp, isFalse);
    expect(gateway.keysInProject, isFalse);
    expect(gateway.keysInSessionExport, isFalse);
    expect(gateway.vendorSelected, isFalse);
    expect(gateway.paidApiCalled, isFalse);
    final pack = gateway.exportProjectPack();
    expect(pack['keys'], isEmpty);
    expect(pack['secrets'], isEmpty);
    expect(pack['tokens'], isEmpty);
    expect(gateway.exportSession()['keys'], isEmpty);
    expect(
      gateway.eventCursorUrl(runId: 'run-1', afterSeq: 4).contains('token='),
      isFalse,
    );
    expect(
      () => gateway.putViaBusinessFunction(List<int>.filled(8, 1)),
      code('MEDIA_NOT_PROXIED'),
    );
    expect(
      () => gateway.fetchUserMediaViaServerless(),
      code('TOOL_NOT_ALLOWED'),
    );
    // The App still runs locally when the cloud is not enabled.
    expect(gateway.cloudEnabled, isFalse);
    expect(gateway.submitted, isFalse);
    expect(gateway.documentWrites, 0);
  });

  test('cross-tenant access is zero: a model-claimed tenant is ignored, a wrong-tenant grant is denied, and same-hash objects in another tenant are not leaked', () {
    final gateway = GatewayPorts();
    final grant = gateway.issueUploadGrant(
      authTenantId: 'tenant-a',
      modelClaimedTenant: 'tenant-a',
      uploadConsented: true,
      contentHash:
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    );
    expect(grant.objectKey.contains('tenant-a'), isTrue);
    expect(grant.containsSecret, isFalse);
    expect(
      gateway.hasObject(
        authTenantId: 'tenant-a',
        contentHash:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      ),
      isTrue,
    );
    expect(
      gateway.hasObject(
        authTenantId: 'tenant-b',
        contentHash:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      ),
      isFalse,
    );
    expect(
      () => gateway.issueUploadGrant(
        authTenantId: 'tenant-a',
        modelClaimedTenant: 'tenant-b',
        uploadConsented: true,
      ),
      code('TENANT_DENIED'),
    );
    expect(
      () => gateway.useGrant(
        grantId: grant.id,
        authTenantId: 'tenant-b',
        nowMs: 0,
      ),
      code('TENANT_DENIED'),
    );
    expect(gateway.crossTenantAccessCount, 0);
    expect(gateway.networkRequestCount, 0);
    expect(gateway.paidApiCalled, isFalse);
  });

  test('upload requires consent; an expired signed URL is refused; a grant cannot be reused past maxUses', () {
    final gateway = GatewayPorts(clockMs: 1000);
    expect(
      () => gateway.issueUploadGrant(
        authTenantId: 'tenant-a',
        uploadConsented: false,
      ),
      code('UPLOAD_CONSENT_REQUIRED'),
    );
    expect(gateway.networkRequestCount, 0);

    final grant = gateway.issueUploadGrant(
      authTenantId: 'tenant-a',
      uploadConsented: true,
      ttlMs: 100,
      maxUses: 1,
    );
    expect(grant.url.contains('token='), isFalse);
    expect(grant.containsSecret, isFalse);
    gateway.useGrant(grantId: grant.id, authTenantId: 'tenant-a', nowMs: 1050);
    expect(
      () => gateway.useGrant(
        grantId: grant.id,
        authTenantId: 'tenant-a',
        nowMs: 1060,
      ),
      code('URL_REUSED'),
    );

    final short = gateway.issueUploadGrant(
      authTenantId: 'tenant-a',
      uploadConsented: true,
      ttlMs: 10,
      maxUses: 1,
    );
    expect(
      () => gateway.useGrant(
        grantId: short.id,
        authTenantId: 'tenant-a',
        nowMs: 1020,
      ),
      code('URL_EXPIRED'),
    );
    expect(gateway.submitted, isFalse);
    expect(gateway.paidApiCalled, isFalse);
    expect(gateway.documentWrites, 0);
  });
}
