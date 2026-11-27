import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:studio_contracts/studio_contracts.dart';
import 'package:json_canonicalizer/json_canonicalizer.dart';
import 'package:studio_document/studio_document.dart';

import 'character_pack_validator.dart';
import 'library_store.dart';
import 'portrait_rights.dart';

const _rebuildLocalIdMapping = 'rebuildLocalIdMapping';
const _archiveFormat = 'studio-character-pack';
const _archiveLimit = 32 * 1024 * 1024;
const _kindCharacter = 'character';

Uint8List canonicalBytes(Object? value) => canonicalizeUtf8(value);

final class CharacterDraft {
  CharacterDraft({
    required this.draftId,
    required this.namespace,
    required this.pack,
    this.baseVersion,
  });

  final String draftId;
  final Namespace namespace;
  final String? baseVersion;
  Map<String, Object?> pack;
}

final class CharacterPackRef {
  const CharacterPackRef({
    required this.libraryId,
    required this.assetId,
    required this.version,
    required this.packHash,
  });

  final String libraryId;
  final String assetId;
  final String version;
  final String packHash;

  Map<String, Object?> toJson() => {
    'libraryId': libraryId,
    'assetId': assetId,
    'version': version,
    'packHash': packHash,
  };
}

final class ArchiveReceipt {
  const ArchiveReceipt({
    required this.fileToken,
    required this.packHash,
    required this.includedResourceHashes,
  });

  final String fileToken;
  final String packHash;
  final List<String> includedResourceHashes;
}

final class ImportPreview {
  const ImportPreview({
    required this.sourcePackHash,
    required this.packHash,
    required this.libraryId,
    required this.assetId,
    required this.version,
    required this.idMap,
    required this.liveRightsState,
  });

  final String sourcePackHash;
  final String packHash;
  final String libraryId;
  final String assetId;
  final String version;
  final Map<String, String> idMap;
  final String liveRightsState;
}

final class ProjectCharacterPin {
  const ProjectCharacterPin({
    required this.projectId,
    required this.revision,
    required this.ref,
  });

  final String projectId;
  final String revision;
  final Map<String, Object?> ref;
}

/// Immutable CharacterPack library, project pins, rights, and import/export.
///
/// This first I-036 slice is DEV-PURE: fictional characters and synthetic
/// rights records only. It does not train or download LoRA weights, clone
/// voices, call paid APIs, or bump the core project SQLite user_version.
final class CharacterRepository {
  CharacterRepository(this.store)
    : cache = CharacterDerivedCache(),
      generations = CharacterGenerationLedger();

  final CharacterLibraryStore store;
  final CharacterDerivedCache cache;
  final CharacterGenerationLedger generations;
  final _drafts = <String, CharacterDraft>{};
  var _draftSeq = 0;
  static const validator = CharacterPackValidator();

  Namespace get namespace => store.namespace;

  static CharacterRepository open(String root, Namespace namespace) =>
      CharacterRepository(CharacterLibraryStore.open(root, namespace));

  void close() => store.close();

  CharacterDraft createDraft(Namespace ns) {
    _requireNamespace(ns);
    final draftId = 'draft${++_draftSeq}';
    final draft = CharacterDraft(
      draftId: draftId,
      namespace: ns,
      pack: <String, Object?>{},
    );
    _drafts[draftId] = draft;
    return draft;
  }

  CharacterDraft forkVersion(String assetId, String pinnedVersion) {
    requireId(assetId);
    final pack = loadPublished(assetId, pinnedVersion);
    final draft = CharacterDraft(
      draftId: 'draft${++_draftSeq}',
      namespace: namespace,
      pack: pack,
      baseVersion: pinnedVersion,
    );
    final asset = Map<String, Object?>.from(draft.pack['asset'] as Map);
    asset['version'] = _nextVersion(assetId);
    draft.pack['asset'] = asset;
    _drafts[draft.draftId] = draft;
    return draft;
  }

