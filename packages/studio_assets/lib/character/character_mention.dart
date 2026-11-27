import 'package:studio_contracts/studio_contracts.dart';

import 'character_pack_validator.dart';
import 'character_repository.dart';

/// One published version of a character in the currently authorized library.
final class CharacterMentionVersion {
  const CharacterMentionVersion({
    required this.version,
    required this.packHash,
    required this.isHead,
    required this.looks,
  });

  final String version;
  final String packHash;
  final bool isHead;
  final List<CharacterMentionLook> looks;

  /// The locked version displayed after a pin/select.
  String get lockedVersion => version;

  Map<String, Object?> toJson() => {
    'version': version,
    'packHash': packHash,
    'isHead': isHead,
    'looks': [for (final look in looks) look.toJson()],
  };
}

final class CharacterMentionLook {
  const CharacterMentionLook({required this.lookId, required this.label});

  final String lookId;
  final String label;

  Map<String, Object?> toJson() => {'lookId': lookId, 'label': label};
}

/// A character visible to `@` mention search in the current namespace.
final class CharacterMentionHit {
  const CharacterMentionHit({
    required this.libraryId,
    required this.assetId,
    required this.name,
    required this.kind,
    required this.description,
    required this.tags,
    required this.versions,
  });

  final String libraryId;
  final String assetId;
  final String name;
  final String kind;
  final String description;
  final List<String> tags;
  final List<CharacterMentionVersion> versions;

  Map<String, Object?> toJson() => {
    'libraryId': libraryId,
    'assetId': assetId,
    'name': name,
    'kind': kind,
    'description': description,
    'tags': List<String>.from(tags),
    'versions': [for (final version in versions) version.toJson()],
  };
}

/// Selectors stored in the mention session. Images are not stored.
final class CharacterMentionSelector {
  const CharacterMentionSelector({
    required this.assetId,
    required this.pinnedVersion,
    required this.lookId,
    this.bindingId,
  });

  final String assetId;
  final String pinnedVersion;
  final String lookId;
  final String? bindingId;

  Map<String, Object?> toJson() => {
    'assetId': assetId,
    'pinnedVersion': pinnedVersion,
    'lookId': lookId,
    'bindingId': bindingId,
  };
}

/// `@` mention search over the currently authorized library only.
///
/// This is a linear scan of published `library_versions` in the repository
/// namespace. It does not use FTS5 and does not instantiate `craft_fts`.
final class ProjectCharacterMentionSearch {
  const ProjectCharacterMentionSearch(this.repository);

  final CharacterRepository repository;

  /// Search the authorized library. A leading `@` is stripped. An empty
  /// query lists every published character in the current namespace.
  /// [libraryId] optionally narrows to one library in that namespace.
  List<CharacterMentionHit> search(String query, {String? libraryId}) {
    if (libraryId != null) {
      requireId(libraryId);
    }
    final needle = _normalizeQuery(query);
    final store = repository.store;
    final rows = libraryId == null
        ? store.select(
            'SELECT library_id, entity_id, version, body_hash FROM '
            'library_versions WHERE namespace=? AND kind=? '
            'ORDER BY entity_id ASC, length(version) ASC, version ASC',
            [store.ns, 'character'],
          )
        : store.select(
            'SELECT library_id, entity_id, version, body_hash FROM '
            'library_versions WHERE namespace=? AND kind=? AND library_id=? '
            'ORDER BY entity_id ASC, length(version) ASC, version ASC',
            [store.ns, 'character', libraryId],
          );
    final grouped = <String, _HitBuilder>{};
    for (final row in rows) {
      final pack = Map<String, Object?>.from(
        repository.loadPublished(
          row['entity_id'] as String,
          row['version'] as String,
        ),
      );
      if (packHashOf(pack) != row['body_hash']) {
        throw const StudioException('BINDING_MISMATCH', 'packHash');
      }
      if (!_matches(needle, pack)) continue;
      final asset = Map<String, Object?>.from(pack['asset'] as Map);
      final libId = row['library_id'] as String;
      final assetId = row['entity_id'] as String;
      final key = '$libId\u0000$assetId';
      final builder = grouped.putIfAbsent(
        key,
        () => _HitBuilder(
          libraryId: libId,
          assetId: assetId,
          name: asset['name'] as String,
          kind: asset['kind'] as String,
          description: asset['description'] as String,
          tags: (asset['tags'] as List).cast<String>(),
        ),
      );
      final looks = [
        for (final item in pack['looks'] as List)
          CharacterMentionLook(
            lookId: (item as Map)['id'] as String,
            label: item['label'] as String,
          ),
      ];
      final version = row['version'] as String;
      builder.versions.add(
        CharacterMentionVersion(
          version: version,
          packHash: row['body_hash'] as String,
          isHead: repository.headVersion(libId, assetId) == version,
          looks: looks,
        ),
      );
    }
    return [for (final builder in grouped.values) builder.build()];
  }

