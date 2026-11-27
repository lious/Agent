import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

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
    this.commands = const [],
    this.inverseKind = 'restoreSnapshot',
    this.beforeSnapshotHash,
  });

  final String id, skillSnapshotHash, compilerVersion;
  final OperatorDescriptor operator;
  final List<String> requiredFeatures;
  final List<Map<String, dynamic>> shotDesignPatchGroups, editPatchGroups;
  final List<String> softWarnings, unsupportedFields, requiredApprovals;
  final List<EditOperation> commands;
  final String inverseKind;
  final String? beforeSnapshotHash;

  /// Protocol proof: the compiler has no project-document write side effect.
  int get documentWrites => 0;

  bool get fellBackToDissolve =>
      editPatchGroups.any((g) => g['kind'] == 'dissolve') ||
      requiredFeatures.contains('dissolve');
}

enum JlCutKind { j, l }

/// s8f editing_craft J/L parameters. Compiles to already-admitted
/// UnlinkAudioVideo + TrimClip commands. This is not a TrimPlanner and
/// does not add a new trim mode.
final class JlCutRequest {
  JlCutRequest({
    required this.kind,
    required this.offset,
    required this.leftVideoId,
    required this.rightVideoId,
  }) {
    requireId(leftVideoId);
    requireId(rightVideoId);
    if (offset <= Q.of(0)) {
      throw const StudioException('INVALID_ID', 'offset');
    }
  }

  final JlCutKind kind;
  final Q offset;
  final String leftVideoId, rightVideoId;
}

/// s8f CraftSkillCompiler. An unregistered technique is refused explicitly
/// and is not rewritten to a registered dissolve. J/L cuts compile to
/// already-admitted unlink and trim commands.
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

  /// J = next audio early; L = outgoing audio late. Inverse is the
  /// existing before snapshot. The compiler does not apply the batch.
  CraftProposal compileJlCut({
    required ProjectDocument project,
    required JlCutRequest request,
  }) {
    final planned = planJlCut(project, request);
    _n += 1;
    return CraftProposal(
      id: 'craft-$_n',
      skillSnapshotHash: project.hash,
      compilerVersion: skillCompilerVersion,
      operator: OperatorDescriptor(
        id: request.kind == JlCutKind.j ? 'editing.jCut' : 'editing.lCut',
        version: '1.0.0',
        backend: 'cpu',
        enabled: true,
        requiredFeatures: const [],
      ),
      requiredFeatures: const [],
      editPatchGroups: [
        for (final command in planned)
          Map<String, dynamic>.from(command.toJson()),
      ],
      commands: planned,
      inverseKind: 'restoreSnapshot',
      beforeSnapshotHash: project.hash,
    );
  }
}

Map<dynamic, dynamic> _clip(ProjectDocument project, String id) {
  for (final t in project.toJson()['sequences'][0]['tracks']) {
    for (final c in t['items']) {
      if (c['id'] == id && c['source'] != null) return c as Map;
    }
  }
  throw StudioException('CLIP_NOT_FOUND', id);
}

Map<dynamic, dynamic> _track(ProjectDocument project, Map clip) {
  for (final t in project.toJson()['sequences'][0]['tracks']) {
    if (t['id'] == clip['trackId']) return t as Map;
  }
  throw const StudioException('CLIP_NOT_FOUND', 'track');
}

Map<dynamic, dynamic> _linkedAudio(ProjectDocument project, String videoId) {
  final d = project.toJson();
  for (final g in d['linkGroups'] as List) {
    final members = [for (final m in g['members']) m['clipId'] as String];
    if (!members.contains(videoId)) continue;
    for (final id in members) {
      if (id == videoId) continue;
      final clip = _clip(project, id);
      if (_track(project, clip)['kind'] == 'audio') return clip;
    }
  }
  throw StudioException('CLIP_NOT_FOUND', videoId);
}

Q _range(Map node, String range, String field) =>
    Q.fromJson(node[range][field]);

Q _streamDuration(ProjectDocument project, Map clip) {
  final source = clip['source'] as Map;
  final assetId = source['id'] ?? source['assetId'];
  for (final asset in project.toJson()['assets'] as List) {
    if (asset['id'] != assetId) continue;
    for (final stream in asset['streams'] as List) {
      if (stream['id'] == source['streamId']) {
        return Q.fromJson(stream['duration']);
      }
    }
  }
  throw StudioException('CLIP_NOT_FOUND', source['streamId'] as String);
}

/// Builds the already-admitted unlink + trim batch for a packed J/L cut.
List<EditOperation> planJlCut(ProjectDocument project, JlCutRequest request) {
  final leftVideo = _clip(project, request.leftVideoId);
  final rightVideo = _clip(project, request.rightVideoId);
  if (_track(project, leftVideo)['kind'] != 'video' ||
      _track(project, rightVideo)['kind'] != 'video') {
    throw const StudioException('CLIP_NOT_FOUND', 'video');
  }
  if (_range(leftVideo, 'timelineRange', 'start') +
          _range(leftVideo, 'timelineRange', 'duration') !=
      _range(rightVideo, 'timelineRange', 'start')) {
    throw const StudioException('NOT_ADJACENT');
  }
  final leftAudio = _linkedAudio(project, request.leftVideoId);
  final rightAudio = _linkedAudio(project, request.rightVideoId);
  for (final audio in [leftAudio, rightAudio]) {
    if (_track(project, audio)['locked'] == true) {
      throw const StudioException('FIELD_LOCKED');
    }
  }
  final rate = Q.fromJson(rightAudio['timeMap']['rate']);
  final needed = rate * request.offset;
  if (request.kind == JlCutKind.j) {
    if (_range(rightAudio, 'sourceRange', 'start') < needed) {
      throw const StudioException('HANDLE_UNAVAILABLE');
    }
  } else {
    final tail =
        _streamDuration(project, leftAudio) -
        (_range(leftAudio, 'sourceRange', 'start') +
            _range(leftAudio, 'sourceRange', 'duration'));
    if (tail < needed) {
      throw const StudioException('HANDLE_UNAVAILABLE');
    }
  }
  final delta = request.kind == JlCutKind.j
      ? Q.of(0) - request.offset
      : request.offset;
  final commands = <EditOperation>[];
  final seen = <String>{};
  for (final groupId in [
    leftVideo['linkGroupId'] as String?,
    rightVideo['linkGroupId'] as String?,
    leftAudio['linkGroupId'] as String?,
    rightAudio['linkGroupId'] as String?,
  ]) {
    if (groupId == null || !seen.add(groupId)) continue;
    commands.add(UnlinkAudioVideo(groupId));
  }
  final leftTrim = TrimClip(leftAudio['id'] as String, 'out', delta);
  final rightTrim = TrimClip(rightAudio['id'] as String, 'in', delta);
  // Shorten first so an L-cut does not temporarily overlap on the
  // same audio track (COLLISION). J shortens the outgoing out-point
  // first; L shortens the incoming in-point first.
  if (request.kind == JlCutKind.j) {
    commands.add(leftTrim);
    commands.add(rightTrim);
  } else {
    commands.add(rightTrim);
    commands.add(leftTrim);
  }
  return commands;
}
