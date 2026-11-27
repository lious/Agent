import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

final _id = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$');
final _u64 = RegExp(r'^(0|[1-9][0-9]{0,18})$');
final _hash = RegExp(r'^sha256:[0-9a-f]{64}$');
final _timestamp = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$');

const _lookRoles = {
  'front',
  'left',
  'right',
  'back',
  'threeQuarter',
  'fullBody',
  'expression',
  'wardrobeDetail',
};

const _allowedUses = {
  'referenceGeneration',
  'training',
  'voiceClone',
  'exportOutput',
  'redistributePack',
  'upload',
};

const _overrideKeys = {'wardrobe', 'era', 'stateDescription', 'hairStyle'};

/// Structural and 8G CharacterPackValidator checks. This is not a generic
/// Draft 2020-12 engine and does not run face recognition.
final class CharacterPackValidator {
  const CharacterPackValidator();

  void validatePack(Map<String, Object?> pack) {
    _object(pack, 'CharacterPack', {
      'schemaVersion',
      'libraryId',
      'namespace',
      'asset',
      'looks',
      'references',
      'bindings',
      'rights',
      'resources',
      'license',
      'signatureRef',
    });
    if (pack['schemaVersion'] != '1.0.0') {
      throw const StudioException('SCHEMA_INVALID', 'schemaVersion');
    }
    _idOf(pack['libraryId'], 'libraryId');
    _namespace(pack['namespace'], 'namespace');
    if (pack['signatureRef'] != null) {
      _hashOf(pack['signatureRef'], 'signatureRef');
    }
    _license(pack['license'], 'license');

    final asset = _map(pack['asset'], 'asset');
    _asset(asset, 'asset');

    final looks = _list(pack['looks'], 'looks', min: 1, max: 128);
    final lookIds = <String>{};
    for (var i = 0; i < looks.length; i++) {
      final look = _map(looks[i], 'looks/$i');
      _look(look, 'looks/$i');
      final id = look['id'] as String;
      if (!lookIds.add(id)) {
        throw StudioException('DUPLICATE_ID', 'looks/$i/id');
      }
    }
    if (!lookIds.contains(asset['defaultLookId'])) {
      throw const StudioException('RESOURCE_MISSING', 'asset.defaultLookId');
    }

    final rights = _list(pack['rights'], 'rights', min: 1, max: 128);
    final rightsById = <String, Map<String, Object?>>{};
    for (var i = 0; i < rights.length; i++) {
      final record = _map(rights[i], 'rights/$i');
      _rights(record, 'rights/$i');
      final id = record['id'] as String;
      if (rightsById.containsKey(id)) {
        throw StudioException('DUPLICATE_ID', 'rights/$i/id');
      }
      rightsById[id] = record;
    }

    final resources = _list(pack['resources'], 'resources', min: 0, max: 1024);
    final resourceByHash = <String, Map<String, Object?>>{};
    for (var i = 0; i < resources.length; i++) {
      final resource = _map(resources[i], 'resources/$i');
      _resource(resource, 'resources/$i');
      final hash = resource['hash'] as String;
      if (resourceByHash.containsKey(hash)) {
        throw StudioException('DUPLICATE_ID', 'resources/$i/hash');
      }
      resourceByHash[hash] = resource;
      final rightsId = resource['rightsId'] as String;
      if (!rightsById.containsKey(rightsId)) {
        throw StudioException('RESOURCE_MISSING', 'resources/$i/rightsId');
      }
    }

    final references = _list(
      pack['references'],
      'references',
      min: 0,
      max: 256,
    );
    final refIds = <String>{};
    for (var i = 0; i < references.length; i++) {
      final reference = _map(references[i], 'references/$i');
      _reference(reference, 'references/$i');
      final id = reference['id'] as String;
      if (!refIds.add(id)) {
        throw StudioException('DUPLICATE_ID', 'references/$i/id');
      }
      if (!lookIds.contains(reference['lookId'])) {
        throw StudioException('RESOURCE_MISSING', 'references/$i/lookId');
      }
      if (!rightsById.containsKey(reference['rightsId'])) {
        throw StudioException('RESOURCE_MISSING', 'references/$i/rightsId');
      }
      _requireResource(
        resourceByHash,
        reference['blobHash'] as String,
        'referenceImage',
        'references/$i/blobHash',
      );
    }

    for (final look in looks) {
      final pathBase = 'looks';
      final ids = _list(
        (look as Map)['referenceIds'],
        pathBase,
        min: 0,
        max: 64,
      );
      for (final id in ids) {
        if (id is! String || !refIds.contains(id)) {
          throw StudioException('RESOURCE_MISSING', '$pathBase/referenceIds');
        }
      }
    }

    final bindings = _list(pack['bindings'], 'bindings', min: 0, max: 128);
    final bindingIds = <String>{};
    for (var i = 0; i < bindings.length; i++) {
      final binding = _map(bindings[i], 'bindings/$i');
      _binding(binding, 'bindings/$i', rightsById);
      final id = binding['id'] as String;
      if (!bindingIds.add(id)) {
        throw StudioException('DUPLICATE_ID', 'bindings/$i/id');
      }
    }

    final portraitRightsId = asset['portraitRightsId'] as String;
    final portrait = rightsById[portraitRightsId];
    if (portrait == null) {
      throw const StudioException('RESOURCE_MISSING', 'asset.portraitRightsId');
    }
    if (asset['kind'] == 'realPerson' &&
        portrait['subjectKind'] == 'fictional') {
      throw const StudioException('BINDING_MISMATCH', 'asset.portraitRightsId');
    }

    final voice = _map(asset['voice'], 'asset.voice');
    if (voice['cloningAllowed'] == true) {
      final voiceRightsId = voice['voiceRightsId'];
      if (voiceRightsId is! String) {
        throw const StudioException(
          'RIGHTS_REQUIRED',
          'asset.voice.voiceRightsId',
        );
      }
      final voiceRights = rightsById[voiceRightsId];
      if (voiceRights == null) {
        throw const StudioException(
          'RESOURCE_MISSING',
          'asset.voice.voiceRightsId',
        );
      }
      final uses = (voiceRights['allowedUses'] as List).cast<String>();
      if (!uses.contains('voiceClone')) {
        throw const StudioException(
          'RIGHTS_REQUIRED',
          'asset.voice.voiceRightsId',
        );
      }
    }
    final samples = _list(
      voice['sampleHashes'],
      'asset.voice.sampleHashes',
      min: 0,
      max: 16,
    );
    for (var i = 0; i < samples.length; i++) {
      _requireResource(
        resourceByHash,
        _hashOf(samples[i], 'asset.voice.sampleHashes/$i'),
        'voiceReference',
        'asset.voice.sampleHashes/$i',
      );
    }
  }

