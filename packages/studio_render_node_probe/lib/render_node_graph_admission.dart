import 'package:studio_contracts/studio_contracts.dart';

/// s4 closed RenderNode union and the identity fields each kind must name.
const officialRenderNodeKinds = {
  'SourceNode': ['assetVersion', 'streamId', 'sourceAt', 'decoderLease'],
  'ImageNode': ['documentVersion'],
  'ColorNode': ['policyVersion', 'lutHash'],
  'EffectNode': ['effectId', 'pluginVersion'],
  'CompositeNode': ['blendMode'],
  'TextNode': ['cueId', 'glyphRunHash'],
  'AudioMixNode': ['busId', 'routingMatrixHash'],
  'OutputNode': ['presetId'],
};

final class RenderNodeDraft {
  const RenderNodeDraft({
    required this.id,
    required this.kind,
    this.identity = const {},
    this.extent,
    this.pixelFormat,
    this.color,
    this.alphaMode,
    this.inputIds = const [],
    this.fingerprint,
  });

  final String id, kind;
  final Map<String, String> identity;
  final String? extent, pixelFormat, color, alphaMode, fingerprint;
  final List<String> inputIds;
}

final class RenderNodeGraphRequest {
  const RenderNodeGraphRequest({
    required this.nodes,
    required this.cacheKey,
    this.cacheKeyIsSourceFilenameOnly = false,
  });

  final List<RenderNodeDraft> nodes;
  final String cacheKey;
  final bool cacheKeyIsSourceFilenameOnly;
}

final class RenderNodeGraphReceipt {
  const RenderNodeGraphReceipt({
    required this.closedUnion,
    required this.acyclic,
    required this.fingerprintInCacheKey,
  });

  final bool closedUnion, acyclic, fingerprintInCacheKey;
}

/// DEV-PURE I-022 / s4 admission: RenderNode is a closed union; each
/// node must publish extent, pixelFormat, color, and alphaMode; the
/// graph is acyclic; node fingerprints participate in the cache key,
/// which must not be only the source filename.
///
/// `decoderLease` and `lutHash` are identity fields from the closed
/// union, not a FrameLease or LUT runtime. This is not a V-003
/// measurement and does not re-qualify RenderRecipeAdmission or
/// PreviewExportConsistencyAdmission.
final class RenderNodeGraphAdmission {
  bool v003Claimed = false;
  bool frameLeaseInvented = false;
  bool lutRuntimeInvented = false;
  bool renderRecipeRequalified = false;
  bool previewExportRequalified = false;
  bool stillImageRequalified = false;
  bool muxerInvented = false;
  bool i024Rewritten = false;
  bool paidApiCalled = false;

  RenderNodeGraphReceipt admit(RenderNodeGraphRequest request) {
    final ids = <String>{};
    for (final node in request.nodes) {
      if (!officialRenderNodeKinds.containsKey(node.kind)) {
        throw const StudioException('RENDER_NODE_UNKNOWN', 'graph');
      }
      if (node.id.isEmpty || !ids.add(node.id)) {
        throw const StudioException('RENDER_NODE_IDENTITY_REQUIRED', 'graph');
      }
      for (final field in officialRenderNodeKinds[node.kind]!) {
        if ((node.identity[field] ?? '').isEmpty) {
          throw const StudioException('RENDER_NODE_IDENTITY_REQUIRED', 'graph');
        }
      }
      if ((node.extent ?? '').isEmpty ||
          (node.pixelFormat ?? '').isEmpty ||
          (node.color ?? '').isEmpty ||
          (node.alphaMode ?? '').isEmpty) {
        throw const StudioException('RENDER_NODE_OUTPUT_REQUIRED', 'graph');
      }
    }
    for (final node in request.nodes) {
      for (final input in node.inputIds) {
        if (!ids.contains(input)) {
          throw const StudioException('RENDER_GRAPH_INPUT_UNKNOWN', 'graph');
        }
      }
    }
    if (_cyclic(request.nodes)) {
      throw const StudioException('RENDER_GRAPH_CYCLE', 'graph');
    }
    final fingerprints = [
      for (final node in request.nodes)
        if ((node.fingerprint ?? '').isNotEmpty) node.fingerprint!,
    ];
    if (request.cacheKeyIsSourceFilenameOnly ||
        fingerprints.isEmpty ||
        fingerprints.any(
          (fingerprint) => !request.cacheKey.contains(fingerprint),
        )) {
      throw const StudioException('CACHE_KEY_FILENAME_ONLY', 'graph');
    }
    return const RenderNodeGraphReceipt(
      closedUnion: true,
      acyclic: true,
      fingerprintInCacheKey: true,
    );
  }
}

bool _cyclic(List<RenderNodeDraft> nodes) {
  final visiting = <String>{};
  final visited = <String>{};
  final inputs = {for (final node in nodes) node.id: node.inputIds};
  bool dfs(String id) {
    if (visiting.contains(id)) return true;
    if (visited.contains(id)) return false;
    visiting.add(id);
    for (final input in inputs[id] ?? const <String>[]) {
      if (dfs(input)) return true;
    }
    visiting.remove(id);
    visited.add(id);
    return false;
  }

  for (final node in nodes) {
    if (dfs(node.id)) return true;
  }
  return false;
}
