import 'package:studio_contracts/studio_contracts.dart';

import 'character_pack_validator.dart';
import 'character_resolver.dart';

/// Official Project.extensions key for character-library pins.
const characterLibraryExtensionKey = 'studio.character-library.v1';

/// I-004 surfaces that would be required to attach a library reference blob
/// as a project Asset. This slice does not invent them.
const missingAppearanceAttachSurfaces = [
  'AssetRepository',
  'RelinkProposal',
  'FileToken',
];

final class ProjectCharacterMaterializeResult {
  const ProjectCharacterMaterializeResult({
    required this.project,
    required this.character,
    required this.extension,
    required this.appearanceRefWritten,
    required this.missingSurfaces,
  });

  final Map<String, Object?> project;
  final Map<String, Object?> character;
  final Map<String, Object?> extension;
  final bool appearanceRefWritten;

  /// Empty when [appearanceRefWritten] is true. Otherwise the I-004
  /// attach/import surfaces that are still missing.
  final List<String> missingSurfaces;

  Map<String, Object?> toJson() => {
    'character': cloneJson(character),
    'extension': cloneJson(extension),
    'appearanceRefWritten': appearanceRefWritten,
    'missingSurfaces': List<String>.from(missingSurfaces),
  };
}

/// Materialize a resolved library pin into Project.Character and
/// `Project.extensions["studio.character-library.v1"]`.
///
/// name / constraints are written on the in-project Character entity.
/// `Character.version` is that entity's version and is not the external
/// [ResolvedCharacter.pinnedVersion]. The extension stores only refs and
/// portablePackHashes. No new Project root table is created.
///
/// appearanceRef is written only when an already-admitted project Asset
/// [EntityRef] is supplied and present in `project.assets`. A bare Asset ID
/// from the external character library is refused. This type does not
/// invent [AssetRepository], [RelinkProposal], or [FileToken], and does not
/// copy library CAS blobs into the project.
final class ProjectCharacterMaterializer {
  const ProjectCharacterMaterializer();

  static const schemaVersion = '1.0.0';

  ProjectCharacterMaterializeResult materialize({
    required Map<String, Object?> project,
    required Map<String, Object?> projectCharacterRef,
    required ResolvedCharacter resolved,
    required String projectCharacterId,
    String? projectRightsId,
    Map<String, Object?>? admittedProjectAppearance,
  }) {
    requireId(projectCharacterId);
    const CharacterPackValidator().validateProjectCharacterRef(
      projectCharacterRef,
    );
    if (projectCharacterRef['projectCharacterId'] != projectCharacterId) {
      throw const StudioException('BINDING_MISMATCH', 'projectCharacterId');
    }
    if (projectCharacterRef['assetId'] != resolved.assetId ||
        projectCharacterRef['pinnedVersion'] != resolved.pinnedVersion ||
        projectCharacterRef['packHash'] != resolved.packHash ||
        projectCharacterRef['lookId'] != resolved.lookId) {
      throw const StudioException('BINDING_MISMATCH', 'resolvedCharacter');
    }

    final next = cloneJson(project);
    final characters = _list(next['characters']);
    final existingIndex = characters.indexWhere(
      (item) => item is Map && item['id'] == projectCharacterId,
    );
    Map<String, Object?> existing = const {};
    if (existingIndex >= 0) {
      existing = Map<String, Object?>.from(characters[existingIndex] as Map);
    }

    final appearance = _appearanceRef(
      project: next,
      admittedProjectAppearance: admittedProjectAppearance,
      libraryAssetId: resolved.assetId,
    );
    final rightsId = _rightsId(
      project: next,
      existing: existing,
      projectRightsId: projectRightsId,
    );
    // In-project entity version, independent of the external pinnedVersion.
    final entityVersion = existing.isEmpty
        ? '1'
        : _incrementU64(existing['version'] as String? ?? '0');

    final character = <String, Object?>{
      'id': projectCharacterId,
      'version': entityVersion,
      'name': resolved.name,
      'appearanceRef': appearance.ref,
      'motivation': existing['motivation'] is String
          ? existing['motivation']
          : '',
      'constraints': List<String>.from(resolved.constraints),
      'rightsId': rightsId,
    };

    if (existingIndex >= 0) {
      characters[existingIndex] = character;
    } else {
      characters.add(character);
    }
    next['characters'] = characters;

    final extension = _upsertExtension(
      project: next,
      projectCharacterRef: projectCharacterRef,
    );
    return ProjectCharacterMaterializeResult(
      project: next,
      character: character,
      extension: extension,
      appearanceRefWritten: appearance.ref != null,
      missingSurfaces: appearance.missingSurfaces,
    );
  }