  CharacterPackRef publish(
    CharacterDraft draft,
    String? expectedHeadVersion,
    RightsDecision rightsDecision,
  ) {
    _requireNamespace(draft.namespace);
    if (!rightsDecision.allowed) {
      throw StudioException(
        rightsDecision.code ?? 'RIGHTS_REQUIRED',
        'rightsDecision',
      );
    }
    return store.transaction(() {
      final pack = cloneJson(draft.pack);
      pack['namespace'] = namespace.toJson();
      final asset = _map(pack['asset']);
      final assetId = asset['id'] as String;
      final version = asset['version'] as String;
      final libraryId = pack['libraryId'] as String;
      final head = headVersion(libraryId, assetId);
      if (head != expectedHeadVersion) {
        throw const StudioException('HEAD_CONFLICT');
      }
      if (head != null && !_versionGreater(version, head)) {
        throw const StudioException('HEAD_CONFLICT');
      }
      validator.validatePack(pack);
      _requireResourceBytes(pack);
      final hash = packHashOf(pack);
      _insertPublished(libraryId, assetId, version, hash, pack, rightsDecision);
      _drafts.remove(draft.draftId);
      return CharacterPackRef(
        libraryId: libraryId,
        assetId: assetId,
        version: version,
        packHash: hash,
      );
    });
  }

  String? headVersion(String libraryId, String assetId) {
    final rows = store.select(
      'SELECT head_version FROM library_heads WHERE namespace=? AND library_id=? '
      'AND kind=? AND entity_id=?',
      [store.ns, libraryId, _kindCharacter, assetId],
    );
    if (rows.isEmpty) return null;
    return rows.single['head_version'] as String;
  }

  Map<String, Object?> loadPublished(String assetId, String version) {
    final rows = store.select(
      'SELECT body_hash FROM library_versions WHERE namespace=? AND kind=? '
      'AND entity_id=? AND version=?',
      [store.ns, _kindCharacter, assetId, version],
    );
    if (rows.isEmpty) {
      throw const StudioException('RESOURCE_MISSING', 'library_versions');
    }
    return _decodePack(rows.single['body_hash'] as String);
  }

  Map<String, Object?> loadHead(String libraryId, String assetId) {
    final version = headVersion(libraryId, assetId);
    if (version == null) {
      throw const StudioException('RESOURCE_MISSING', 'library_heads');
    }
    return loadPublished(assetId, version);
  }

  void pinProject(ProjectCharacterPin pin) {
    validator.validateProjectCharacterRef(pin.ref);
    requireId(pin.projectId);
    if (!RegExp(r'^(0|[1-9][0-9]{0,18})$').hasMatch(pin.revision)) {
      throw const StudioException('SCHEMA_INVALID', 'revision');
    }
    final libraryId = pin.ref['libraryId'] as String;
    final assetId = pin.ref['assetId'] as String;
    final version = pin.ref['pinnedVersion'] as String;
    final body = store.select(
      'SELECT body_hash FROM library_versions WHERE namespace=? AND library_id=? '
      'AND kind=? AND entity_id=? AND version=?',
      [store.ns, libraryId, _kindCharacter, assetId, version],
    );
    if (body.isEmpty) {
      throw const StudioException('RESOURCE_MISSING', 'pinnedVersion');
    }
    if (body.single['body_hash'] != pin.ref['packHash']) {
      throw const StudioException('BINDING_MISMATCH', 'packHash');
    }
    final pack = _decodePack(pin.ref['packHash'] as String);
    if (pack['asset'] is! Map ||
        (pack['asset'] as Map)['id'] != assetId ||
        (pack['asset'] as Map)['version'] != version) {
      throw const StudioException('BINDING_MISMATCH', 'asset');
    }
    final refHash = contentHash(pin.ref);
    store.transaction(() {
      store.putCas(refHash, canonicalBytes(pin.ref));
      store.execute(
        'INSERT INTO library_project_pins(namespace,project_id,revision,'
        'library_id,kind,entity_id,version,effective_ref_hash) '
        'VALUES(?,?,?,?,?,?,?,?)',
        [
          store.ns,
          pin.projectId,
          pin.revision,
          libraryId,
          _kindCharacter,
          assetId,
          version,
          refHash,
        ],
      );
    });
  }