  void validateProjectCharacterRef(Map<String, Object?> ref) {
    _object(ref, 'ProjectCharacterRef', {
      'projectCharacterId',
      'libraryId',
      'assetId',
      'pinnedVersion',
      'packHash',
      'lookId',
      'overrides',
      'bindingId',
      'rightsEpoch',
    });
    _idOf(ref['projectCharacterId'], 'projectCharacterId');
    _idOf(ref['libraryId'], 'libraryId');
    _idOf(ref['assetId'], 'assetId');
    _u64Of(ref['pinnedVersion'], 'pinnedVersion');
    _hashOf(ref['packHash'], 'packHash');
    _idOf(ref['lookId'], 'lookId');
    _u64Of(ref['rightsEpoch'], 'rightsEpoch');
    if (ref['bindingId'] != null) {
      _idOf(ref['bindingId'], 'bindingId');
    }
    final overrides = _map(ref['overrides'], 'overrides');
    _object(overrides, 'overrides', _overrideKeys);
    for (final key in _overrideKeys) {
      final value = overrides[key];
      if (value != null && value is! String) {
        throw StudioException('SCHEMA_INVALID', 'overrides.$key');
      }
    }
  }

  void requireExportRights(
    Map<String, Object?> pack,
    Iterable<String> selected,
  ) {
    validatePack(pack);
    final rights = {
      for (final item in (pack['rights'] as List))
        (item as Map)['id'] as String: Map<String, Object?>.from(item),
    };
    final assetRights =
        rights[(_map(pack['asset'], 'asset')['portraitRightsId'] as String)]!;
    _requireUse(assetRights, 'redistributePack', 'asset.portraitRightsId');
    final resources = {
      for (final item in (pack['resources'] as List))
        (item as Map)['hash'] as String: Map<String, Object?>.from(item),
    };
    for (final hash in selected) {
      final resource = resources[hash];
      if (resource == null) {
        throw StudioException('RESOURCE_MISSING', hash);
      }
      final record = rights[resource['rightsId'] as String];
      if (record == null) {
        throw StudioException('RESOURCE_MISSING', 'resources.rightsId');
      }
      _requireUse(record, 'redistributePack', 'resources.rightsId');
    }
  }