  static Map<String, Object?> _upsertExtension({
    required Map<String, Object?> project,
    required Map<String, Object?> projectCharacterRef,
  }) {
    final extensions = project['extensions'] is Map
        ? Map<String, Object?>.from(project['extensions'] as Map)
        : <String, Object?>{};
    final current = extensions[characterLibraryExtensionKey] is Map
        ? Map<String, Object?>.from(
            extensions[characterLibraryExtensionKey] as Map,
          )
        : <String, Object?>{};
    final refs = <Map<String, Object?>>[
      for (final item
          in (current['refs'] is List ? current['refs'] as List : []))
        if (item is Map) cloneJson(Map<String, Object?>.from(item)),
    ];
    final id = projectCharacterRef['projectCharacterId'];
    refs.removeWhere((ref) => ref['projectCharacterId'] == id);
    refs.add(cloneJson(projectCharacterRef));
    final hashes = <String>{
      for (final ref in refs)
        if (ref['packHash'] is String) ref['packHash'] as String,
    };
    final extension = <String, Object?>{
      'schemaVersion': schemaVersion,
      'refs': refs,
      'portablePackHashes': hashes.toList()..sort(),
    };
    // Only refs / portablePackHashes (plus the closed schemaVersion).
    if (extension.keys.toSet().difference({
      'schemaVersion',
      'refs',
      'portablePackHashes',
    }).isNotEmpty) {
      throw const StudioException(
        'SCHEMA_INVALID',
        characterLibraryExtensionKey,
      );
    }
    extensions[characterLibraryExtensionKey] = extension;
    project['extensions'] = extensions;
    return extension;
  }

  static _Appearance _appearanceRef({
    required Map<String, Object?> project,
    required Map<String, Object?>? admittedProjectAppearance,
    required String libraryAssetId,
  }) {
    if (admittedProjectAppearance == null) {
      return const _Appearance(
        ref: null,
        missingSurfaces: missingAppearanceAttachSurfaces,
      );
    }
    if (!admittedProjectAppearance.containsKey('id') ||
        !admittedProjectAppearance.containsKey('version') ||
        admittedProjectAppearance.length != 2) {
      throw const StudioException('SCHEMA_INVALID', 'appearanceRef');
    }
    final id = admittedProjectAppearance['id'];
    final version = admittedProjectAppearance['version'];
    if (id is! String || version is! String) {
      throw const StudioException('SCHEMA_INVALID', 'appearanceRef');
    }
    requireId(id);
    if (!RegExp(r'^(0|[1-9][0-9]{0,18})$').hasMatch(version)) {
      throw const StudioException('SCHEMA_INVALID', 'appearanceRef.version');
    }
    if (id == libraryAssetId) {
      // A bare library Asset ID is never written, even if the string matches
      // a project asset id; the EntityRef must resolve in project.assets.
      final assets = _list(project['assets']);
      final admitted = assets.any(
        (item) => item is Map && item['id'] == id && item['version'] == version,
      );
      if (!admitted) {
        throw const StudioException('BINDING_MISMATCH', 'appearanceRef');
      }
    }
    final assets = _list(project['assets']);
    final admitted = assets.where(
      (item) => item is Map && item['id'] == id && item['version'] == version,
    );
    if (admitted.isEmpty) {
      throw const StudioException('RESOURCE_MISSING', 'appearanceRef');
    }
    return _Appearance(
      ref: {'id': id, 'version': version},
      missingSurfaces: const [],
    );
  }

  static String _rightsId({
    required Map<String, Object?> project,
    required Map<String, Object?> existing,
    required String? projectRightsId,
  }) {
    final candidate = projectRightsId ?? existing['rightsId'] as String?;
    if (candidate == null) {
      throw const StudioException('RESOURCE_MISSING', 'rightsId');
    }
    requireId(candidate);
    final records = _list(project['rightsRecords']);
    final found = records.any((item) => item is Map && item['id'] == candidate);
    if (!found) {
      // Do not write a bare library portraitRightsId as a project rights row.
      throw const StudioException('RESOURCE_MISSING', 'rightsId');
    }
    return candidate;
  }

  static List<Object?> _list(Object? value) =>
      value is List ? List<Object?>.from(value) : <Object?>[];

  static String _incrementU64(String value) {
    if (!RegExp(r'^(0|[1-9][0-9]{0,18})$').hasMatch(value)) {
      throw const StudioException('SCHEMA_INVALID', 'Character.version');
    }
    return (BigInt.parse(value) + BigInt.one).toString();
  }
}

final class _Appearance {
  const _Appearance({required this.ref, required this.missingSurfaces});
  final Map<String, Object?>? ref;
  final List<String> missingSurfaces;
}