  Map<String, Object?>? projectPin({
    required String projectId,
    required String revision,
    required String libraryId,
    required String assetId,
  }) {
    final rows = store.select(
      'SELECT version, effective_ref_hash FROM library_project_pins '
      'WHERE namespace=? AND project_id=? AND revision=? AND library_id=? '
      'AND kind=? AND entity_id=?',
      [store.ns, projectId, revision, libraryId, _kindCharacter, assetId],
    );
    if (rows.isEmpty) return null;
    // Pins are immutable rows; a revision may only have one effective ref
    // for a given entity in this slice.
    final row = rows.last;
    final ref = Map<String, Object?>.from(
      jsonDecode(
        utf8.decode(store.readCas(row['effective_ref_hash'] as String)),
      ) as Map,
    );
    validator.validateProjectCharacterRef(ref);
    if (ref['pinnedVersion'] != row['version'] ||
        contentHash(ref) != row['effective_ref_hash']) {
      throw const StudioException('BINDING_MISMATCH', 'effective_ref_hash');
    }
    return ref;
  }

  /// List pins for an entity across projects, ignoring later library heads.
  List<Map<String, Object?>> pinsForAsset(String libraryId, String assetId) {
    final rows = store.select(
      'SELECT project_id, revision, version, effective_ref_hash '
      'FROM library_project_pins WHERE namespace=? AND library_id=? AND kind=? '
      'AND entity_id=?',
      [store.ns, libraryId, _kindCharacter, assetId],
    );
    return [for (final row in rows) Map<String, Object?>.from(row)];
  }

