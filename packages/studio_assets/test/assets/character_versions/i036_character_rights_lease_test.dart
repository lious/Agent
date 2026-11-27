import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:studio_assets/studio_assets.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

Namespace get appA => Namespace('studio.app.a', 'tenant', 'ws');

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

Directory _temp() => Directory.systemTemp.createTempSync('i036-lease-');

Map<String, Object?> emptyOverrides() => {
  'wardrobe': null,
  'era': null,
  'stateDescription': null,
  'hairStyle': null,
};

Map<String, Object?> syntheticPack(
  Namespace ns, {
  required String assetId,
  required String name,
  required String rightsId,
  required String kind,
  required String subjectKind,
  String version = '1',
  String hair = 'short black hair',
  String existingOutputsPolicy = existingOutputsRetainAllowed,
  List<String> allowedUses = const [
    'referenceGeneration',
    'training',
    'upload',
    'exportOutput',
    'redistributePack',
  ],
}) {
  final portrait = {
    'id': rightsId,
    'version': '1',
    'subjectKind': subjectKind,
    'holderRef': 'holder-$assetId',
    'allowedUses': allowedUses,
    'allowedProviderIds': <String>[],
    'territories': <String>[],
    'expiresAt': null,
    'revocationAuthorityRef': 'authority-$assetId',
    'evidenceHash': null,
    'status': 'verified',
    'existingOutputsPolicy': existingOutputsPolicy,
  };
  final terms = {'notice': 'synthetic $subjectKind license for $name'};
  final termsHash = contentHash(terms);
  final lookId = 'look-default';
  final refBytes = Uint8List.fromList(
    utf8.encode('synthetic-front-view-$assetId-v$version'),
  );
  final refHash = rawBytesHash(refBytes);
  return {
    'schemaVersion': '1.0.0',
    'libraryId': 'lib-characters',
    'namespace': ns.toJson(),
    'asset': {
      'id': assetId,
      'version': version,
      'name': name,
      'kind': kind,
      'description':
          'Synthetic $subjectKind character used only in DEV-PURE tests.',
      'traits': {
        'ageMin': 24,
        'ageMax': 28,
        'ageBasis': subjectKind == 'realPerson'
            ? 'userDeclared'
            : 'fictionalDesign',
        'heightCm': 170,
        'bodyBuild': 'slim',
        'posture': 'upright',
        'eyeShape': 'almond',
        'eyeColor': 'dark brown',
        'nose': 'straight',
        'mouth': 'neutral',
        'jaw': 'soft',
        'brows': 'natural',
        'ears': 'average',
        'skinToneNotes': 'warm light',
        'hairStyle': hair,
        'hairColor': 'black',
        'distinctiveFeatures': <String>['synthetic test look'],
        'doNotDrift': <String>['face shape', 'eye color'],
      },
      'voice': {
        'description': 'calm mid register, not a cloned voice',
        'languages': ['zh', 'en'],
        'registerIntent': 'mid',
        'accentIntent': null,
        'speedIntent': null,
        'sampleHashes': <String>[],
        'cloningAllowed': false,
        'voiceRightsId': null,
        'providerSpeakerIdRef': null,
      },
      'defaultLookId': lookId,
      'portraitRightsId': rightsId,
      'tags': [subjectKind, 'dev-pure'],
    },
    'looks': [
      {
        'id': lookId,
        'label': 'default look',
        'era': 'contemporary',
        'wardrobe': 'neutral coat',
        'hairOverride': null,
        'makeup': null,
        'stateDescription': 'standing, relaxed',
        'referenceIds': ['ref-front'],
        'forbiddenChanges': <String>['change face identity'],
      },
    ],
    'references': [
      {
        'id': 'ref-front',
        'lookId': lookId,
        'role': 'front',
        'blobHash': refHash,
        'expression': 'neutral',
        'source': 'syntheticApproved',
        'rightsId': rightsId,
      },
    ],
    'bindings': <Map<String, Object?>>[],
    'rights': [portrait],
    'resources': [
      {
        'hash': refHash,
        'bytes': refBytes.length.toString(),
        'mime': 'application/octet-stream',
        'role': 'referenceImage',
        'rightsId': rightsId,
      },
      {
        'hash': termsHash,
        'bytes': canonicalBytes(terms).length.toString(),
        'mime': 'application/json',
        'role': 'licenseEvidence',
        'rightsId': rightsId,
      },
    ],
    'license': {
      'codeLicense': 'synthetic-dev-pure',
      'weightLicense': null,
      'termsHash': termsHash,
      'attributionText':
          'Synthetic test character. No biometric identification.',
      'sourceUrls': <String>[],
    },
    'signatureRef': null,
  };
}