  static String _normalizeQuery(String query) {
    var text = query.trim();
    if (text.startsWith('@')) {
      text = text.substring(1).trim();
    }
    return text.toLowerCase();
  }

  static bool _matches(String needle, Map<String, Object?> pack) {
    if (needle.isEmpty) return true;
    final asset = pack['asset'] as Map;
    final fields = <String>[
      asset['id'] as String? ?? '',
      asset['name'] as String? ?? '',
      asset['description'] as String? ?? '',
      for (final tag in (asset['tags'] as List)) tag.toString(),
      for (final item in pack['looks'] as List) ...[
        (item as Map)['id'] as String? ?? '',
        item['label'] as String? ?? '',
        item['wardrobe'] as String? ?? '',
      ],
    ];
    return fields.any((field) => field.toLowerCase().contains(needle));
  }
}

class _HitBuilder {
  _HitBuilder({
    required this.libraryId,
    required this.assetId,
    required this.name,
    required this.kind,
    required this.description,
    required this.tags,
  });

  final String libraryId;
  final String assetId;
  final String name;
  final String kind;
  final String description;
  final List<String> tags;
  final versions = <CharacterMentionVersion>[];

  CharacterMentionHit build() => CharacterMentionHit(
    libraryId: libraryId,
    assetId: assetId,
    name: name,
    kind: kind,
    description: description,
    tags: tags,
    versions: List<CharacterMentionVersion>.from(versions),
  );
}

/// Session storage for `@` mention selection.
///
/// Only [ProjectCharacterRef] maps and selectors are retained. Pack images
/// are never copied or uploaded into the session.
final class CharacterMentionSession {
  CharacterMentionSession();

  final _refs = <Map<String, Object?>>[];
  final _selectors = <CharacterMentionSelector>[];

  List<Map<String, Object?>> get refs => [
    for (final ref in _refs) cloneJson(ref),
  ];

  List<CharacterMentionSelector> get selectors =>
      List<CharacterMentionSelector>.unmodifiable(_selectors);

  /// Image / pack payloads are never stored in the session.
  List<Object?> get storedPackImages => const [];

  /// Select asset/version/look from the authorized library, generate a
  /// [ProjectCharacterRef], and record the locked [pinnedVersion].
  Map<String, Object?> select({
    required CharacterRepository repository,
    required String projectCharacterId,
    required String libraryId,
    required String assetId,
    required String pinnedVersion,
    required String lookId,
    Map<String, Object?>? overrides,
    String? bindingId,
  }) {
    requireId(projectCharacterId);
    requireId(libraryId);
    requireId(assetId);
    requireId(lookId);
    final pack = repository.loadPublished(assetId, pinnedVersion);
    if (pack['libraryId'] != libraryId) {
      throw const StudioException('BINDING_MISMATCH', 'libraryId');
    }
    final looks = {
      for (final item in pack['looks'] as List) (item as Map)['id'] as String,
    };
    if (!looks.contains(lookId)) {
      throw const StudioException('RESOURCE_MISSING', 'lookId');
    }
    if (bindingId != null) {
      requireId(bindingId);
      final bindings = {
        for (final item in pack['bindings'] as List)
          (item as Map)['id'] as String,
      };
      if (!bindings.contains(bindingId)) {
        throw const StudioException('RESOURCE_MISSING', 'bindingId');
      }
    }
    final rightsId = (pack['asset'] as Map)['portraitRightsId'] as String;
    final live = repository.liveRights(rightsId);
    final ref = <String, Object?>{
      'projectCharacterId': projectCharacterId,
      'libraryId': libraryId,
      'assetId': assetId,
      'pinnedVersion': pinnedVersion,
      'packHash': packHashOf(pack),
      'lookId': lookId,
      'overrides': cloneJson(
        overrides ??
            <String, Object?>{
              'wardrobe': null,
              'era': null,
              'stateDescription': null,
              'hairStyle': null,
            },
      ),
      'bindingId': bindingId,
      'rightsEpoch': live?['epoch'] as String? ?? '0',
    };
    CharacterRepository.validator.validateProjectCharacterRef(ref);
    _refs.add(cloneJson(ref));
    _selectors.add(
      CharacterMentionSelector(
        assetId: assetId,
        pinnedVersion: pinnedVersion,
        lookId: lookId,
        bindingId: bindingId,
      ),
    );
    return cloneJson(ref);
  }
}
