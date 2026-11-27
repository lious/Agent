import 'package:studio_contracts/studio_contracts.dart';

import 'registry_bridge.dart';

const filmCraftContentType = 'filmCraft';
const skillCompilerVersion = '1.0.0';

final _hash = RegExp(r'^[a-f0-9]{64}$');

void _requireHash(String value, [String path = 'hash']) {
  if (!_hash.hasMatch(value)) throw StudioException('INVALID_ID', path);
}

/// s8f FilmSkillAsset carried as a Harness SkillPackage content type.
/// This is not a new executable plugin system and cannot add shaders
/// or FFmpeg filter strings to EffectRegistry.
final class SkillPackage {
  SkillPackage({
    required this.id,
    required this.version,
    required this.contentHash,
    required this.contentType,
    required this.pluginType,
    required this.pluginVersion,
    this.shaderSource,
    this.ffmpegFilter,
  }) {
    requireId(id);
    requireId(version);
    _requireHash(contentHash, 'contentHash');
    requireId(contentType);
    requirePluginId(pluginType);
    requirePluginId(pluginVersion);
    if (contentType != filmCraftContentType) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'contentType');
    }
  }

  final String id, version, contentHash, contentType;
  final String pluginType, pluginVersion;
  final String? shaderSource, ffmpegFilter;

  bool get introducesUnreviewedOperator =>
      (shaderSource != null && shaderSource!.isNotEmpty) ||
      (ffmpegFilter != null && ffmpegFilter!.isNotEmpty);
}

/// Compiled proposal only. Patch groups are values and are never applied
/// to a project document by this compiler.
final class CraftProposal {
  CraftProposal({
    required this.id,
    required this.skillSnapshotHash,
    required this.compilerVersion,
    required this.operator,
    required this.requiredFeatures,
    this.shotDesignPatchGroups = const [],
    this.editPatchGroups = const [],
    this.softWarnings = const [],
    this.unsupportedFields = const [],
    this.requiredApprovals = const [],
  });

  final String id, skillSnapshotHash, compilerVersion;
  final OperatorDescriptor operator;
  final List<String> requiredFeatures;
  final List<Map<String, dynamic>> shotDesignPatchGroups, editPatchGroups;
  final List<String> softWarnings, unsupportedFields, requiredApprovals;

  /// Protocol proof: the compiler has no project-document write side effect.
  int get documentWrites => 0;

  bool get fellBackToDissolve =>
      editPatchGroups.any((g) => g['kind'] == 'dissolve') ||
      requiredFeatures.contains('dissolve');
}

/// s8f CraftSkillCompiler. An unregistered technique is refused explicitly
/// and is not rewritten to a registered dissolve.
final class CraftSkillCompiler {
  CraftSkillCompiler({this.bridge = const RegistryBridge()});

  final RegistryBridge bridge;
  int documentWrites = 0;
  int _n = 0;

  CraftProposal compile({
    required SkillPackage skill,
    required String backend,
  }) {
    if (skill.introducesUnreviewedOperator) {
      throw StudioException('UNSUPPORTED_EDIT_TECHNIQUE', skill.pluginType);
    }
    final operator = bridge.resolve(
      pluginType: skill.pluginType,
      pluginVersion: skill.pluginVersion,
      backend: backend,
    );
    if (!operator.enabled) {
      throw StudioException('UNSUPPORTED_EDIT_TECHNIQUE', skill.pluginType);
    }
    _n += 1;
    return CraftProposal(
      id: 'craft-$_n',
      skillSnapshotHash: skill.contentHash,
      compilerVersion: skillCompilerVersion,
      operator: operator,
      requiredFeatures: operator.requiredFeatures,
    );
  }
}