Map<String, Object?> fictionalPack(
  Namespace ns, {
  String version = '1',
  String existingOutputsPolicy = existingOutputsRetainAllowed,
}) => syntheticPack(
  ns,
  assetId: 'lan',
  name: '岚',
  rightsId: 'rights-lan',
  kind: 'fictional',
  subjectKind: 'fictional',
  version: version,
  existingOutputsPolicy: existingOutputsPolicy,
);

Map<String, Object?> realPersonPack(
  Namespace ns, {
  String version = '1',
  String existingOutputsPolicy = existingOutputsRetainAllowed,
}) => syntheticPack(
  ns,
  assetId: 'pat',
  name: 'Pat',
  rightsId: 'rights-pat',
  kind: 'realPerson',
  subjectKind: 'realPerson',
  version: version,
  existingOutputsPolicy: existingOutputsPolicy,
);

void putPackResources(CharacterRepository repo, Map<String, Object?> pack) {
  final name = (pack['asset'] as Map)['name'] as String;
  final subject = (pack['asset'] as Map)['kind'] as String;
  final kindLabel = subject == 'realPerson' ? 'realPerson' : 'fictional';
  final terms = {'notice': 'synthetic $kindLabel license for $name'};
  repo.store.putCas(contentHash(terms), canonicalBytes(terms));
  final assetId = (pack['asset'] as Map)['id'] as String;
  final version = (pack['asset'] as Map)['version'] as String;
  for (final item in pack['resources'] as List) {
    final hash = (item as Map)['hash'] as String;
    if (repo.store.hasCas(hash)) continue;
    final bytes = Uint8List.fromList(
      utf8.encode('synthetic-front-view-$assetId-v$version'),
    );
    if (rawBytesHash(bytes) == hash) {
      repo.store.putCas(hash, bytes);
    }
  }
}

CharacterPackRef publishPack(
  CharacterRepository repo,
  Map<String, Object?> pack, {
  String? expectedHead,
  required String rightsId,
  String epoch = '0',
}) {
  putPackResources(repo, pack);
  return repo.publish(
    repo.createDraft(repo.namespace)..pack = pack,
    expectedHead,
    RightsDecision.allow(rightsId: rightsId, epoch: epoch),
  );
}

Map<String, Object?> characterRefFor({
  required CharacterPackRef published,
  required Map<String, Object?> pack,
  required String rightsEpoch,
  Map<String, Object?>? overrides,
}) {
  return {
    'projectCharacterId': 'pc-${published.assetId}',
    'libraryId': published.libraryId,
    'assetId': published.assetId,
    'pinnedVersion': published.version,
    'packHash': published.packHash,
    'lookId': (pack['asset'] as Map)['defaultLookId'],
    'overrides': overrides ?? emptyOverrides(),
    'bindingId': null,
    'rightsEpoch': rightsEpoch,
  };
}

