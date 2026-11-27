import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_privacy/studio_privacy.dart';
import 'package:test/test.dart';

/// Increment 2.53 official first I-054 slice: PermissionBroker and
/// PrivacyService export/delete surfaces. This file does not rewrite
/// I-029 DeletionBarrier or I-027 session-search leftovers, does not
/// claim production FTS/RAG, does not invent I-013 job archival or an
/// I-014 RestoreService commit path, does not start I-035, does not
/// mark I-037, I-038, V-007, or V-020 complete, and does not rewrite
/// frozen I-036 fts5Enabled==false assertions. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('denied photos or microphone still allow local file import; export to a FileToken does not need album write; denoise cannot open a mic without a grant; a system grant is not provider consent', () {
    final broker = PermissionBroker();
    broker.deny(PermissionScope.savePhoto);
    broker.deny(PermissionScope.recordMic);
    expect(
      broker
          .request(
            PermissionRequest(
              scope: PermissionScope.savePhoto,
              userGestureId: 'g-photo',
            ),
          )
          .decision,
      PermissionDecision.denied,
    );
    expect(
      broker
          .request(
            PermissionRequest(
              scope: PermissionScope.recordMic,
              userGestureId: 'g-mic',
              userInformedMic: true,
            ),
          )
          .decision,
      PermissionDecision.denied,
    );
    final imported = broker.importLocalFile('file-1');
    expect(imported.sourceKind, ImportSourceKind.localFile);
    expect(imported.state, 'localReady');
    broker.exportToFileToken();
    expect(broker.projectRevision, 0);
    expect(broker.documentWrites, 0);

    expect(
      () => broker.startCapture(denoiseOrClone: true),
      code('PERMISSION_DENIED'),
    );
    expect(
      broker
          .request(
            PermissionRequest(
              scope: PermissionScope.recordMic,
              userGestureId: 'g-silent',
            ),
          )
          .decision,
      PermissionDecision.denied,
    );
    expect(
      broker
          .request(
            PermissionRequest(
              scope: PermissionScope.cloudUpload,
              userGestureId: 'g-off',
              offlineMode: true,
            ),
          )
          .decision,
      PermissionDecision.denied,
    );
    expect(
      () => broker.request(
        PermissionRequest(
          scope: PermissionScope.cloudUpload,
          userGestureId: 'g-sys',
          treatSystemGrantAsProviderConsent: true,
        ),
      ),
      code('UPLOAD_CONSENT_REQUIRED'),
    );
    final cloud = broker.materializeCloudAlbum('album-1');
    expect(cloud.strictlyOfflineClaimed, isFalse);
    expect(cloud.state, isNot('localReady'));
    final pick = broker.request(
      PermissionRequest(scope: PermissionScope.pick, userGestureId: 'g-pick'),
    );
    expect(pick.granted, isTrue);
    expect(pick.writtenToProjectPack, isFalse);
  });

  test('purged content is not visible on FTS, RAG, summary, or archive surfaces; an old summary or pack cannot resurrect it; production FTS/RAG and remote erasure are not claimed', () {
    final privacy = PrivacyService();
    const phrase = 'secret-private-line';
    const fingerprint =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    privacy.put(id: 'msg-1', phrase: phrase, fingerprint: fingerprint);
    final beforeEpoch = privacy.privacyEpoch;
    expect(privacy.visibleOn(PrivacySurface.fts, phrase), isTrue);
    privacy.purge(const ['msg-1']);
    expect(privacy.privacyEpoch, greaterThan(beforeEpoch));
    expect(privacy.visibleOn(PrivacySurface.fts, phrase), isFalse);
    expect(privacy.visibleOn(PrivacySurface.rag, phrase), isFalse);
    expect(privacy.visibleOn(PrivacySurface.summary, phrase), isFalse);
    expect(privacy.visibleOn(PrivacySurface.archive, phrase), isFalse);
    expect(privacy.productionFtsEnabled, isFalse);
    expect(privacy.productionRagEnabled, isFalse);
    expect(privacy.claimedRemoteErasure, isFalse);
    expect(privacy.submitted, isFalse);
    expect(privacy.projectRevision, 0);
    expect(
      () => privacy.publishSummary(capturedEpoch: beforeEpoch, phrase: phrase),
      code('SNAPSHOT_PRIVACY_BARRIER'),
    );
    expect(
      () => privacy.importOldArchive(fingerprint: fingerprint),
      code('SNAPSHOT_PRIVACY_BARRIER'),
    );
    expect(privacy.documentWrites, 0);
  });

  test('default diagnostics exclude private text, source media, and credentials; a production-basis export may include policy facts but not credentials, deleted bodies, or session archives', () {
    final privacy = PrivacyService();
    privacy.put(
      id: 'msg-2',
      phrase: 'private-body',
      fingerprint:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );
    privacy.purge(const ['msg-2']);
    final diagnostic = privacy.exportDiagnostic();
    expect(diagnostic['privateTextIncluded'], isFalse);
    expect(diagnostic['sourceMediaIncluded'], isFalse);
    expect(diagnostic['credentialsIncluded'], isFalse);
    expect(diagnostic['bodies'], isEmpty);
    expect(
      () => privacy.exportDiagnostic(includePrivateText: true),
      code('SNAPSHOT_PRIVACY_BARRIER'),
    );
    expect(
      () => privacy.exportDiagnostic(includeSourceMedia: true),
      code('SNAPSHOT_PRIVACY_BARRIER'),
    );
    expect(
      () => privacy.exportDiagnostic(includeCredentials: true),
      code('SNAPSHOT_PRIVACY_BARRIER'),
    );
    final basis = privacy.exportProductionBasis(
      includePolicyFacts: true,
      includeCredentials: false,
      includeDeletedBodies: false,
    );
    expect(basis['policyFactsIncluded'], isTrue);
    expect(basis['credentialsIncluded'], isFalse);
    expect(basis['deletedBodiesIncluded'], isFalse);
    expect(basis['sessionPolicy'], 'excluded');
    expect(basis['sessionArchive'], isNull);
    expect(
      () => privacy.exportProductionBasis(
        includePolicyFacts: true,
        includeCredentials: true,
        includeDeletedBodies: false,
      ),
      code('SNAPSHOT_PRIVACY_BARRIER'),
    );
    expect(
      () => privacy.exportProductionBasis(
        includePolicyFacts: true,
        includeCredentials: false,
        includeDeletedBodies: true,
      ),
      code('SNAPSHOT_PRIVACY_BARRIER'),
    );
    expect(
      () => privacy.exportProductionBasis(
        includePolicyFacts: true,
        includeCredentials: false,
        includeDeletedBodies: false,
        sessionPolicy: 'selectedContent',
      ),
      code('SNAPSHOT_PRIVACY_BARRIER'),
    );
    expect(privacy.documentWrites, 0);
    expect(privacy.submitted, isFalse);
  });
}