  static void _requireUse(
    Map<String, Object?> record,
    String use,
    String path,
  ) {
    final uses = (record['allowedUses'] as List).cast<String>();
    if (!uses.contains(use)) {
      throw StudioException('RIGHTS_REQUIRED', path);
    }
  }

  static void _requireResource(
    Map<String, Map<String, Object?>> resources,
    String hash,
    String role,
    String path,
  ) {
    final resource = resources[hash];
    if (resource == null) {
      throw StudioException('RESOURCE_MISSING', path);
    }
    if (resource['role'] != role) {
      throw StudioException('BINDING_MISMATCH', path);
    }
  }

  static void _asset(Map<String, Object?> asset, String path) {
    _object(asset, path, {
      'id',
      'version',
      'name',
      'kind',
      'description',
      'traits',
      'voice',
      'defaultLookId',
      'portraitRightsId',
      'tags',
    });
    _idOf(asset['id'], '$path.id');
    _u64Of(asset['version'], '$path.version');
    _string(asset['name'], '$path.name', 256);
    if (asset['kind'] != 'fictional' && asset['kind'] != 'realPerson') {
      throw StudioException('SCHEMA_INVALID', '$path.kind');
    }
    _string(asset['description'], '$path.description', 16384);
    _idOf(asset['defaultLookId'], '$path.defaultLookId');
    _idOf(asset['portraitRightsId'], '$path.portraitRightsId');
    final tags = _list(asset['tags'], '$path.tags', min: 0, max: 128);
    for (final tag in tags) {
      _string(tag, '$path.tags', 128);
    }
    _traits(_map(asset['traits'], '$path.traits'), '$path.traits');
    _voice(_map(asset['voice'], '$path.voice'), '$path.voice');
  }

  static void _traits(Map<String, Object?> traits, String path) {
    _object(traits, path, {
      'ageMin',
      'ageMax',
      'ageBasis',
      'heightCm',
      'bodyBuild',
      'posture',
      'eyeShape',
      'eyeColor',
      'nose',
      'mouth',
      'jaw',
      'brows',
      'ears',
      'skinToneNotes',
      'hairStyle',
      'hairColor',
      'distinctiveFeatures',
      'doNotDrift',
    });
    final ageMin = traits['ageMin'];
    final ageMax = traits['ageMax'];
    if (ageMin != null) _intRange(ageMin, 0, 120, '$path.ageMin');
    if (ageMax != null) _intRange(ageMax, 0, 120, '$path.ageMax');
    if (ageMin is int && ageMax is int && ageMin > ageMax) {
      throw StudioException('SCHEMA_INVALID', '$path.ageMin');
    }
    const bases = {'fictionalDesign', 'userDeclared', 'unknown'};
    if (!bases.contains(traits['ageBasis'])) {
      throw StudioException('SCHEMA_INVALID', '$path.ageBasis');
    }
    final height = traits['heightCm'];
    if (height != null) {
      if (height is! num || height < 30 || height > 250) {
        throw StudioException('SCHEMA_INVALID', '$path.heightCm');
      }
    }
    for (final field in [
      'bodyBuild',
      'posture',
      'eyeShape',
      'eyeColor',
      'nose',
      'mouth',
      'jaw',
      'brows',
      'ears',
      'skinToneNotes',
      'hairStyle',
      'hairColor',
    ]) {
      final max = (field == 'posture' || field == 'hairStyle')
          ? 1024
          : (field == 'bodyBuild' || field == 'hairColor' || field == 'eyeColor'
                ? 256
                : 512);
      final value = traits[field];
      if (value != null) _string(value, '$path.$field', max);
    }
    for (final field in ['distinctiveFeatures', 'doNotDrift']) {
      final values = _list(traits[field], '$path.$field', min: 0, max: 64);
      for (final value in values) {
        _string(value, '$path.$field', 1024);
      }
    }
  }

