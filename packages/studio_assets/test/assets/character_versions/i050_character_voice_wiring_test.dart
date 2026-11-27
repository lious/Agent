import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:studio_assets/studio_assets.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_voice/studio_voice.dart';
import 'package:test/test.dart';

Namespace get appA => Namespace('studio.app.a', 'tenant', 'ws');

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

Directory _temp() => Directory.systemTemp.createTempSync('i050-');

Map<String, Object?> emptyOverrides() => {
  'wardrobe': null,
  'era': null,
  'stateDescription': null,
  'hairStyle': null,
};

Map<String, Object?> cloneableLanPack(Namespace ns, {bool cloningAllowed = true}) {
  final terms = {'notice': 'synthetic fictional license for Lan'};
  final termsHash = contentHash(terms);
  const lookId = 'look-blue-coat';
  final refBytes = Uint8List.fromList(utf8.encode('synthetic-front-view-lan-v1'));
  final refHash = rawBytesHash(refBytes);
  final portrait = {
    'id': 'rights-lan',
    'version': '1',
    'subjectKind': 'fictional',
    'holderRef': 'holder-lan',
    'allowedUses': ['referenceGeneration', 'exportOutput', 'redistributePack'],
    'allowedProviderIds': <String>[],
    'territories': <String>[],
    'expiresAt': null,
    'revocationAuthorityRef': 'authority-lan',
    'evidenceHash': null,
    'status': 'verified',
    'existingOutputsPolicy': 'retainAllowed',
  };
  final voiceRights = {
    ...portrait,
    'id': 'voice-rights-lan',
    'allowedUses': ['voiceClone'],
  };
  return {
    'schemaVersion': '1.0.0',
    'libraryId': 'lib-characters',
    'namespace': ns.toJson(),
    'asset': {
      'id': 'lan',
      'version': '1',
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
        'hairStyle': 'short black hair',
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
        'cloningAllowed': cloningAllowed,
        'voiceRightsId': cloningAllowed ? 'voice-rights-lan' : null,
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
    'rights': [portrait, if (cloningAllowed) voiceRights],
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
        'bytes': canonicalBytes(terms).length.toString(),
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

void putPackResources(CharacterRepository repo, Map<String, Object?> pack) {
  final terms = {'notice': 'synthetic fictional license for Lan'};
  repo.store.putCas(contentHash(terms), canonicalBytes(terms));
  final version = (pack['asset'] as Map)['version'] as String;
  final bytes = Uint8List.fromList(
    utf8.encode('synthetic-front-view-lan-v$version'),
  );
  repo.store.putCas(rawBytesHash(bytes), bytes);
}

Map<String, Object?> characterRefFor({
  required CharacterPackRef published,
  required Map<String, Object?> pack,
}) {
  return {
    'projectCharacterId': 'pc-lan',
    'libraryId': published.libraryId,
    'assetId': published.assetId,
    'pinnedVersion': published.version,
    'packHash': published.packHash,
    'lookId': (pack['asset'] as Map)['defaultLookId'],
    'overrides': emptyOverrides(),
    'bindingId': null,
    'rightsEpoch': '0',
  };
}

void main() {
  late Directory dir;
  setUp(() => dir = _temp());
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  (CharacterRepository, Map<String, Object?>) publishCloneable() {
    final repo = CharacterRepository.open(p.join(dir.path, 'a'), appA);
    final pack = cloneableLanPack(appA);
    putPackResources(repo, pack);
    final published = repo.publish(
      repo.createDraft(appA)..pack = pack,
      null,
      const RightsDecision.allow(rightsId: 'rights-lan', epoch: '0'),
    );
    return (repo, characterRefFor(published: published, pack: pack));
  }

  test('CharacterRepository.voiceClone checks consent then fails closed without inference', () {
    final (repo, ref) = publishCloneable();
    repo.voiceConsent.grant(
      VoiceConsent(
        consentId: 'consent-1',
        subjectPersonId: 'lan',
        voiceProfileId: 'voice-lan',
        uses: {'voiceClone'},
        grantedAt: DateTime.utc(2026, 11, 27),
      ),
    );
    expect(
      () => repo.requestVoiceClone(
        characterRef: ref,
        voiceProfileId: 'voice-lan',
        traceId: 'trace-lan',
        referencePcm: const [0, 1, 2, 3],
        provider: 'dev.pure',
        region: 'CN',
        now: DateTime.utc(2026, 11, 27),
      ),
      code(cloneInferenceUnavailable),
    );
    expect(repo.voiceConsent.executionCount('voice-lan'), 0);
    expect(repo.generations.dispatched, 0);
    expect(() => repo.voiceStore.readSealed('emb-1'), code(voiceProfileMissing));
    repo.close();
  });

  test('missing consent is CONSENT_REQUIRED, not FEATURE_NOT_IMPLEMENTED', () {
    final (repo, ref) = publishCloneable();
    expect(
      () => repo.requestVoiceClone(
        characterRef: ref,
        voiceProfileId: 'voice-lan',
        traceId: 'trace-lan',
        referencePcm: const [0, 1, 2, 3],
        provider: 'dev.pure',
        region: 'CN',
        now: DateTime.utc(2026, 11, 27),
      ),
      code(consentRequired),
    );
    repo.close();
  });

  test('cloningAllowed false is refused as RIGHTS_REQUIRED before any backend call', () {
    final repo = CharacterRepository.open(p.join(dir.path, 'b'), appA);
    final pack = cloneableLanPack(appA, cloningAllowed: false);
    putPackResources(repo, pack);
    final published = repo.publish(
      repo.createDraft(appA)..pack = pack,
      null,
      const RightsDecision.allow(rightsId: 'rights-lan', epoch: '0'),
    );
    final ref = characterRefFor(published: published, pack: pack);
    repo.voiceConsent.grant(
      VoiceConsent(
        consentId: 'consent-1',
        subjectPersonId: 'lan',
        voiceProfileId: 'voice-lan',
        uses: {'voiceClone'},
        grantedAt: DateTime.utc(2026, 11, 27),
      ),
    );
    expect(
      () => repo.requestVoiceClone(
        characterRef: ref,
        voiceProfileId: 'voice-lan',
        traceId: 'trace-lan',
        referencePcm: const [0, 1, 2, 3],
        provider: 'dev.pure',
        region: 'CN',
        now: DateTime.utc(2026, 11, 27),
      ),
      code('RIGHTS_REQUIRED'),
    );
    expect(repo.voiceConsent.executionCount('voice-lan'), 0);
    repo.close();
  });
}
