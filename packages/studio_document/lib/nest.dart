import 'package:studio_contracts/studio_contracts.dart';

import 'retime.dart';
import 'time.dart';

const nestCycle = 'NEST_CYCLE';
const nestDepth = 'NEST_DEPTH';

final class NestEdge {
  NestEdge({
    required this.clipId,
    required this.childSequenceId,
    required this.version,
    RetimeMap? timeMap,
  }) : timeMap = timeMap ?? RetimeMap.linear(rate: Q.of(1), duration: Q.of(1));

  final String clipId, childSequenceId, version;
  final RetimeMap timeMap;
}

/// Nested sequence DAG. Nest clips reference a child sequenceId at a
/// fixed version. Cycles are refused. Maximum depth is 8. This does not
/// persist MakeCompound / UpgradeNest and does not auto-follow versions.
final class NestResolver {
  NestResolver(this.edgesBySequence);
  static const maxDepth = 8;

  /// Parent sequence id → nest edges into child sequences.
  final Map<String, List<NestEdge>> edgesBySequence;

  void validate({String? root}) {
    final visiting = <String>{};
    final visited = <String>{};

    int walk(String id, int depth) {
      if (depth > maxDepth) {
        throw StudioException(nestDepth, id);
      }
      if (visiting.contains(id)) {
        throw StudioException(nestCycle, id);
      }
      if (visited.contains(id)) return depth;
      visiting.add(id);
      var deepest = depth;
      for (final edge in edgesBySequence[id] ?? const <NestEdge>[]) {
        final child = walk(edge.childSequenceId, depth + 1);
        if (child > deepest) deepest = child;
      }
      visiting.remove(id);
      visited.add(id);
      return deepest;
    }

    if (root != null) {
      walk(root, 1);
      return;
    }
    for (final id in edgesBySequence.keys) {
      walk(id, 1);
    }
  }

  /// Compose source offsets through a nest path of TimeMaps, outer first.
  /// Each step uses [RetimeMap.sourceAt], not a frame index.
  Q sourceAt(Q clipLocal, List<RetimeMap> stack) {
    validate();
    if (stack.length > maxDepth) {
      throw const StudioException(nestDepth, 'stack');
    }
    var t = clipLocal;
    for (final map in stack) {
      t = map.sourceAt(t);
    }
    return t;
  }
}