  static void _voice(Map<String, Object?> voice, String path) {
    _object(voice, path, {
      'description',
      'languages',
      'registerIntent',
      'accentIntent',
      'speedIntent',
      'sampleHashes',
      'cloningAllowed',
      'voiceRightsId',
      'providerSpeakerIdRef',
    });
    _string(voice['description'], '$path.description', 2048);
    final languages = _list(
      voice['languages'],
      '$path.languages',
      min: 0,
      max: 32,
    );
    for (final language in languages) {
      _string(language, '$path.languages', 64);
    }
    if (voice['registerIntent'] != null) {
      _string(voice['registerIntent'], '$path.registerIntent', 256);
    }
    if (voice['accentIntent'] != null) {
      _string(voice['accentIntent'], '$path.accentIntent', 512);
    }
    if (voice['speedIntent'] != null) {
      _string(voice['speedIntent'], '$path.speedIntent', 256);
    }
    if (voice['cloningAllowed'] is! bool) {
      throw StudioException('SCHEMA_INVALID', '$path.cloningAllowed');
    }
    if (voice['voiceRightsId'] != null) {
      _idOf(voice['voiceRightsId'], '$path.voiceRightsId');
    }
    if (voice['providerSpeakerIdRef'] != null) {
      _idOf(voice['providerSpeakerIdRef'], '$path.providerSpeakerIdRef');
    }
    final samples = _list(
      voice['sampleHashes'],
      '$path.sampleHashes',
      min: 0,
      max: 16,
    );
    for (var i = 0; i < samples.length; i++) {
      _hashOf(samples[i], '$path.sampleHashes/$i');
    }
  }

  static void _look(Map<String, Object?> look, String path) {
    _object(look, path, {
      'id',
      'label',
      'era',
      'wardrobe',
      'hairOverride',
      'makeup',
      'stateDescription',
      'referenceIds',
      'forbiddenChanges',
    });
    _idOf(look['id'], '$path.id');
    _string(look['label'], '$path.label', 256);
    if (look['era'] != null) _string(look['era'], '$path.era', 256);
    _string(look['wardrobe'], '$path.wardrobe', 4096);
    if (look['hairOverride'] != null) {
      _string(look['hairOverride'], '$path.hairOverride', 1024);
    }
    if (look['makeup'] != null) _string(look['makeup'], '$path.makeup', 1024);
    _string(look['stateDescription'], '$path.stateDescription', 2048);
    final refs = _list(
      look['referenceIds'],
      '$path.referenceIds',
      min: 0,
      max: 64,
    );
    for (final id in refs) {
      _idOf(id, '$path.referenceIds');
    }
    final forbidden = _list(
      look['forbiddenChanges'],
      '$path.forbiddenChanges',
      min: 0,
      max: 64,
    );
    for (final item in forbidden) {
      _string(item, '$path.forbiddenChanges', 1024);
    }
  }

  static void _reference(Map<String, Object?> reference, String path) {
    _object(reference, path, {
      'id',
      'lookId',
      'role',
      'blobHash',
      'expression',
      'source',
      'rightsId',
    });
    _idOf(reference['id'], '$path.id');
    _idOf(reference['lookId'], '$path.lookId');
    if (!_lookRoles.contains(reference['role'])) {
      throw StudioException('SCHEMA_INVALID', '$path.role');
    }
    _hashOf(reference['blobHash'], '$path.blobHash');
    if (reference['expression'] != null) {
      _string(reference['expression'], '$path.expression', 512);
    }
    if (reference['source'] != 'userProvided' &&
        reference['source'] != 'syntheticApproved') {
      throw StudioException('SCHEMA_INVALID', '$path.source');
    }
    _idOf(reference['rightsId'], '$path.rightsId');
  }

