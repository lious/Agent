import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:studio_assets/studio_assets.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

Namespace get appA => Namespace('studio.app.a', 'tenant', 'ws');
Namespace get appB => Namespace('studio.app.b', 'tenant', 'ws');

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

Directory _temp() => Directory.systemTemp.createTempSync('i036-bind-');

Map<String, Object?> emptyOverrides() => {
  'wardrobe': null,
  'era': null,
  'stateDescription': null,
  'hairStyle': null,
};

Map<String, Object?> fictionalPack(
  Namespace ns, {
  required String assetId,
  required String name,
  required String rightsId,
  String version = '1',
  String libraryId = 'lib-characters',
  String hair = 'short black hair',
  String lookId = 'look-blue-coat',
  String wardrobe = 'blue coat',
  String lookLabel = 'blue coat',
  String marker = 'front',
  List<Map<String, Object?>> extraLooks = const [],
  List<Map<String, Object?>> extraReferences = const [],
  List<Map<String, Object?>> extraResources = const [],
}) {
  final portrait = {
    'id': rightsId,
    'version': '1',
    'subjectKind': 'fictional',
    'holderRef': 'holder-$assetId',
    'allowedUses': const [
      'referenceGeneration',
      'exportOutput',
      'redistributePack',
    ],
    'allowedProviderIds': <String>[],
    'territories': <String>[],
    'expiresAt': null,
    'revocationAuthorityRef': 'authority-$assetId',
    'evidenceHash': null,
    'status': 'verified',
    'existingOutputsPolicy': 'retainAllowed',
  };
  final terms = {'notice': 'synthetic fictional license for $name'};
  final termsHash = contentHash(terms);
  final refBytes = Uint8List.fromList(
    utf8.encode('synthetic-$marker-view-$assetId-v$version'),
  );
  final refHash = rawBytesHash(refBytes);
  final defaultRefId = 'ref-$marker';
  return {
    'schemaVersion': '1.0.0',
    'libraryId': libraryId,
    'namespace': ns.toJson(),
    'asset': {
      'id': assetId,
      'version': version,
      'name': name,
      'kind': 'fictional',
      'description': 'Fictional character $name used only in DEV-PURE tests.',
      'traits': {
        'ageMin': 24,
        'ageMax': 28,
        'ageBasis': 'fictionalDesign',
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
        'distinctiveFeatures': <String>['$wardrobe in default look'],
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
      'tags': ['fictional', 'dev-pure', assetId],
    },
    'looks': [
      {
        'id': lookId,
        'label': lookLabel,
        'era': 'contemporary',
        'wardrobe': wardrobe,
        'hairOverride': null,
        'makeup': null,
        'stateDescription': 'standing, relaxed',
        'referenceIds': [defaultRefId],
        'forbiddenChanges': <String>['change face identity'],
      },
      ...extraLooks,
    ],
    'references': [
      {
        'id': defaultRefId,
        'lookId': lookId,
        'role': 'front',
        'blobHash': refHash,
        'expression': 'neutral',
        'source': 'syntheticApproved',
        'rightsId': rightsId,
      },
      ...extraReferences,
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
      ...extraResources,
    ],
    'license': {
      'codeLicense': 'synthetic-dev-pure',
      'weightLicense': null,
      'termsHash': termsHash,
      'attributionText': 'Fictional test character. No real-person likeness.',
      'sourceUrls': <String>[],
    },
    'signatureRef': null,
  };
}

Map<String, Object?> lanPack(
  Namespace ns, {
  String version = '1',
  String hair = 'short black hair',
  List<Map<String, Object?>> extraLooks = const [],
  List<Map<String, Object?>> extraReferences = const [],
  List<Map<String, Object?>> extraResources = const [],
}) => fictionalPack(
  ns,
  assetId: 'lan',
  name: '岚',
  rightsId: 'rights-lan',
  version: version,
  hair: hair,
  extraLooks: extraLooks,
  extraReferences: extraReferences,
  extraResources: extraResources,
);

void putPackResources(CharacterRepository repo, Map<String, Object?> pack) {
  final name = (pack['asset'] as Map)['name'] as String;
  final terms = {'notice': 'synthetic fictional license for $name'};
  repo.store.putCas(contentHash(terms), canonicalBytes(terms));
  final assetId = (pack['asset'] as Map)['id'] as String;
  final version = (pack['asset'] as Map)['version'] as String;
  for (final item in pack['resources'] as List) {
    final hash = (item as Map)['hash'] as String;
    if (repo.store.hasCas(hash)) continue;
    for (final marker in const ['front', 'full']) {
      final bytes = Uint8List.fromList(
        utf8.encode('synthetic-$marker-view-$assetId-v$version'),
      );
      if (rawBytesHash(bytes) == hash) {
        repo.store.putCas(hash, bytes);
        break;
      }
    }
  }
}

CharacterPackRef publishPack(
  CharacterRepository repo,
  Map<String, Object?> pack, {
  String? expectedHead,
  String rightsId = 'rights-lan',
  String epoch = '0',
}) {
  putPackResources(repo, pack);
  return repo.publish(
    repo.createDraft(repo.namespace)..pack = pack,
    expectedHead,
    RightsDecision.allow(rightsId: rightsId, epoch: epoch),
  );
}

Map<String, Object?> sliceProject({
  required String rightsId,
  List<Map<String, Object?>> assets = const [],
  List<Map<String, Object?>> characters = const [],
}) => {
  'projectId': 'proj-lan',
  'revision': '1',
  'characters': characters,
  'assets': assets,
  'rightsRecords': [
    {'id': rightsId},
  ],
  'extensions': <String, Object?>{},
};

Map<String, Object?> projectImageAsset({
  required String id,
  required String rightsId,
  String version = '1',
}) => {
  'id': id,
  'version': version,
  'name': 'admitted-appearance',
  'kind': 'image',
  'originalBlobHash': null,
  'externalLocator': null,
  'streams': <Map<String, Object?>>[],
  'proxyRefs': <Map<String, Object?>>[],
  'rightsId': rightsId,
  'contentFingerprint':
      'sha256:0000000000000000000000000000000000000000000000000000000000000000',
  'status': 'ready',
};

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

  test('@ mention scan searches only the authorized library and records a locked-version ref without uploading pack images', () {
    final repoA = CharacterRepository.open(p.join(dir.path, 'a'), appA);
    final repoB = CharacterRepository.open(p.join(dir.path, 'b'), appB);
    publishPack(repoA, lanPack(appA));
    publishPack(
      repoA,
      fictionalPack(
        appA,
        assetId: 'he',
        name: '禾',
        rightsId: 'rights-he',
        lookId: 'look-green',
        wardrobe: 'green jacket',
        lookLabel: 'green jacket',
      ),
      rightsId: 'rights-he',
    );
    publishPack(repoB, lanPack(appB));

    expect(repoA.store.fts5Enabled, isFalse);
    final tables = repoA.store
        .select("SELECT name FROM sqlite_master WHERE type='table'")
        .map((row) => row['name'] as String)
        .toSet();
    expect(tables.contains('craft_fts'), isFalse);

    final searchA = ProjectCharacterMentionSearch(repoA);
    final all = searchA.search('');
    expect(all.map((hit) => hit.assetId).toSet(), {'lan', 'he'});
    final lanHits = searchA.search('@岚');
    expect(lanHits, hasLength(1));
    expect(lanHits.single.assetId, 'lan');
    expect(lanHits.single.name, '岚');
    expect(lanHits.single.versions, hasLength(1));
    expect(lanHits.single.versions.single.lockedVersion, '1');
    expect(lanHits.single.versions.single.isHead, isTrue);
    expect(searchA.search('禾').single.assetId, 'he');
    expect(searchA.search('no-such-character'), isEmpty);
    // The currently authorized library is this namespace, not App B.
    expect(ProjectCharacterMentionSearch(repoB).search('岚'), hasLength(1));
    expect(
      searchA.search('岚', libraryId: 'lib-characters').single.assetId,
      'lan',
    );

    final session = CharacterMentionSession();
    final ref = session.select(
      repository: repoA,
      projectCharacterId: 'pc-lan',
      libraryId: 'lib-characters',
      assetId: 'lan',
      pinnedVersion: '1',
      lookId: 'look-blue-coat',
    );
    expect(ref['pinnedVersion'], '1');
    expect(ref['packHash'], lanHits.single.versions.single.packHash);
    expect(ref['lookId'], 'look-blue-coat');
    expect(ref['assetId'], 'lan');
    CharacterRepository.validator.validateProjectCharacterRef(ref);
    expect(session.refs, [ref]);
    expect(session.selectors, hasLength(1));
    expect(session.selectors.single.pinnedVersion, '1');
    expect(session.storedPackImages, isEmpty);
    // Selecting a ref must not copy pack image bytes into the session.
    expect(session.refs.single.keys, isNot(contains('resources')));
    expect(jsonEncode(session.refs), isNot(contains('synthetic-front-view')));
    repoA.close();
    repoB.close();
  });

  test('ProjectCharacterResolver.resolve applies legal overrides and fails closed on revoked live rights', () {
    final repo = CharacterRepository.open(p.join(dir.path, 'a'), appA);
    final secondLookId = 'look-red-cape';
    final secondBytes = Uint8List.fromList(
      utf8.encode('synthetic-full-view-lan-v1'),
    );
    final secondHash = rawBytesHash(secondBytes);
    repo.store.putCas(secondHash, secondBytes);
    final pack = lanPack(
      appA,
      extraLooks: [
        {
          'id': secondLookId,
          'label': 'red cape',
          'era': 'festival',
          'wardrobe': 'red cape',
          'hairOverride': null,
          'makeup': null,
          'stateDescription': 'bowing',
          'referenceIds': ['ref-full'],
          'forbiddenChanges': <String>['drop the cape'],
        },
      ],
      extraReferences: [
        {
          'id': 'ref-full',
          'lookId': secondLookId,
          'role': 'fullBody',
          'blobHash': secondHash,
          'expression': 'neutral',
          'source': 'syntheticApproved',
          'rightsId': 'rights-lan',
        },
      ],
      extraResources: [
        {
          'hash': secondHash,
          'bytes': secondBytes.length.toString(),
          'mime': 'application/octet-stream',
          'role': 'referenceImage',
          'rightsId': 'rights-lan',
        },
      ],
    );
    final published = publishPack(repo, pack);
    final session = CharacterMentionSession();
    final baseRef = session.select(
      repository: repo,
      projectCharacterId: 'pc-lan',
      libraryId: published.libraryId,
      assetId: published.assetId,
      pinnedVersion: published.version,
      lookId: 'look-blue-coat',
    );
    final resolve = ProjectCharacterResolver(repo);
    final scoped = CharacterResolveScope(
      operation: 'referenceGeneration',
      provider: 'dev-pure',
      region: 'test',
      now: DateTime.utc(2026, 11, 27, 6, 20),
      projectId: 'proj-lan',
      shotId: 'shot-1',
    );
    final resolved = resolve.resolve(
      baseRef,
      scoped,
      repo.liveRights('rights-lan'),
    );
    expect(resolved.assetId, 'lan');
    expect(resolved.pinnedVersion, '1');
    expect(resolved.packHash, published.packHash);
    expect(resolved.lookId, 'look-blue-coat');
    expect(resolved.voicePlanRef, isNull);
    expect(resolved.selectedReferenceRefs, hasLength(1));
    expect(resolved.selectedReferenceRefs.single.id, 'ref-front');
    expect(resolved.selectedReferenceRefs.single.version, '1');
    expect(resolved.effectiveAppearanceText, contains('岚'));
    expect(resolved.effectiveAppearanceText, contains('blue coat'));
    expect(resolved.effectiveAppearanceText, isNot(contains('red cape')));
    expect(resolved.constraints, contains('face shape'));
    expect(resolved.constraints, isNot(contains('drop the cape')));

    final hairRef = Map<String, Object?>.from(baseRef);
    hairRef['overrides'] = {
      ...emptyOverrides(),
      'hairStyle': 'long black hair',
    };
    final hairResolved = resolve.resolve(
      hairRef,
      scoped,
      repo.liveRights('rights-lan'),
    );
    expect(hairResolved.effectiveTraitHash, isNot(resolved.effectiveTraitHash));
    expect(hairResolved.effectiveAppearanceText, contains('long black hair'));

    final wardrobeRef = Map<String, Object?>.from(baseRef);
    wardrobeRef['overrides'] = {...emptyOverrides(), 'wardrobe': 'green coat'};
    final wardrobeResolved = resolve.resolve(
      wardrobeRef,
      scoped,
      repo.liveRights('rights-lan'),
    );
    expect(
      wardrobeResolved.effectiveAppearanceText,
      contains('wardrobe: green coat'),
    );
    expect(
      wardrobeResolved.effectiveAppearanceText,
      isNot(contains('blue coat')),
    );

    final mismatched = Map<String, Object?>.from(baseRef);
    mismatched['packHash'] = 'sha256:0000000000000000000000000000000000000000000000000000000000000000';
    expect(
      () => resolve.resolve(mismatched, scoped, repo.liveRights('rights-lan')),
      code('BINDING_MISMATCH'),
    );

    final report = repo.revoke('rights-lan', '0');
    expect(report.state, 'revoked');
    expect(
      () => resolve.resolve(baseRef, scoped, repo.liveRights('rights-lan')),
      code('RIGHTS_REVOKED'),
    );
    // A stale allow snapshot cannot bypass the live revoked row.
    expect(
      () => resolve.resolve(baseRef, scoped, {
        'rights_id': 'rights-lan',
        'epoch': '0',
        'state': 'active',
      }),
      code('RIGHTS_REVOKED'),
    );
    repo.close();
  });

  test('CharacterPromptInjector.compile injects only this shot appearance, wardrobe, action, and anti-drift constraints', () {
    final repo = CharacterRepository.open(p.join(dir.path, 'a'), appA);
    final secondBytes = Uint8List.fromList(
      utf8.encode('synthetic-full-view-lan-v1'),
    );
    final secondHash = rawBytesHash(secondBytes);
    repo.store.putCas(secondHash, secondBytes);
    final pack = lanPack(
      appA,
      extraLooks: [
        {
          'id': 'look-red-cape',
          'label': 'red cape',
          'era': 'festival',
          'wardrobe': 'red cape',
          'hairOverride': null,
          'makeup': null,
          'stateDescription': 'bowing',
          'referenceIds': ['ref-full'],
          'forbiddenChanges': <String>['drop the cape'],
        },
      ],
      extraReferences: [
        {
          'id': 'ref-full',
          'lookId': 'look-red-cape',
          'role': 'fullBody',
          'blobHash': secondHash,
          'expression': 'neutral',
          'source': 'syntheticApproved',
          'rightsId': 'rights-lan',
        },
      ],
      extraResources: [
        {
          'hash': secondHash,
          'bytes': secondBytes.length.toString(),
          'mime': 'application/octet-stream',
          'role': 'referenceImage',
          'rightsId': 'rights-lan',
        },
      ],
    );
    final published = publishPack(repo, pack);
    final ref = CharacterMentionSession().select(
      repository: repo,
      projectCharacterId: 'pc-lan',
      libraryId: published.libraryId,
      assetId: published.assetId,
      pinnedVersion: published.version,
      lookId: 'look-blue-coat',
      overrides: {...emptyOverrides(), 'wardrobe': 'green coat'},
    );
    final resolved = ProjectCharacterResolver(repo).resolve(
      ref,
      CharacterResolveScope(
        operation: 'referenceGeneration',
        provider: 'dev-pure',
        region: 'test',
        now: DateTime.utc(2026, 11, 27, 6, 20),
      ),
      repo.liveRights('rights-lan'),
    );
    final plan = CharacterPromptInjector(repo).compile(
      resolved,
      const CharacterShotInput(shotId: 'shot-1', action: 'walks to the window'),
      const ProviderCapability(firstFrameSlots: 1),
    );
    final prompt = plan.promptSections.join('\n');
    expect(prompt, contains('appearance:'));
    expect(prompt, contains('green coat'));
    expect(prompt, contains('action: walks to the window'));
    expect(prompt, contains('do-not-drift:'));
    expect(prompt, contains('face shape'));
    expect(prompt, contains('IDENTITY_SOFT_CONSTRAINT'));
    expect(prompt, isNot(contains('red cape')));
    expect(prompt, isNot(contains('calm mid register')));
    expect(prompt, isNot(contains('ageMin')));
    expect(prompt, isNot(contains('eyeShape')));
    expect(prompt, isNot(contains('fictionalDesign')));
    expect(plan.providerImageInputs, hasLength(1));
    expect(plan.providerImageInputs.single['role'], 'front');
    expect(plan.providerImageInputs.single['source'], 'libraryPack');
    expect(plan.adapterLoadRefs, isEmpty);
    repo.close();
  });

  test('CharacterPromptInjector returns REFERENCE_SLOT_CONFLICT when a single first-frame slot would drop one side', () {
    final repo = CharacterRepository.open(p.join(dir.path, 'a'), appA);
    final published = publishPack(repo, lanPack(appA));
    final resolved = ProjectCharacterResolver(repo).resolve(
      CharacterMentionSession().select(
        repository: repo,
        projectCharacterId: 'pc-lan',
        libraryId: published.libraryId,
        assetId: published.assetId,
        pinnedVersion: published.version,
        lookId: 'look-blue-coat',
      ),
      CharacterResolveScope(
        operation: 'referenceGeneration',
        provider: 'dev-pure',
        region: 'test',
        now: DateTime.utc(2026, 11, 27, 6, 20),
      ),
      repo.liveRights('rights-lan'),
    );
    final injector = CharacterPromptInjector(repo);
    const product = CharacterShotInput(
      shotId: 'shot-product',
      action: 'holds the bottle',
      hasProductFirstFrame: true,
      productFirstFrameRef: {'id': 'product-frame', 'version': '1'},
    );
    expect(
      () => injector.compile(
        resolved,
        product,
        const ProviderCapability(firstFrameSlots: 1),
      ),
      code('REFERENCE_SLOT_CONFLICT'),
    );
    final both = injector.compile(
      resolved,
      product,
      const ProviderCapability(
        firstFrameSlots: 2,
        supportsMultiReference: true,
      ),
    );
    expect(both.providerImageInputs.map((input) => input['role']).toSet(), {
      'front',
      'productFirstFrame',
    });
    final textOnly = injector.compile(
      resolved,
      product,
      const ProviderCapability(firstFrameSlots: 1, textOnly: true),
    );
    expect(textOnly.providerImageInputs.map((input) => input['role']), [
      'productFirstFrame',
    ]);
    expect(textOnly.warnings, contains('TEXT_ONLY_NO_REFERENCE_IMAGES'));
    repo.close();
  });

  test('identity consistency is IDENTITY_SOFT_CONSTRAINT and is never marked as a pixel lock', () {
    final repo = CharacterRepository.open(p.join(dir.path, 'a'), appA);
    final published = publishPack(repo, lanPack(appA));
    final resolved = ProjectCharacterResolver(repo).resolve(
      CharacterMentionSession().select(
        repository: repo,
        projectCharacterId: 'pc-lan',
        libraryId: published.libraryId,
        assetId: published.assetId,
        pinnedVersion: published.version,
        lookId: 'look-blue-coat',
      ),
      CharacterResolveScope(
        operation: 'referenceGeneration',
        provider: 'dev-pure',
        region: 'test',
        now: DateTime.utc(2026, 11, 27, 6, 20),
      ),
      repo.liveRights('rights-lan'),
    );
    final plan = CharacterPromptInjector(repo).compile(
      resolved,
      const CharacterShotInput(shotId: 'shot-1', action: 'turns'),
      const ProviderCapability(firstFrameSlots: 1),
    );
    expect(
      plan.identityConsistency,
      CharacterBindingPlan.identitySoftConstraint,
    );
    expect(plan.pixelLocked, isFalse);
    expect(plan.toJson()['pixelLocked'], isFalse);
    final encoded = jsonEncode(plan.toJson());
    expect(encoded, contains('IDENTITY_SOFT_CONSTRAINT'));
    expect(encoded.toLowerCase(), isNot(contains('pixel lock')));
    expect(encoded, isNot(contains('PIXEL_LOCK')));
    expect(encoded, isNot(contains('IDENTITY_PIXEL')));
    repo.close();
  });

  test('materialize writes name, constraints, and extension refs; appearanceRef attach stops on missing I-004 surfaces', () {
    final repo = CharacterRepository.open(p.join(dir.path, 'a'), appA);
    final published = publishPack(repo, lanPack(appA));
    final ref = CharacterMentionSession().select(
      repository: repo,
      projectCharacterId: 'pc-lan',
      libraryId: published.libraryId,
      assetId: published.assetId,
      pinnedVersion: published.version,
      lookId: 'look-blue-coat',
      overrides: {...emptyOverrides(), 'wardrobe': 'green coat'},
    );
    final resolved = ProjectCharacterResolver(repo).resolve(
      ref,
      CharacterResolveScope(
        operation: 'referenceGeneration',
        provider: 'dev-pure',
        region: 'test',
        now: DateTime.utc(2026, 11, 27, 6, 20),
      ),
      repo.liveRights('rights-lan'),
    );
    const materializer = ProjectCharacterMaterializer();
    final first = materializer.materialize(
      project: sliceProject(rightsId: 'rights-project-lan'),
      projectCharacterRef: ref,
      resolved: resolved,
      projectCharacterId: 'pc-lan',
      projectRightsId: 'rights-project-lan',
    );
    expect(first.appearanceRefWritten, isFalse);
    expect(first.character['appearanceRef'], isNull);
    expect(first.character['name'], '岚');
    expect(first.character['constraints'], contains('face shape'));
    expect(first.character['version'], '1');
    expect(first.character['version'], resolved.pinnedVersion);
    expect(first.character.keys, isNot(contains('pinnedVersion')));
    expect(first.character.keys, isNot(contains('packHash')));
    expect(first.character.keys.toSet(), {
      'id',
      'version',
      'name',
      'appearanceRef',
      'motivation',
      'constraints',
      'rightsId',
    });
    expect(first.missingSurfaces, missingAppearanceAttachSurfaces);
    expect(first.missingSurfaces, [
      'AssetRepository',
      'RelinkProposal',
      'FileToken',
    ]);
    expect(first.extension.keys.toSet(), {
      'schemaVersion',
      'refs',
      'portablePackHashes',
    });
    expect(first.extension['schemaVersion'], '1.0.0');
    expect(first.extension['refs'], [ref]);
    expect(first.extension['portablePackHashes'], [published.packHash]);
    expect(first.project.keys.toSet(), {
      'projectId',
      'revision',
      'characters',
      'assets',
      'rightsRecords',
      'extensions',
    });
    expect(
      (first.project['extensions'] as Map)[characterLibraryExtensionKey],
      first.extension,
    );

    final second = materializer.materialize(
      project: first.project,
      projectCharacterRef: ref,
      resolved: resolved,
      projectCharacterId: 'pc-lan',
      projectRightsId: 'rights-project-lan',
    );
    expect(second.character['version'], '2');
    expect(resolved.pinnedVersion, '1');
    expect(second.character['version'], isNot(resolved.pinnedVersion));
    expect((second.extension['refs'] as List), hasLength(1));

    expect(
      () => materializer.materialize(
        project: sliceProject(rightsId: 'rights-project-lan'),
        projectCharacterRef: ref,
        resolved: resolved,
        projectCharacterId: 'pc-lan',
        projectRightsId: 'rights-project-lan',
        admittedProjectAppearance: {
          'id': 'lan',
          'version': resolved.pinnedVersion,
        },
      ),
      code('BINDING_MISMATCH'),
    );

    final admittedId = 'proj-appearance-lan';
    final admitted = materializer.materialize(
      project: sliceProject(
        rightsId: 'rights-project-lan',
        assets: [
          projectImageAsset(id: admittedId, rightsId: 'rights-project-lan'),
        ],
      ),
      projectCharacterRef: ref,
      resolved: resolved,
      projectCharacterId: 'pc-lan',
      projectRightsId: 'rights-project-lan',
      admittedProjectAppearance: {'id': admittedId, 'version': '1'},
    );
    expect(admitted.appearanceRefWritten, isTrue);
    expect(admitted.missingSurfaces, isEmpty);
    expect(admitted.character['appearanceRef'], {
      'id': admittedId,
      'version': '1',
    });
    expect((admitted.character['appearanceRef'] as Map)['id'], isNot('lan'));
    repo.close();
  });
}
