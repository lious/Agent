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

Directory _temp() => Directory.systemTemp.createTempSync('i036-');

String repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final schema = File(
      p.join(dir.path, 'schemas', 'character-pack.schema.json'),
    );
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (schema.existsSync() && pubspec.existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  throw StateError('repository root with official schemas not found');
}

Map<String, Object?> emptyOverrides() => {
  'wardrobe': null,
  'era': null,
  'stateDescription': null,
  'hairStyle': null,
};

Map<String, Object?> fictionalLanPack(
  Namespace ns, {
  String version = '1',
  String hair = 'short black hair',
  List<String> allowedUses = const [
    'referenceGeneration',
    'exportOutput',
    'redistributePack',
  ],
}) {
  final portrait = {
    'id': 'rights-lan',
    'version': '1',
    'subjectKind': 'fictional',
    'holderRef': 'holder-lan',
    'allowedUses': allowedUses,
    'allowedProviderIds': <String>[],
    'territories': <String>[],
    'expiresAt': null,
    'revocationAuthorityRef': 'authority-lan',
    'evidenceHash': null,
    'status': 'verified',
    'existingOutputsPolicy': 'retainAllowed',
  };
  final terms = {'notice': 'synthetic fictional license for Lan'};
  final termsHash = contentHash(terms);
  final lookId = 'look-blue-coat';
  final refBytes = Uint8List.fromList(
    utf8.encode('synthetic-front-view-lan-v$version'),
  );
  final refHash = rawBytesHash(refBytes);
  return {
    'schemaVersion': '1.0.0',
    'libraryId': 'lib-characters',
    'namespace': ns.toJson(),
    'asset': {
      'id': 'lan',
      'version': version,
      'name': '岚',
      'kind': 'fictional',
      'description': 'Fictional character Lan used only in DEV-PURE tests.',
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
        'distinctiveFeatures': <String>['blue coat in default look'],
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
      'portraitRightsId': 'rights-lan',
      'tags': ['fictional', 'dev-pure'],
    },
    'looks': [
      {
        'id': lookId,
        'label': 'blue coat',
        'era': 'contemporary',
        'wardrobe': 'blue coat',
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
        'rightsId': 'rights-lan',
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
        'rightsId': 'rights-lan',
      },
      {
        'hash': termsHash,
        'bytes': canonicalizeLength(terms),
        'mime': 'application/json',
        'role': 'licenseEvidence',
        'rightsId': 'rights-lan',
      },
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

String canonicalizeLength(Object value) =>
    canonicalBytes(value).length.toString();

Map<String, Object?> characterRefFor({
  required CharacterPackRef published,
  required Map<String, Object?> pack,
  required String rightsEpoch,
  Map<String, Object?>? overrides,
  String projectCharacterId = 'pc-lan',
}) {
  return {
    'projectCharacterId': projectCharacterId,
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

void putPackResources(CharacterRepository repo, Map<String, Object?> pack) {
  final terms = {'notice': 'synthetic fictional license for Lan'};
  repo.store.putCas(contentHash(terms), CanonicalBytes.of(terms));
  for (final item in (pack['resources'] as List)) {
    final hash = (item as Map)['hash'] as String;
    if (repo.store.hasCas(hash)) continue;
    // reference image payload is reconstructed from versioned utf8 marker
    final version = (pack['asset'] as Map)['version'] as String;
    final bytes = Uint8List.fromList(
      utf8.encode('synthetic-front-view-lan-v$version'),
    );
    if (rawBytesHash(bytes) == hash) {
      repo.store.putCas(hash, bytes);
    }
  }
}

class CanonicalBytes {
  static Uint8List of(Object value) => canonicalBytes(value);
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

  test('official 8G CharacterPack schema and T57 library DDL are closed', () {
    final root = repoRoot();
    final packSchema = File(
      p.join(root, 'schemas', 'character-pack.schema.json'),
    ).readAsStringSync();
    final refSchema = File(
      p.join(root, 'schemas', 'project-character-ref.schema.json'),
    ).readAsStringSync();
    final sql = File(p.join(root, 'schemas', 't57-library.sql'))
        .readAsStringSync();
    final t57 = jsonDecode(
      File(p.join(root, 'docs/studio/reference/t57Schemas.json'))
          .readAsStringSync(),
    ) as Map;
    expect(jsonDecode(packSchema), t57['characterPack']);
    expect(jsonDecode(refSchema), t57['projectCharacterRef']);
    expect(officialT57LibraryDdl, sql);
    expect(
      File(p.join(root, 'packages/studio_assets/schemas/t57-library.sql'))
          .readAsStringSync(),
      sql,
    );
    final store = CharacterLibraryStore.open(p.join(dir.path, 'lib'), appA);
    expect(store.userVersion, CharacterLibraryStore.libraryWorkspaceVersion);
    expect(store.userVersion, 6);
    expect(
      officialT57LibraryDdl,
      contains('CREATE VIRTUAL TABLE craft_fts USING fts5'),
    );
    expect(store.fts5Enabled, isFalse);
    final tables = store
        .select("SELECT name FROM sqlite_master WHERE type='table'")
        .map((row) => row['name'] as String)
        .toSet();
    expect(
      tables,
      containsAll([
        'library_versions',
        'library_heads',
        'library_project_pins',
        'portrait_rights_versions',
        'portrait_rights_live',
        'character_look_index',
        'model_adapter_bindings',
        'audio_candidates',
        'license_decisions',
      ]),
    );
    expect(tables.contains('craft_fts'), isFalse);
    store.close();
  });

  test(
    'CharacterPackValidator enforces 8G cross-reference and rights rules',
    () {
      const validator = CharacterPackValidator();
      final pack = fictionalLanPack(appA);
      validator.validatePack(pack);

      final age = cloneJson(pack);
      ((age['asset'] as Map)['traits'] as Map)['ageMin'] = 40;
      ((age['asset'] as Map)['traits'] as Map)['ageMax'] = 20;
      expect(() => validator.validatePack(age), code('SCHEMA_INVALID'));

      final real = cloneJson(pack);
      (real['asset'] as Map)['kind'] = 'realPerson';
      expect(() => validator.validatePack(real), code('BINDING_MISMATCH'));

      final cloneVoice = cloneJson(pack);
      final voice = Map<String, Object?>.from(
        (cloneVoice['asset'] as Map)['voice'] as Map,
      );
      voice['cloningAllowed'] = true;
      voice['voiceRightsId'] = 'rights-lan';
      (cloneVoice['asset'] as Map)['voice'] = voice;
      expect(() => validator.validatePack(cloneVoice), code('RIGHTS_REQUIRED'));
    },
  );

  test('global library upgrade does not change old project pins', () {
    final repo = CharacterRepository.open(p.join(dir.path, 'a'), appA);
    final v1 = fictionalLanPack(appA, version: '1', hair: 'short black hair');
    putPackResources(repo, v1);
    final draft = repo.createDraft(appA)..pack = v1;
    final published1 = repo.publish(
      draft,
      null,
      const RightsDecision.allow(rightsId: 'rights-lan', epoch: '0'),
    );
    expect(published1.version, '1');
    expect(repo.headVersion('lib-characters', 'lan'), '1');

    final ref1 = characterRefFor(
      published: published1,
      pack: v1,
      rightsEpoch: '0',
    );
    repo.pinProject(
      ProjectCharacterPin(projectId: 'ep1', revision: '1', ref: ref1),
    );
    repo.pinProject(
      ProjectCharacterPin(projectId: 'ep2', revision: '1', ref: ref1),
    );

    final forked = repo.forkVersion('lan', '1');
    (forked.pack['asset'] as Map)['traits'] = {
      ...(forked.pack['asset'] as Map)['traits'] as Map,
      'hairStyle': 'long black hair',
    };
    // New version needs its own resource bytes when the front-view payload changes.
    final v2pack = forked.pack;
    final newBytes = Uint8List.fromList(
      utf8.encode('synthetic-front-view-lan-v2'),
    );
    final newHash = rawBytesHash(newBytes);
    repo.store.putCas(newHash, newBytes);
    final refs = List<Map<String, Object?>>.from(
      (v2pack['references'] as List).map(
        (e) => Map<String, Object?>.from(e as Map),
      ),
    );
    refs[0]['blobHash'] = newHash;
    v2pack['references'] = refs;
    final resources = List<Map<String, Object?>>.from(
      (v2pack['resources'] as List).map(
        (e) => Map<String, Object?>.from(e as Map),
      ),
    );
    final image = Map<String, Object?>.from(
      resources.firstWhere((r) => r['role'] == 'referenceImage'),
    );
    image['hash'] = newHash;
    image['bytes'] = newBytes.length.toString();
    v2pack['resources'] = [
      image,
      ...resources.where((r) => r['role'] != 'referenceImage'),
    ];
    final published2 = repo.publish(
      forked,
      '1',
      const RightsDecision.allow(rightsId: 'rights-lan', epoch: '0'),
    );
    expect(published2.version, '2');
    expect(published2.packHash, isNot(published1.packHash));
    expect(repo.headVersion('lib-characters', 'lan'), '2');

    final ep1 = repo.projectPin(
      projectId: 'ep1',
      revision: '1',
      libraryId: 'lib-characters',
      assetId: 'lan',
    );
    final ep2 = repo.projectPin(
      projectId: 'ep2',
      revision: '1',
      libraryId: 'lib-characters',
      assetId: 'lan',
    );
    expect(ep1, ref1);
    expect(ep2, ref1);
    expect(ep1!['pinnedVersion'], '1');
    expect(ep1['packHash'], published1.packHash);
    expect(
      ((repo.loadPublished('lan', '1')['asset'] as Map)['traits']
          as Map)['hairStyle'],
      'short black hair',
    );
    expect(
      ((repo.loadHead('lib-characters', 'lan')['asset'] as Map)['traits']
          as Map)['hairStyle'],
      'long black hair',
    );
    repo.close();
  });

  test('upgrade keeps local wardrobe override and does not overwrite hand-edited captions', () {
    final repo = CharacterRepository.open(p.join(dir.path, 'a'), appA);
    final v1 = fictionalLanPack(appA, version: '1');
    putPackResources(repo, v1);
    final published1 = repo.publish(
      repo.createDraft(appA)..pack = v1,
      null,
      const RightsDecision.allow(rightsId: 'rights-lan', epoch: '0'),
    );
    final forked = repo.forkVersion('lan', '1');
    (forked.pack['asset'] as Map)['traits'] = {
      ...(forked.pack['asset'] as Map)['traits'] as Map,
      'hairStyle': 'long black hair',
    };
    final newBytes = Uint8List.fromList(
      utf8.encode('synthetic-front-view-lan-v2'),
    );
    final newHash = rawBytesHash(newBytes);
    repo.store.putCas(newHash, newBytes);
    final refs = List<Map<String, Object?>>.from(
      (forked.pack['references'] as List).map(
        (e) => Map<String, Object?>.from(e as Map),
      ),
    );
    refs[0]['blobHash'] = newHash;
    forked.pack['references'] = refs;
    final resources = List<Map<String, Object?>>.from(
      (forked.pack['resources'] as List).map(
        (e) => Map<String, Object?>.from(e as Map),
      ),
    );
    final image = Map<String, Object?>.from(
      resources.firstWhere((r) => r['role'] == 'referenceImage'),
    );
    image['hash'] = newHash;
    image['bytes'] = newBytes.length.toString();
    forked.pack['resources'] = [
      image,
      ...resources.where((r) => r['role'] != 'referenceImage'),
    ];
    final published2 = repo.publish(
      forked,
      '1',
      const RightsDecision.allow(rightsId: 'rights-lan', epoch: '0'),
    );

    final oldPin = characterRefFor(
      published: published1,
      pack: v1,
      rightsEpoch: '0',
      overrides: {
        'wardrobe': 'green coat',
        'era': null,
        'stateDescription': null,
        'hairStyle': null,
      },
    );
    repo.pinProject(
      ProjectCharacterPin(projectId: 'ep2', revision: '1', ref: oldPin),
    );
    final newPin = characterRefFor(
      published: published2,
      pack: repo.loadPublished('lan', '2'),
      rightsEpoch: '0',
    );
    const captions = [
      {'id': 'cue-1', 'text': 'hand-edited line', 'locked': true},
    ];
    const trim = {
      'start': '00:00:01.000',
      'end': '00:00:02.000',
      'locked': true,
    };
    final projectSlice = {
      'characterPin': oldPin,
      'captions': captions,
      'trim': trim,
      'locked': {'captions': captions, 'trim': trim},
    };
    final proposal = const CharacterUpgradePlanner().plan(
      oldPin: oldPin,
      newPin: newPin,
      localOverrides: {'wardrobe': 'green coat'},
      lockedPaths: {'captions': captions, 'trim': trim},
      appearancePromptDrafts: ['shot-lan-wide'],
    );
    expect(proposal.retainedOverrides['wardrobe'], 'green coat');
    expect(proposal.staleAppearancePromptDrafts, ['shot-lan-wide']);
    expect(proposal.newPin['pinnedVersion'], '2');
    expect(proposal.newPin['packHash'], published2.packHash);
    final applied = const CharacterUpgradePlanner().apply(
      projectSlice,
      proposal,
    );
    expect(applied['captions'], captions);
    expect(applied['trim'], trim);
    expect(applied['locked'], {'captions': captions, 'trim': trim});
    expect((applied['characterPin'] as Map)['pinnedVersion'], '2');
    expect(
      (applied['characterPin'] as Map)['overrides'],
      proposal.retainedOverrides,
    );
    repo.pinProject(
      ProjectCharacterPin(
        projectId: 'ep2',
        revision: '2',
        ref: Map<String, Object?>.from(applied['characterPin'] as Map),
      ),
    );
    // Previous revision pin is unchanged.
    expect(
      repo.projectPin(
        projectId: 'ep2',
        revision: '1',
        libraryId: 'lib-characters',
        assetId: 'lan',
      )?['pinnedVersion'],
      '1',
    );
    expect(
      () => const CharacterUpgradePlanner().plan(
        oldPin: oldPin,
        newPin: newPin,
        localOverrides: {'eyeColor': 'green'},
        lockedPaths: const {},
      ),
      code('BINDING_MISMATCH'),
    );
    repo.close();
  });

  test('after revoke, new generation and cache hits are 0', () {
    final repo = CharacterRepository.open(p.join(dir.path, 'a'), appA);
    final pack = fictionalLanPack(appA);
    putPackResources(repo, pack);
    final published = repo.publish(
      repo.createDraft(appA)..pack = pack,
      null,
      const RightsDecision.allow(rightsId: 'rights-lan', epoch: '0'),
    );
    final ref = characterRefFor(
      published: published,
      pack: pack,
      rightsEpoch: '0',
    );
    final now = DateTime.utc(2026, 11, 27, 3, 0, 0);
    repo.requestGeneration(
      characterRef: ref,
      provider: 'dev.pure',
      region: 'CN',
      now: now,
    );
    expect(repo.generations.dispatched, 1);
    expect(
      repo.lookupCache(
        characterRef: ref,
        provider: 'dev.pure',
        region: 'CN',
        now: now,
      ),
      isNotNull,
    );
    expect(repo.cache.hits, 1);

    final report = repo.revoke('rights-lan', '0');
    expect(report.state, 'revoked');
    expect(report.epoch, '1');
    expect(report.newGenerations, 0);
    expect(report.cacheHits, 0);
    expect(report.existingOutputsPolicy, 'retainAllowed');
    expect(
      () => repo.requestGeneration(
        characterRef: ref,
        provider: 'dev.pure',
        region: 'CN',
        now: now,
      ),
      code('RIGHTS_REVOKED'),
    );
    expect(repo.generations.dispatched, 0);
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
    // Historical pack bytes stay; revoke is a live access record.
    expect(repo.loadPublished('lan', '1')['asset'], isA<Map>());
    expect(
      () => repo.store.execute(
        'UPDATE library_versions SET body_hash=? WHERE entity_id=?',
        ['sha256:${'0' * 64}', 'lan'],
      ),
      throwsA(isA<Exception>()),
    );
    repo.close();
  });

  test('cross-app import does not inherit source grants or permissions', () {
    final dirA = Directory(p.join(dir.path, 'a'))..createSync();
    final dirB = Directory(p.join(dir.path, 'b'))..createSync();
    final repoA = CharacterRepository.open(dirA.path, appA);
    final pack = fictionalLanPack(appA);
    putPackResources(repoA, pack);
    final published = repoA.publish(
      repoA.createDraft(appA)..pack = pack,
      null,
      const RightsDecision.allow(rightsId: 'rights-lan', epoch: '0'),
    );
    final refA = characterRefFor(
      published: published,
      pack: pack,
      rightsEpoch: '0',
    );
    final now = DateTime.utc(2026, 11, 27, 3, 0, 0);
    repoA.requestGeneration(
      characterRef: refA,
      provider: 'dev.pure',
      region: 'CN',
      now: now,
    );
    expect(repoA.generations.dispatched, 1);

    final archivePath = p.join(dir.path, 'lan.pack.zip');
    final resources = [
      for (final item in (pack['resources'] as List))
        (item as Map)['hash'] as String,
    ];
    final receipt = repoA.exportPack(
      ref: published,
      selectedResources: resources,
      rightsDecision: const RightsDecision.allow(
        rightsId: 'rights-lan',
        epoch: '0',
      ),
      destinationPath: archivePath,
    );
    expect(receipt.packHash, published.packHash);

    expect(
      () => repoA.exportPack(
        ref: published,
        selectedResources: resources,
        rightsDecision: const RightsDecision.deny('RIGHTS_REQUIRED'),
        destinationPath: p.join(dir.path, 'denied.zip'),
      ),
      code('RIGHTS_REQUIRED'),
    );

    final noRedistribute = fictionalLanPack(
      appA,
      allowedUses: const ['referenceGeneration', 'exportOutput'],
    );
    // Export of a pack whose rights omit redistributePack is refused even
    // with an allow decision: requireExportRights checks the record.
    final blockedRepo = CharacterRepository.open(
      p.join(dir.path, 'blocked'),
      appA,
    );
    putPackResources(blockedRepo, noRedistribute);
    final blockedPub = blockedRepo.publish(
      blockedRepo.createDraft(appA)..pack = noRedistribute,
      null,
      const RightsDecision.allow(rightsId: 'rights-lan', epoch: '0'),
    );
    expect(
      () => blockedRepo.exportPack(
        ref: blockedPub,
        selectedResources: [
          for (final item in (noRedistribute['resources'] as List))
            (item as Map)['hash'] as String,
        ],
        rightsDecision: const RightsDecision.allow(
          rightsId: 'rights-lan',
          epoch: '0',
        ),
        destinationPath: p.join(dir.path, 'blocked.zip'),
      ),
      code('RIGHTS_REQUIRED'),
    );
    blockedRepo.close();

    final repoB = CharacterRepository.open(dirB.path, appB);
    final preview = repoB.importPack(
      fileToken: archivePath,
      targetNamespace: appB,
      collisionPolicy: characterImportRebuildLocalIds,
    );
    expect(preview.sourcePackHash, published.packHash);
    expect(preview.liveRightsState, 'unknown');
    expect(preview.packHash, isNot(published.packHash));
    expect(preview.assetId, isNot('lan'));
    expect(preview.idMap['lan'], preview.assetId);
    final imported = repoB.loadPublished(preview.assetId, preview.version);
    expect((imported['namespace'] as Map)['appId'], 'studio.app.b');
    final live = repoB.liveRights(preview.idMap['rights-lan']!);
    expect(live?['state'], 'unknown');

    final refB = characterRefFor(
      published: CharacterPackRef(
        libraryId: preview.libraryId,
        assetId: preview.assetId,
        version: preview.version,
        packHash: preview.packHash,
      ),
      pack: imported,
      rightsEpoch: live?['epoch'] as String? ?? '0',
    );
    expect(
      () => repoB.requestGeneration(
        characterRef: refB,
        provider: 'dev.pure',
        region: 'CN',
        now: now,
      ),
      code('RIGHTS_REQUIRED'),
    );
    expect(
      repoB.lookupCache(
        characterRef: refB,
        provider: 'dev.pure',
        region: 'CN',
        now: now,
      ),
      isNull,
    );

    // Local re-verification on App B does not copy App A grants, and a later
    // revoke on A leaves B's independently recorded decision intact.
    repoB.putLiveRights(
      rightsId: preview.idMap['rights-lan']!,
      epoch: '0',
      state: 'active',
    );
    repoB.requestGeneration(
      characterRef: refB,
      provider: 'dev.pure',
      region: 'CN',
      now: now,
    );
    expect(repoB.generations.dispatched, 1);
    repoA.revoke('rights-lan', '0');
    expect(repoB.liveRights(preview.idMap['rights-lan']!)?['state'], 'active');
    repoB.requestGeneration(
      characterRef: refB,
      provider: 'dev.pure',
      region: 'CN',
      now: now,
    );
    expect(repoB.generations.dispatched, 2);
    expect(repoA.liveRights('rights-lan')?['state'], 'revoked');
    expect(
      () => repoA.requestGeneration(
        characterRef: refA,
        provider: 'dev.pure',
        region: 'CN',
        now: now,
      ),
      code('RIGHTS_REVOKED'),
    );
    repoA.close();
    repoB.close();
  });

  test(
    'publish is refused on head conflict and leaves no half-published version',
    () {
      final repo = CharacterRepository.open(p.join(dir.path, 'a'), appA);
      final pack = fictionalLanPack(appA);
      putPackResources(repo, pack);
      repo.publish(
        repo.createDraft(appA)..pack = pack,
        null,
        const RightsDecision.allow(rightsId: 'rights-lan', epoch: '0'),
      );
      final stale = repo.forkVersion('lan', '1');
      expect(
        () => repo.publish(
          stale,
          null,
          const RightsDecision.allow(rightsId: 'rights-lan', epoch: '0'),
        ),
        code('HEAD_CONFLICT'),
      );
      expect(repo.headVersion('lib-characters', 'lan'), '1');
      final versions = repo.store.select(
        'SELECT version FROM library_versions WHERE entity_id=?',
        ['lan'],
      );
      expect(versions.length, 1);
      repo.close();
    },
  );
}