  static void _rights(Map<String, Object?> record, String path) {
    _object(record, path, {
      'id',
      'version',
      'subjectKind',
      'holderRef',
      'allowedUses',
      'allowedProviderIds',
      'territories',
      'expiresAt',
      'revocationAuthorityRef',
      'evidenceHash',
      'status',
      'existingOutputsPolicy',
    });
    _idOf(record['id'], '$path.id');
    _u64Of(record['version'], '$path.version');
    if (record['subjectKind'] != 'fictional' &&
        record['subjectKind'] != 'realPerson') {
      throw StudioException('SCHEMA_INVALID', '$path.subjectKind');
    }
    _idOf(record['holderRef'], '$path.holderRef');
    final uses = _list(
      record['allowedUses'],
      '$path.allowedUses',
      min: 0,
      max: 6,
    );
    final seen = <String>{};
    for (final use in uses) {
      if (use is! String || !_allowedUses.contains(use) || !seen.add(use)) {
        throw StudioException('SCHEMA_INVALID', '$path.allowedUses');
      }
    }
    final providers = _list(
      record['allowedProviderIds'],
      '$path.allowedProviderIds',
      min: 0,
      max: 64,
    );
    for (final id in providers) {
      _idOf(id, '$path.allowedProviderIds');
    }
    final territories = _list(
      record['territories'],
      '$path.territories',
      min: 0,
      max: 128,
    );
    for (final territory in territories) {
      _string(territory, '$path.territories', 64);
    }
    if (record['expiresAt'] != null) {
      _timestampOf(record['expiresAt'], '$path.expiresAt');
    }
    if (record['revocationAuthorityRef'] != null) {
      _idOf(record['revocationAuthorityRef'], '$path.revocationAuthorityRef');
    }
    if (record['evidenceHash'] != null) {
      _hashOf(record['evidenceHash'], '$path.evidenceHash');
    }
    const statuses = {'asserted', 'verified', 'revoked', 'expired'};
    if (!statuses.contains(record['status'])) {
      throw StudioException('SCHEMA_INVALID', '$path.status');
    }
    const policies = {'retainAllowed', 'blockUse', 'reviewRequired'};
    if (!policies.contains(record['existingOutputsPolicy'])) {
      throw StudioException('SCHEMA_INVALID', '$path.existingOutputsPolicy');
    }
  }

  static void _resource(Map<String, Object?> resource, String path) {
    _object(resource, path, {'hash', 'bytes', 'mime', 'role', 'rightsId'});
    _hashOf(resource['hash'], '$path.hash');
    _u64Of(resource['bytes'], '$path.bytes');
    _string(resource['mime'], '$path.mime', 128);
    const roles = {
      'referenceImage',
      'voiceReference',
      'adapter',
      'licenseEvidence',
    };
    if (!roles.contains(resource['role'])) {
      throw StudioException('SCHEMA_INVALID', '$path.role');
    }
    _idOf(resource['rightsId'], '$path.rightsId');
  }

  static void _binding(
    Map<String, Object?> binding,
    String path,
    Map<String, Map<String, Object?>> rights,
  ) {
    _object(binding, path, {
      'id',
      'kind',
      'providerProfileId',
      'baseModelFamily',
      'baseModelFingerprint',
      'encoderFingerprint',
      'embeddingLayout',
      'adapterBlobHash',
      'referenceRoles',
      'strategy',
      'preprocessorHash',
      'parameterHash',
      'trainingRightsId',
    });
    _idOf(binding['id'], '$path.id');
    final kind = binding['kind'];
    if (kind != 'referenceImages' &&
        kind != 'lora' &&
        kind != 'featureEmbedding') {
      throw StudioException('SCHEMA_INVALID', '$path.kind');
    }
    _idOf(binding['providerProfileId'], '$path.providerProfileId');
    _string(binding['baseModelFamily'], '$path.baseModelFamily', 128);
    if (binding['baseModelFingerprint'] != null) {
      _hashOf(binding['baseModelFingerprint'], '$path.baseModelFingerprint');
    }
    if (binding['encoderFingerprint'] != null) {
      _hashOf(binding['encoderFingerprint'], '$path.encoderFingerprint');
    }
    if (binding['embeddingLayout'] != null) {
      _string(binding['embeddingLayout'], '$path.embeddingLayout', 256);
    }
    if (binding['adapterBlobHash'] != null) {
      _hashOf(binding['adapterBlobHash'], '$path.adapterBlobHash');
    }
    final roles = _list(
      binding['referenceRoles'],
      '$path.referenceRoles',
      min: 0,
      max: 16,
    );
    for (final role in roles) {
      _string(role, '$path.referenceRoles', 64);
    }
    const strategies = {
      'singleFirstFrame',
      'multiReference',
      'subjectCondition',
      'textOnly',
    };
    if (!strategies.contains(binding['strategy'])) {
      throw StudioException('SCHEMA_INVALID', '$path.strategy');
    }
    if (binding['preprocessorHash'] != null) {
      _hashOf(binding['preprocessorHash'], '$path.preprocessorHash');
    }
    _hashOf(binding['parameterHash'], '$path.parameterHash');
    if (binding['trainingRightsId'] != null) {
      _idOf(binding['trainingRightsId'], '$path.trainingRightsId');
    }
    if (kind == 'lora' || kind == 'featureEmbedding') {
      if (binding['baseModelFingerprint'] == null ||
          binding['adapterBlobHash'] == null ||
          binding['trainingRightsId'] == null) {
        throw StudioException('BINDING_MISMATCH', path);
      }
      final training = rights[binding['trainingRightsId']];
      if (training == null) {
        throw StudioException('RESOURCE_MISSING', '$path.trainingRightsId');
      }
      _requireUse(training, 'training', '$path.trainingRightsId');
    }
    if (kind == 'featureEmbedding') {
      if (binding['encoderFingerprint'] == null ||
          binding['preprocessorHash'] == null ||
          binding['embeddingLayout'] == null) {
        throw StudioException('BINDING_MISMATCH', path);
      }
    }
  }