  ArchiveReceipt exportPack({
    required CharacterPackRef ref,
    required Iterable<String> selectedResources,
    required RightsDecision rightsDecision,
    required String destinationPath,
  }) {
    if (!rightsDecision.allowed) {
      throw StudioException(
        rightsDecision.code ?? 'RIGHTS_REQUIRED',
        'rightsDecision',
      );
    }
    final pack = loadPublished(ref.assetId, ref.version);
    if (packHashOf(pack) != ref.packHash) {
      throw const StudioException('BINDING_MISMATCH', 'packHash');
    }
    validator.requireExportRights(pack, selectedResources);
    final selected = selectedResources.toList();
    for (final hash in selected) {
      if (!store.hasCas(hash)) {
        throw StudioException('RESOURCE_MISSING', hash);
      }
    }
    final files = <String, Uint8List>{};
    final packBytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(pack)),
    );
    files['pack.json'] = packBytes;
    var size = packBytes.length;
    final resources = <Map<String, Object?>>[];
    for (final hash in selected) {
      final bytes = store.readCas(hash);
      size += bytes.length;
      if (size > _archiveLimit) {
        throw const StudioException('ARCHIVE_LIMIT');
      }
      final name = 'resources/${hash.substring('sha256:'.length)}';
      _rejectUnsafePath(name);
      files[name] = bytes;
      final declared = (pack['resources'] as List).cast<Map>().firstWhere(
        (item) => item['hash'] == hash,
      );
      resources.add({
        'path': name,
        'hash': hash,
        'bytes': declared['bytes'],
        'role': declared['role'],
        'rightsId': declared['rightsId'],
        'mime': declared['mime'],
      });
    }
    final manifest = {
      'format': _archiveFormat,
      'schemaVersion': '1.0.0',
      'packHash': ref.packHash,
      'libraryId': ref.libraryId,
      'assetId': ref.assetId,
      'version': ref.version,
      'sourceNamespace': namespace.toJson(),
      'packPath': 'pack.json',
      'resources': resources,
      'signatureRef': pack['signatureRef'],
      // Snapshot of rights declarations only. Live grants, approval state,
      // and secret evidence are not exported and must be re-verified.
      'rightsSnapshot': pack['rights'],
    };
    final manifestBytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest)),
    );
    if (size + manifestBytes.length > _archiveLimit) {
      throw const StudioException('ARCHIVE_LIMIT');
    }
    files['manifest.json'] = manifestBytes;
    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded.length > _archiveLimit) {
      throw const StudioException('ARCHIVE_LIMIT');
    }
    _atomicWrite(destinationPath, encoded);
    return ArchiveReceipt(
      fileToken: destinationPath,
      packHash: ref.packHash,
      includedResourceHashes: selected,
    );
  }

  ImportPreview importPack({
    required String fileToken,
    required Namespace targetNamespace,
    required String collisionPolicy,
  }) {
    if (targetNamespace != namespace) {
      throw const StudioException('NAMESPACE_MISMATCH', 'targetNamespace');
    }
    if (collisionPolicy != _rebuildLocalIdMapping) {
      // Spec 8E requires rebuilding local ID mapping on import. Other
      // collision policies are not admitted in this slice.
      throw const StudioException('UNSUPPORTED_COLLISION_POLICY');
    }
    final unpacked = _readArchive(fileToken);
    final manifest = jsonDecode(utf8.decode(unpacked['manifest.json']!)) as Map;
    if (manifest['format'] != _archiveFormat ||
        manifest['schemaVersion'] != '1.0.0') {
      throw const StudioException('SCHEMA_INVALID', 'manifest');
    }
    final pack =
        jsonDecode(utf8.decode(unpacked['pack.json']!)) as Map<String, dynamic>;
    final packMap = Map<String, Object?>.from(pack);
    validator.validatePack(packMap);
    final sourceHash = packHashOf(packMap);
    if (sourceHash != manifest['packHash']) {
      throw const StudioException('BINDING_MISMATCH', 'packHash');
    }
    final selected = <String, Uint8List>{};
    for (final item in (manifest['resources'] as List? ?? const [])) {
      final resource = Map<String, Object?>.from(item as Map);
      final path = resource['path'] as String;
      _rejectUnsafePath(path);
      final bytes = unpacked[path];
      if (bytes == null) {
        throw StudioException('RESOURCE_MISSING', path);
      }
      if (rawBytesHash(bytes) != resource['hash'] ||
          bytes.length.toString() != resource['bytes']) {
        throw const StudioException('BLOB_HASH_MISMATCH');
      }
      selected[resource['hash'] as String] = bytes;
    }
    final remapped = _remapPack(packMap, targetNamespace);
    validator.validatePack(remapped.pack);
    _requireResourceBytes(remapped.pack, supplied: selected);
    final hash = packHashOf(remapped.pack);
    return store.transaction(() {
      final asset = _map(remapped.pack['asset']);
      final assetId = asset['id'] as String;
      final libraryId = remapped.pack['libraryId'] as String;
      final version = asset['version'] as String;
      if (headVersion(libraryId, assetId) != null) {
        // Remapped IDs should be new; a collision after remap is refused
        // rather than overwriting an existing published version.
        throw const StudioException('HEAD_CONFLICT');
      }
      for (final entry in selected.entries) {
        store.putCas(entry.key, entry.value);
      }
      store.putCas(hash, utf8.encode(json.encode(remapped.pack)));
      // Live rights stay unknown: source-app approvals are not inherited.
      _insertPublished(
        libraryId,
        assetId,
        version,
        hash,
        remapped.pack,
        const RightsDecision.deny('UNKNOWN'),
        liveState: 'unknown',
      );
      return ImportPreview(
        sourcePackHash: sourceHash,
        packHash: hash,
        libraryId: libraryId,
        assetId: assetId,
        version: version,
        idMap: remapped.idMap,
        liveRightsState: 'unknown',
      );
    });
  }

  /// Record a local live-rights decision. Used after import so the receiving
  /// App can re-verify; it does not resurrect a source-app approval.
  void putLiveRights({
    required String rightsId,
    required String epoch,
    required String state,
    String? checkedAt,
    String? leaseUntil,
  }) {
    const allowed = {'active', 'revoked', 'expired', 'unknown'};
    if (!allowed.contains(state)) {
      throw const StudioException('SCHEMA_INVALID', 'state');
    }
    requireId(rightsId);
    store.transaction(() {
      store.execute(
        'INSERT INTO portrait_rights_live(namespace,rights_id,epoch,state,'
        'checked_at,lease_until) VALUES(?,?,?,?,?,?) '
        'ON CONFLICT(namespace,rights_id) DO UPDATE SET epoch=excluded.epoch,'
        'state=excluded.state,checked_at=excluded.checked_at,'
        'lease_until=excluded.lease_until',
        [store.ns, rightsId, epoch, state, checkedAt, leaseUntil],
      );
    });
  }

  Map<String, Object?>? liveRights(String rightsId) {
    final rows = store.select(
      'SELECT rights_id, epoch, state, checked_at, lease_until '
      'FROM portrait_rights_live WHERE namespace=? AND rights_id=?',
      [store.ns, rightsId],
    );
    if (rows.isEmpty) return null;
    return Map<String, Object?>.from(rows.single);
  }

  RightsDecision evaluate({
    required Map<String, Object?> characterRef,
    required String operation,
    required String provider,
    required String region,
    required DateTime now,
  }) {
    validator.validateProjectCharacterRef(characterRef);
    final pack = loadPublished(
      characterRef['assetId'] as String,
      characterRef['pinnedVersion'] as String,
    );
    if (packHashOf(pack) != characterRef['packHash']) {
      throw const StudioException('BINDING_MISMATCH', 'packHash');
    }
    final rightsId = (_map(pack['asset'])['portraitRightsId'] as String);
    final live = liveRights(rightsId);
    final record = _rightsRecord(pack, rightsId);
    final epoch = live?['epoch'] as String? ?? '0';
    if (live == null || live['state'] == 'unknown') {
      return RightsDecision.deny(
        'RIGHTS_REQUIRED',
        rightsId: rightsId,
        epoch: epoch,
        existingOutputsPolicy: record['existingOutputsPolicy'] as String?,
      );
    }
    if (live['state'] == 'revoked') {
      return RightsDecision.deny(
        'RIGHTS_REVOKED',
        rightsId: rightsId,
        epoch: epoch,
        existingOutputsPolicy: record['existingOutputsPolicy'] as String?,
      );
    }
    if (live['state'] == 'expired') {
      return RightsDecision.deny(
        'RIGHTS_EXPIRED',
        rightsId: rightsId,
        epoch: epoch,
        existingOutputsPolicy: record['existingOutputsPolicy'] as String?,
      );
    }
    final expiresAt = record['expiresAt'] as String?;
    if (expiresAt != null && DateTime.parse(expiresAt).isBefore(now.toUtc())) {
      return RightsDecision.deny(
        'RIGHTS_EXPIRED',
        rightsId: rightsId,
        epoch: epoch,
        existingOutputsPolicy: record['existingOutputsPolicy'] as String?,
      );
    }
    final uses = (record['allowedUses'] as List).cast<String>();
    if (!uses.contains(operation)) {
      return RightsDecision.deny(
        'RIGHTS_REQUIRED',
        rightsId: rightsId,
        epoch: epoch,
        existingOutputsPolicy: record['existingOutputsPolicy'] as String?,
      );
    }
    final providers = (record['allowedProviderIds'] as List).cast<String>();
    if (providers.isNotEmpty && !providers.contains(provider)) {
      return RightsDecision.deny(
        'RIGHTS_REQUIRED',
        rightsId: rightsId,
        epoch: epoch,
        existingOutputsPolicy: record['existingOutputsPolicy'] as String?,
      );
    }
    // region/territories: empty means unrestricted in this DEV-PURE slice.
    final territories = (record['territories'] as List).cast<String>();
    if (territories.isNotEmpty && !territories.contains(region)) {
      return RightsDecision.deny(
        'RIGHTS_REQUIRED',
        rightsId: rightsId,
        epoch: epoch,
        existingOutputsPolicy: record['existingOutputsPolicy'] as String?,
      );
    }
    return RightsDecision.allow(
      rightsId: rightsId,
      epoch: epoch,
      existingOutputsPolicy: record['existingOutputsPolicy'] as String?,
    );
  }

  /// Dispatch a synthetic generation (no model, no paid API). Denied after
  /// revocation. Cache hits after revocation remain 0.
  void requestGeneration({
    required Map<String, Object?> characterRef,
    required String provider,
    required String region,
    required DateTime now,
  }) {
    final decision = evaluate(
      characterRef: characterRef,
      operation: 'referenceGeneration',
      provider: provider,
      region: region,
      now: now,
    );
    if (!decision.allowed) {
      throw StudioException(decision.code ?? 'RIGHTS_REQUIRED');
    }
    generations.recordDispatch();
    cache.put(
      rightsId: decision.rightsId!,
      packHash: characterRef['packHash'] as String,
      lookId: characterRef['lookId'] as String,
      value: 'generated:${characterRef['packHash']}',
    );
  }

  String? lookupCache({
    required Map<String, Object?> characterRef,
    required String provider,
    required String region,
    required DateTime now,
  }) {
    final decision = evaluate(
      characterRef: characterRef,
      operation: 'referenceGeneration',
      provider: provider,
      region: region,
      now: now,
    );
    return cache.lookup(
      rightsId: characterRefRightsId(characterRef),
      packHash: characterRef['packHash'] as String,
      lookId: characterRef['lookId'] as String,
      revoked: !decision.allowed,
    );
  }

  String characterRefRightsId(Map<String, Object?> characterRef) {
    final pack = loadPublished(
      characterRef['assetId'] as String,
      characterRef['pinnedVersion'] as String,
    );
    return _map(pack['asset'])['portraitRightsId'] as String;
  }

  RevocationReport revoke(String rightsId, String expectedEpoch) {
    requireId(rightsId);
    return store.transaction(() {
      final live = liveRights(rightsId);
      if (live == null) {
        throw const StudioException('RESOURCE_MISSING', 'rightsId');
      }
      if (live['epoch'] != expectedEpoch) {
        throw const StudioException('HEAD_CONFLICT', 'epoch');
      }
      final nextEpoch = _incrementU64(expectedEpoch);
      cache.invalidateRights(rightsId);
      cache.resetCounters();
      generations.reset();
      store.execute(
        'UPDATE portrait_rights_live SET epoch=?, state=? WHERE namespace=? '
        'AND rights_id=?',
        [nextEpoch, 'revoked', store.ns, rightsId],
      );
      final policy = _existingOutputsPolicy(rightsId);
      return RevocationReport(
        rightsId: rightsId,
        epoch: nextEpoch,
        state: 'revoked',
        newGenerations: generations.dispatched,
        cacheHits: cache.hits,
        existingOutputsPolicy: policy,
      );
    });
  }

  void _insertPublished(
    String libraryId,
    String assetId,
    String version,
    String hash,
    Map<String, Object?> pack,
    RightsDecision rightsDecision, {
    String liveState = 'active',
  }) {
    store.putCas(hash, canonicalBytes(pack));
    store.execute(
      'INSERT INTO library_versions(namespace,library_id,kind,entity_id,'
      'version,body_hash) VALUES(?,?,?,?,?,?)',
      [store.ns, libraryId, _kindCharacter, assetId, version, hash],
    );
    store.execute(
      'INSERT INTO library_heads(namespace,library_id,kind,entity_id,'
      'head_version) VALUES(?,?,?,?,?) ON CONFLICT(namespace,library_id,kind,'
      'entity_id) DO UPDATE SET head_version=excluded.head_version',
      [store.ns, libraryId, _kindCharacter, assetId, version],
    );
    for (final look in (pack['looks'] as List)) {
      final lookMap = Map<String, Object?>.from(look as Map);
      store.execute(
        'INSERT INTO character_look_index(namespace,library_id,kind,asset_id,'
        'asset_version,look_id,body_hash) VALUES(?,?,?,?,?,?,?)',
        [
          store.ns,
          libraryId,
          _kindCharacter,
          assetId,
          version,
          lookMap['id'],
          hash,
        ],
      );
    }
    for (final binding in (pack['bindings'] as List)) {
      final bindingMap = Map<String, Object?>.from(binding as Map);
      store.execute(
        'INSERT INTO model_adapter_bindings(namespace,library_id,kind,asset_id,'
        'asset_version,binding_id,body_hash,base_fingerprint) '
        'VALUES(?,?,?,?,?,?,?,?)',
        [
          store.ns,
          libraryId,
          _kindCharacter,
          assetId,
          version,
          bindingMap['id'],
          hash,
          bindingMap['baseModelFingerprint'],
        ],
      );
    }
    for (final rights in (pack['rights'] as List)) {
      final record = Map<String, Object?>.from(rights as Map);
      final rightsId = record['id'] as String;
      final rightsVersion = record['version'] as String;
      final rightsHash = contentHash(record);
      store.putCas(rightsHash, canonicalBytes(record));
      final exists = store.select(
        'SELECT 1 FROM portrait_rights_versions WHERE namespace=? AND '
        'rights_id=? AND version=?',
        [store.ns, rightsId, rightsVersion],
      );
      if (exists.isEmpty) {
        store.execute(
          'INSERT INTO portrait_rights_versions(namespace,rights_id,version,'
          'body_hash) VALUES(?,?,?,?)',
          [store.ns, rightsId, rightsVersion, rightsHash],
        );
      }
      final live = liveRights(rightsId);
      final epoch = live?['epoch'] as String? ?? '0';
      final state = liveState == 'unknown'
          ? 'unknown'
          : (rightsDecision.allowed ? 'active' : 'unknown');
      if (live == null) {
        store.execute(
          'INSERT INTO portrait_rights_live(namespace,rights_id,epoch,state,'
          'checked_at,lease_until) VALUES(?,?,?,?,?,?)',
          [store.ns, rightsId, epoch, state, null, null],
        );
      }
    }
  }

  void _requireResourceBytes(
    Map<String, Object?> pack, {
    Map<String, Uint8List>? supplied,
  }) {
    for (final item in (pack['resources'] as List)) {
      final resource = Map<String, Object?>.from(item as Map);
      final hash = resource['hash'] as String;
      final bytes =
          supplied?[hash] ?? (store.hasCas(hash) ? store.readCas(hash) : null);
      if (bytes == null) {
        throw StudioException('RESOURCE_MISSING', hash);
      }
      if (bytes.length.toString() != resource['bytes'] ||
          rawBytesHash(bytes) != hash) {
        throw const StudioException('BLOB_HASH_MISMATCH');
      }
    }
  }

  Map<String, Object?> _decodePack(String hash) {
    final bytes = store.readCas(hash);
    final decoded = jsonDecode(utf8.decode(bytes));
    return Map<String, Object?>.from(decoded as Map);
  }

  Map<String, Object?> _rightsRecord(
    Map<String, Object?> pack,
    String rightsId,
  ) {
    for (final item in (pack['rights'] as List)) {
      final record = Map<String, Object?>.from(item as Map);
      if (record['id'] == rightsId) return record;
    }
    throw const StudioException('RESOURCE_MISSING', 'rightsId');
  }

  String _existingOutputsPolicy(String rightsId) {
    final versions = store.select(
      'SELECT version, body_hash FROM portrait_rights_versions WHERE '
      'namespace=? AND rights_id=? ORDER BY length(version), version',
      [store.ns, rightsId],
    );
    if (versions.isEmpty) {
      throw const StudioException('RESOURCE_MISSING', 'rightsId');
    }
    final body = jsonDecode(
      utf8.decode(store.readCas(versions.last['body_hash'] as String)),
    ) as Map;
    return body['existingOutputsPolicy'] as String;
  }

  String _nextVersion(String assetId) {
    final rows = store.select(
      'SELECT version FROM library_versions WHERE namespace=? AND kind=? '
      'AND entity_id=?',
      [store.ns, _kindCharacter, assetId],
    );
    var max = BigInt.zero;
    for (final row in rows) {
      final value = BigInt.parse(row['version'] as String);
      if (value > max) max = value;
    }
    return (max + BigInt.one).toString();
  }

  bool _versionGreater(String left, String right) =>
      BigInt.parse(left) > BigInt.parse(right);

  void _requireNamespace(Namespace ns) {
    if (ns != namespace) {
      throw const StudioException('NAMESPACE_MISMATCH');
    }
  }

  Map<String, Object?> _map(Object? value) =>
      Map<String, Object?>.from(value as Map);

  _Remapped _remapPack(Map<String, Object?> source, Namespace target) {
    final idMap = <String, String>{};
    String mapId(String id) => idMap.putIfAbsent(
      id,
      () => 'm${contentHash([namespace.key, target.key, id]).substring(7, 23)}',
    );
    final pack = cloneJson(source);
    pack['namespace'] = target.toJson();
    pack['libraryId'] = mapId(pack['libraryId'] as String);
    final asset = _map(pack['asset']);
    asset['id'] = mapId(asset['id'] as String);
    asset['defaultLookId'] = mapId(asset['defaultLookId'] as String);
    asset['portraitRightsId'] = mapId(asset['portraitRightsId'] as String);
    final voice = _map(asset['voice']);
    if (voice['voiceRightsId'] != null) {
      voice['voiceRightsId'] = mapId(voice['voiceRightsId'] as String);
    }
    asset['voice'] = voice;
    pack['asset'] = asset;
    pack['looks'] = [
      for (final item in (pack['looks'] as List))
        () {
          final look = Map<String, Object?>.from(item as Map);
          look['id'] = mapId(look['id'] as String);
          look['referenceIds'] = [
            for (final id in (look['referenceIds'] as List))
              mapId(id as String),
          ];
          return look;
        }(),
    ];
    pack['references'] = [
      for (final item in (pack['references'] as List))
        () {
          final reference = Map<String, Object?>.from(item as Map);
          reference['id'] = mapId(reference['id'] as String);
          reference['lookId'] = mapId(reference['lookId'] as String);
          reference['rightsId'] = mapId(reference['rightsId'] as String);
          return reference;
        }(),
    ];
    pack['bindings'] = [
      for (final item in (pack['bindings'] as List))
        () {
          final binding = Map<String, Object?>.from(item as Map);
          binding['id'] = mapId(binding['id'] as String);
          if (binding['trainingRightsId'] != null) {
            binding['trainingRightsId'] = mapId(
              binding['trainingRightsId'] as String,
            );
          }
          return binding;
        }(),
    ];
    pack['rights'] = [
      for (final item in (pack['rights'] as List))
        () {
          final record = Map<String, Object?>.from(item as Map);
          record['id'] = mapId(record['id'] as String);
          return record;
        }(),
    ];
    pack['resources'] = [
      for (final item in (pack['resources'] as List))
        () {
          final resource = Map<String, Object?>.from(item as Map);
          resource['rightsId'] = mapId(resource['rightsId'] as String);
          return resource;
        }(),
    ];
    return _Remapped(pack, idMap);
  }

  Map<String, Uint8List> _readArchive(String fileToken) {
    final file = File(fileToken);
    if (!file.existsSync()) {
      throw const StudioException('RESOURCE_MISSING', 'fileToken');
    }
    final bytes = file.readAsBytesSync();
    if (bytes.length > _archiveLimit) {
      throw const StudioException('ARCHIVE_LIMIT');
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final files = <String, Uint8List>{};
    var size = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      _rejectUnsafePath(entry.name);
      if (files.containsKey(entry.name)) {
        throw const StudioException('ARCHIVE_DUPLICATE_PATH');
      }
      final content = Uint8List.fromList(entry.content as List<int>);
      size += content.length;
      if (size > _archiveLimit) {
        throw const StudioException('ARCHIVE_LIMIT');
      }
      files[entry.name] = content;
    }
    if (!files.containsKey('manifest.json') ||
        !files.containsKey('pack.json')) {
      throw const StudioException('RESOURCE_MISSING', 'manifest');
    }
    return files;
  }

  void _atomicWrite(String path, List<int> bytes) {
    _rejectUnsafePath(p.basename(path));
    final file = File(path);
    file.parent.createSync(recursive: true);
    final stage = File('${file.path}.stage');
    stage.writeAsBytesSync(bytes, flush: true);
    stage.renameSync(file.path);
  }

  void _rejectUnsafePath(String path) {
    if (path.startsWith('/') ||
        path
            .split('/')
            .any((part) => part.isEmpty || part == '.' || part == '..') ||
        path.contains('\\') ||
        path.contains('\u0000')) {
      throw const StudioException('ARCHIVE_UNSAFE_ENTRY');
    }
  }

  String _incrementU64(String value) =>
      (BigInt.parse(value) + BigInt.one).toString();
}

class _Remapped {
  _Remapped(this.pack, this.idMap);
  final Map<String, Object?> pack;
  final Map<String, String> idMap;
}

/// Admitted import collision policy: rebuild local IDs as specified in 8E.
const characterImportRebuildLocalIds = _rebuildLocalIdMapping;