void main() {
  late Directory dir;

  setUp(() {
    dir = _temp();
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  test('real-person new cloud generation is blocked when offline or the lease has expired, and requires a fresh online check stub', () {
    final repo = CharacterRepository.open(p.join(dir.path, 'a'), appA);
    final fictional = fictionalPack(appA);
    final real = realPersonPack(appA);
    final fictionalPub = publishPack(repo, fictional, rightsId: 'rights-lan');
    final realPub = publishPack(repo, real, rightsId: 'rights-pat');
    final fictionalRef = characterRefFor(
      published: fictionalPub,
      pack: fictional,
      rightsEpoch: '0',
    );
    final realRef = characterRefFor(
      published: realPub,
      pack: real,
      rightsEpoch: '0',
    );
    final now = DateTime.utc(2026, 11, 27, 7, 0, 0);

    // Fictional characters use live epoch records and do not require an
    // online check, even when the device is offline.
    repo.requestGeneration(
      characterRef: fictionalRef,
      provider: 'dev.pure',
      region: 'CN',
      now: now,
      context: const DispatchContext(cloud: true, offline: true),
    );
    expect(repo.generations.dispatched, 1);

    // Real-person cloud generation without a lease requires a fresh check.
    expect(
      () => repo.requestGeneration(
        characterRef: realRef,
        provider: 'dev.pure',
        region: 'CN',
        now: now,
        context: const DispatchContext(cloud: true, offline: true),
      ),
      code('FRESH_ONLINE_CHECK_REQUIRED'),
    );

    final expired = now.subtract(const Duration(hours: 1));
    repo.putLiveRights(
      rightsId: 'rights-pat',
      epoch: '0',
      state: 'active',
      checkedAt: expired.toIso8601String(),
      leaseUntil: expired.toIso8601String(),
    );
    expect(
      () => repo.requestGeneration(
        characterRef: realRef,
        provider: 'dev.pure',
        region: 'CN',
        now: now,
        context: const DispatchContext(cloud: true, offline: true),
      ),
      code('FRESH_ONLINE_CHECK_REQUIRED'),
    );

    final stub = ScriptedOnlineRightsCheck(
      fresh: true,
      leaseUntil: now.add(const Duration(hours: 6)),
    );
    expect(stub.invokedPaidNetwork, isFalse);
    repo.requestGeneration(
      characterRef: realRef,
      provider: 'dev.pure',
      region: 'CN',
      now: now,
      context: DispatchContext(cloud: true, offline: false, onlineCheck: stub),
    );
    expect(stub.callCount, 1);
    expect(stub.invokedPaidNetwork, isFalse);
    expect(repo.generations.dispatched, 2);
    expect(repo.liveRights('rights-pat')?['lease_until'], isNotNull);

    // A still-valid lease can satisfy the freshness window even offline.
    repo.requestGeneration(
      characterRef: realRef,
      provider: 'dev.pure',
      region: 'CN',
      now: now.add(const Duration(hours: 1)),
      context: const DispatchContext(cloud: true, offline: true),
    );
    expect(repo.generations.dispatched, 3);
    repo.close();
  });

  test('a pin freezes content not permission, and restoring an old pack cannot bypass a known revocation', () {
    final repo = CharacterRepository.open(p.join(dir.path, 'a'), appA);
    final pack = realPersonPack(appA);
    final published = publishPack(repo, pack, rightsId: 'rights-pat');
    final ref = characterRefFor(
      published: published,
      pack: pack,
      rightsEpoch: '0',
    );
    final now = DateTime.utc(2026, 11, 27, 7, 0, 0);
    final stub = ScriptedOnlineRightsCheck(
      fresh: true,
      leaseUntil: now.add(const Duration(hours: 6)),
    );
    final cloud = DispatchContext(
      cloud: true,
      offline: false,
      onlineCheck: stub,
    );
    repo.requestGeneration(
      characterRef: ref,
      provider: 'dev.pure',
      region: 'CN',
      now: now,
      context: cloud,
    );
    repo.pinProject(
      ProjectCharacterPin(projectId: 'ep1', revision: '1', ref: ref),
    );
    expect(
      repo.projectPin(
        projectId: 'ep1',
        revision: '1',
        libraryId: published.libraryId,
        assetId: published.assetId,
      )?['packHash'],
      published.packHash,
    );

    final archivePath = p.join(dir.path, 'pat.pack.zip');
    final resources = [
      for (final item in (pack['resources'] as List))
        (item as Map)['hash'] as String,
    ];
    repo.exportPack(
      ref: published,
      selectedResources: resources,
      rightsDecision: const RightsDecision.allow(
        rightsId: 'rights-pat',
        epoch: '0',
      ),
      destinationPath: archivePath,
    );

    final report = repo.revoke('rights-pat', '0');
    expect(report.state, 'revoked');
    expect(report.epoch, '1');
    // The pin still resolves to the same content hash, but live permission
    // is denied — including when a still-valid lease row would otherwise
    // have been in window.
    expect(
      () => repo.requestGeneration(
        characterRef: ref,
        provider: 'dev.pure',
        region: 'CN',
        now: now,
        context: cloud,
      ),
      code('RIGHTS_REVOKED'),
    );
    expect(
      () => repo.putLiveRights(
        rightsId: 'rights-pat',
        epoch: '1',
        state: 'active',
      ),
      code('RIGHTS_REVOKED'),
    );

    final preview = repo.importPack(
      fileToken: archivePath,
      targetNamespace: appA,
      collisionPolicy: characterImportRebuildLocalIds,
    );
    expect(preview.liveRightsState, 'revoked');
    expect(preview.sourcePackHash, published.packHash);
    final imported = repo.loadPublished(preview.assetId, preview.version);
    final restoredRef = characterRefFor(
      published: CharacterPackRef(
        libraryId: preview.libraryId,
        assetId: preview.assetId,
        version: preview.version,
        packHash: preview.packHash,
      ),
      pack: imported,
      rightsEpoch: preview.liveRightsState == 'revoked' ? '0' : '0',
    );
    expect(
      () => repo.requestGeneration(
        characterRef: restoredRef,
        provider: 'dev.pure',
        region: 'CN',
        now: now,
        context: cloud,
      ),
      code('RIGHTS_REVOKED'),
    );
    expect(
      () => repo.putLiveRights(
        rightsId: (imported['asset'] as Map)['portraitRightsId'] as String,
        epoch: '0',
        state: 'active',
      ),
      code('RIGHTS_REVOKED'),
    );
    repo.close();
  });

  test('dispatch denies generation, training, and reference upload after revoke using live authority/epoch', () {
    final repo = CharacterRepository.open(p.join(dir.path, 'a'), appA);
    final pack = fictionalPack(appA);
    final published = publishPack(repo, pack, rightsId: 'rights-lan');
    final ref = characterRefFor(
      published: published,
      pack: pack,
      rightsEpoch: '0',
    );
    final now = DateTime.utc(2026, 11, 27, 7, 0, 0);
    repo.pinCandidateTask(
      CandidateTaskPin(
        taskId: 'task-running',
        libraryId: published.libraryId,
        entityId: published.assetId,
        version: published.version,
        packHash: published.packHash,
        state: 'processing',
      ),
    );
    repo.pinCandidateTask(
      CandidateTaskPin(
        taskId: 'task-late',
        libraryId: published.libraryId,
        entityId: published.assetId,
        version: published.version,
        packHash: published.packHash,
        state: 'ready',
      ),
    );
    repo.dispatch(
      operation: 'referenceGeneration',
      characterRef: ref,
      provider: 'dev.pure',
      region: 'CN',
      now: now,
    );
    repo.dispatch(
      operation: 'training',
      characterRef: ref,
      provider: 'dev.pure',
      region: 'CN',
      now: now,
    );
    repo.dispatch(
      operation: 'upload',
      characterRef: ref,
      provider: 'dev.pure',
      region: 'CN',
      now: now,
    );
    expect(repo.generations.dispatched, 3);
    expect(
      repo.lookupCache(
        characterRef: ref,
        provider: 'dev.pure',
        region: 'CN',
        now: now,
      ),
      isNotNull,
    );

    final report = repo.revoke('rights-lan', '0');
    expect(report.state, 'revoked');
    expect(report.newGenerations, 0);
    expect(report.cacheHits, 0);
    expect(report.cancelledTasks, 1);
    expect(report.isolatedTasks, 1);
    expect(
      repo.gc
          .candidatePinsForRightsPack(
            libraryId: published.libraryId,
            entityId: published.assetId,
            version: published.version,
          )
          .map((row) => '${row['task_id']}:${row['state']}')
          .toSet(),
      {'task-running:cancelled', 'task-late:isolated'},
    );

    for (final operation in ['referenceGeneration', 'training', 'upload']) {
      expect(
        () => repo.dispatch(
          operation: operation,
          characterRef: ref,
          provider: 'dev.pure',
          region: 'CN',
          now: now,
        ),
        code('RIGHTS_REVOKED'),
      );
    }
    expect(
      repo.lookupCache(
        characterRef: ref,
        provider: 'dev.pure',
        region: 'CN',
        now: now,
      ),
      isNull,
    );
    expect(repo.cache.hits, 0);
    expect(
      () => repo.pinCandidateTask(
        CandidateTaskPin(
          taskId: 'task-after',
          libraryId: published.libraryId,
          entityId: published.assetId,
          version: published.version,
          packHash: published.packHash,
        ),
      ),
      code('RIGHTS_REVOKED'),
    );
    repo.close();
  });

  test('a candidate result that arrives after revoke is isolated and is not accepted as a ready output', () {
    final repo = CharacterRepository.open(p.join(dir.path, 'a'), appA);
    final pack = fictionalPack(appA);
    final published = publishPack(repo, pack, rightsId: 'rights-lan');
    repo.pinCandidateTask(
      CandidateTaskPin(
        taskId: 'task-inflight',
        libraryId: published.libraryId,
        entityId: published.assetId,
        version: published.version,
        packHash: published.packHash,
        state: 'processing',
      ),
    );
    final report = repo.revoke('rights-lan', '0');
    expect(report.state, 'revoked');
    expect(report.cancelledTasks, 1);
    expect(
      repo.gc
          .candidatePinsForRightsPack(
            libraryId: published.libraryId,
            entityId: published.assetId,
            version: published.version,
          )
          .single['state'],
      'cancelled',
    );

    final output = File(p.join(dir.path, 'late-arrival.bin'))
      ..writeAsStringSync('late-arrival-bytes');
    final arrival = repo.arriveCandidateResult(
      taskId: 'task-inflight',
      outputPath: output.path,
      outputId: 'late-out',
    );
    expect(arrival.isolated, isTrue);
    expect(arrival.outputAccepted, isFalse);
    expect(arrival.state, 'isolated');
    expect(arrival.code, 'RIGHTS_REVOKED');
    expect(
      repo.gc
          .candidatePinsForRightsPack(
            libraryId: published.libraryId,
            entityId: published.assetId,
            version: published.version,
          )
          .single['state'],
      'isolated',
    );
    // The late payload is not a normal ready/success output. The user
    // file is not deleted.
    expect(output.existsSync(), isTrue);
    expect(output.readAsStringSync(), 'late-arrival-bytes');
    expect(repo.revocation.existingOutputs('rights-lan').outputs, isEmpty);
    expect(
      () => repo.revocation.useExistingOutput('late-out'),
      code('RESOURCE_MISSING'),
    );
    repo.close();
  });

  test(
    'existing outputs follow existingOutputsPolicy and are never deleted',
    () {
      void verifyPolicy(String policy, String expectedCode) {
        final sub = Directory(p.join(dir.path, policy))..createSync();
        final repo = CharacterRepository.open(p.join(sub.path, 'lib'), appA);
        final pack = fictionalPack(appA, existingOutputsPolicy: policy);
        final published = publishPack(repo, pack, rightsId: 'rights-lan');
        final ref = characterRefFor(
          published: published,
          pack: pack,
          rightsEpoch: '0',
        );
        final output = File(p.join(sub.path, 'user-output.bin'))
          ..writeAsStringSync('user-kept-bytes');
        repo.requestGeneration(
          characterRef: ref,
          provider: 'dev.pure',
          region: 'CN',
          now: DateTime.utc(2026, 11, 27, 7, 0, 0),
          outputPath: output.path,
          outputId: 'out-$policy',
        );
        final report = repo.revoke('rights-lan', '0');
        expect(report.existingOutputsPolicy, policy);
        final disposition = repo.revocation.existingOutputs('rights-lan');
        expect(disposition.policy, policy);
        expect(disposition.deletedAny, isFalse);
        expect(disposition.outputs, hasLength(1));
        expect(disposition.outputs.single.fileRetained, isTrue);
        expect(output.existsSync(), isTrue);
        expect(output.readAsStringSync(), 'user-kept-bytes');
        if (policy == existingOutputsRetainAllowed) {
          final used = repo.revocation.useExistingOutput('out-$policy');
          expect(used.disposition, existingOutputsRetainAllowed);
          expect(used.fileRetained, isTrue);
        } else {
          expect(
            () => repo.revocation.useExistingOutput('out-$policy'),
            code(expectedCode),
          );
        }
        expect(output.existsSync(), isTrue);
        repo.close();
      }

      verifyPolicy(existingOutputsRetainAllowed, '');
      verifyPolicy(existingOutputsBlockUse, 'RIGHTS_OUTPUT_BLOCKED');
      verifyPolicy(
        existingOutputsReviewRequired,
        'RIGHTS_OUTPUT_REVIEW_REQUIRED',
      );
    },
  );

  test('library GC treats project, export, and candidate-task pins as roots; deleting a head does not delete a pinned version', () {
    final repo = CharacterRepository.open(p.join(dir.path, 'a'), appA);
    final v1 = fictionalPack(
      appA,
      version: '1',
      existingOutputsPolicy: existingOutputsRetainAllowed,
    );
    final published1 = publishPack(repo, v1, rightsId: 'rights-lan');
    final v2 = fictionalPack(appA, version: '2');
    ((v2['asset'] as Map)['traits'] as Map)['hairStyle'] = 'long black hair';
    putPackResources(repo, v2);
    // v2 uses a new reference payload; publish after resources are stored.
    final published2 = repo.publish(
      repo.createDraft(appA)..pack = v2,
      '1',
      const RightsDecision.allow(rightsId: 'rights-lan', epoch: '0'),
    );
    expect(repo.headVersion(published2.libraryId, published2.assetId), '2');

    final ref1 = characterRefFor(
      published: published1,
      pack: v1,
      rightsEpoch: '0',
    );
    repo.pinProject(
      ProjectCharacterPin(projectId: 'old-ep', revision: '1', ref: ref1),
    );

    final archivePath = p.join(dir.path, 'lan-v2.zip');
    repo.exportPack(
      ref: published2,
      selectedResources: [
        for (final item in (v2['resources'] as List))
          (item as Map)['hash'] as String,
      ],
      rightsDecision: const RightsDecision.allow(
        rightsId: 'rights-lan',
        epoch: '0',
      ),
      destinationPath: archivePath,
    );
    repo.pinCandidateTask(
      CandidateTaskPin(
        taskId: 'cand-v2',
        libraryId: published2.libraryId,
        entityId: published2.assetId,
        version: published2.version,
        packHash: published2.packHash,
        state: 'processing',
      ),
    );

    final headGone = repo.gc.deleteHead(
      published2.libraryId,
      published2.assetId,
    );
    expect(headGone.deletedHeadVersion, '2');
    expect(headGone.remainingVersions, ['1', '2']);
    // Old project still resolves the pinned v1 pack.
    expect(
      repo.projectPin(
        projectId: 'old-ep',
        revision: '1',
        libraryId: published1.libraryId,
        assetId: published1.assetId,
      )?['pinnedVersion'],
      '1',
    );
    expect(repo.loadPublished('lan', '1')['asset'], isA<Map>());
    expect(repo.loadPublished('lan', '2')['asset'], isA<Map>());

    final blockedV1 = repo.gc.recycle(
      libraryId: published1.libraryId,
      entityId: published1.assetId,
      version: '1',
    );
    expect(blockedV1.recycled, isFalse);
    expect(blockedV1.code, 'HAS_REFERENCES');
    expect(blockedV1.referenceCount, 1);

    final blockedV2 = repo.gc.recycle(
      libraryId: published2.libraryId,
      entityId: published2.assetId,
      version: '2',
    );
    expect(blockedV2.recycled, isFalse);
    expect(blockedV2.code, 'HAS_REFERENCES');
    expect(blockedV2.referenceCount, 2);

    repo.gc.releaseExportPin(
      contentHash({
        'destinationPath': archivePath,
        'packHash': published2.packHash,
      }),
    );
    final stillBlocked = repo.gc.recycle(
      libraryId: published2.libraryId,
      entityId: published2.assetId,
      version: '2',
    );
    expect(stillBlocked.recycled, isFalse);
    expect(stillBlocked.referenceCount, 1);

    repo.gc.releaseCandidatePin('cand-v2');
    final recycled = repo.gc.recycle(
      libraryId: published2.libraryId,
      entityId: published2.assetId,
      version: '2',
    );
    expect(recycled.recycled, isTrue);
    expect(() => repo.loadPublished('lan', '2'), code('RESOURCE_MISSING'));
    expect(repo.loadPublished('lan', '1')['asset'], isA<Map>());
    repo.close();
  });

  test('recycle is refused for retained or revocation-cleanup versions and may be retried after cleanup is released', () {
    final repo = CharacterRepository.open(p.join(dir.path, 'a'), appA);
    final v1 = fictionalPack(appA, version: '1');
    final published1 = publishPack(repo, v1, rightsId: 'rights-lan');
    final v2 = fictionalPack(appA, version: '2');
    ((v2['asset'] as Map)['traits'] as Map)['hairStyle'] = 'long black hair';
    putPackResources(repo, v2);
    repo.publish(
      repo.createDraft(appA)..pack = v2,
      '1',
      const RightsDecision.allow(rightsId: 'rights-lan', epoch: '0'),
    );

    repo.gc.deleteHead(published1.libraryId, published1.assetId);
    repo.gc.retainVersion(
      planId: 'retain-v1',
      libraryId: published1.libraryId,
      entityId: published1.assetId,
      version: '1',
    );
    final retained = repo.gc.recycle(
      libraryId: published1.libraryId,
      entityId: published1.assetId,
      version: '1',
    );
    expect(retained.recycled, isFalse);
    expect(retained.retryable, isFalse);
    expect(retained.code, 'RETAINED');
    expect(repo.loadPublished('lan', '1')['asset'], isA<Map>());

    repo.gc.planRevocationCleanup(
      planId: 'cleanup-v2',
      libraryId: published1.libraryId,
      entityId: published1.assetId,
      version: '2',
    );
    final pending = repo.gc.recycle(
      libraryId: published1.libraryId,
      entityId: published1.assetId,
      version: '2',
    );
    expect(pending.recycled, isFalse);
    expect(pending.retryable, isTrue);
    expect(pending.code, 'REVOCATION_CLEANUP_PENDING');
    expect(repo.loadPublished('lan', '2')['asset'], isA<Map>());

    repo.gc.releasePlan('cleanup-v2');
    final retried = repo.gc.recycle(
      libraryId: published1.libraryId,
      entityId: published1.assetId,
      version: '2',
    );
    expect(retried.recycled, isTrue);
    expect(retried.retryable, isFalse);
    expect(() => repo.loadPublished('lan', '2'), code('RESOURCE_MISSING'));
    // Access was already independently blocked by revoke in other cases;
    // physical GC here only proceeds after the cleanup plan is released.
    repo.close();
  });
}