  static void _license(Object? value, String path) {
    final license = _map(value, path);
    _object(license, path, {
      'codeLicense',
      'weightLicense',
      'termsHash',
      'attributionText',
      'sourceUrls',
    });
    _string(license['codeLicense'], '$path.codeLicense', 128);
    if (license['weightLicense'] != null) {
      _string(license['weightLicense'], '$path.weightLicense', 128);
    }
    _hashOf(license['termsHash'], '$path.termsHash');
    _string(license['attributionText'], '$path.attributionText', 16384);
    final urls = _list(
      license['sourceUrls'],
      '$path.sourceUrls',
      min: 0,
      max: 32,
    );
    for (final url in urls) {
      _string(url, '$path.sourceUrls', 2048);
    }
  }

  static void _namespace(Object? value, String path) {
    final ns = _map(value, path);
    _object(ns, path, {'appId', 'tenantId', 'workspaceId'});
    _idOf(ns['appId'], '$path.appId');
    _idOf(ns['tenantId'], '$path.tenantId');
    _idOf(ns['workspaceId'], '$path.workspaceId');
  }

  static void _object(
    Map<String, Object?> value,
    String path,
    Set<String> keys,
  ) {
    for (final key in keys) {
      if (!value.containsKey(key)) {
        throw StudioException('SCHEMA_INVALID', '$path.$key');
      }
    }
    for (final key in value.keys) {
      if (!keys.contains(key)) {
        throw StudioException('SCHEMA_INVALID', '$path.$key');
      }
    }
  }

  static Map<String, Object?> _map(Object? value, String path) {
    if (value is! Map) {
      throw StudioException('SCHEMA_INVALID', path);
    }
    return Map<String, Object?>.from(value);
  }

  static List<Object?> _list(
    Object? value,
    String path, {
    required int min,
    required int max,
  }) {
    if (value is! List) {
      throw StudioException('SCHEMA_INVALID', path);
    }
    if (value.length < min || value.length > max) {
      throw StudioException('SCHEMA_INVALID', path);
    }
    return List<Object?>.from(value);
  }

  static String _idOf(Object? value, String path) {
    if (value is! String || !_id.hasMatch(value)) {
      throw StudioException('INVALID_ID', path);
    }
    return value;
  }

  static String _u64Of(Object? value, String path) {
    if (value is! String || !_u64.hasMatch(value) || value.length > 19) {
      throw StudioException('SCHEMA_INVALID', path);
    }
    return value;
  }

  static String _hashOf(Object? value, String path) {
    if (value is! String || !_hash.hasMatch(value)) {
      throw StudioException('SCHEMA_INVALID', path);
    }
    return value;
  }

  static void _string(Object? value, String path, int max) {
    if (value is! String || value.length > max) {
      throw StudioException('SCHEMA_INVALID', path);
    }
  }

  static void _intRange(Object? value, int min, int max, String path) {
    if (value is! int || value < min || value > max) {
      throw StudioException('SCHEMA_INVALID', path);
    }
  }

  static void _timestampOf(Object? value, String path) {
    if (value is! String || !_timestamp.hasMatch(value)) {
      throw StudioException('SCHEMA_INVALID', path);
    }
  }
}

Map<String, Object?> cloneJson(Object? value) =>
    Map<String, Object?>.from(deepClone(value) as Map);

Object? deepClone(Object? value) {
  if (value is Map) {
    return {for (final e in value.entries) e.key: deepClone(e.value)};
  }
  if (value is List) {
    return [for (final item in value) deepClone(item)];
  }
  return value;
}

String packHashOf(Map<String, Object?> pack) => contentHash(pack);
