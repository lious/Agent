import 'package:studio_contracts/studio_contracts.dart';

import 'artifact.dart';
import 'context_codes.dart';
import 'hashing.dart';
import 'locators.dart';

final class ProjectionChunk {
  ProjectionChunk({
    required this.id,
    required this.text,
    required this.kind,
    required List<String> citationIds,
    this.trust = 'untrusted',
  }) : citationIds = List.unmodifiable(citationIds) {
    requireId(id);
  }

  final String id, text, kind, trust;
  final List<String> citationIds;
}

final class TextProjection {
  TextProjection({
    required this.id,
    required List<ProjectionChunk> chunks,
    required List<String> sourceArtifactIds,
    required this.complete,
    List<String>? omittedIds,
  }) : chunks = List.unmodifiable(chunks),
       sourceArtifactIds = List.unmodifiable(sourceArtifactIds),
       omittedIds = List.unmodifiable(omittedIds ?? const []) {
    requireId(id);
    if (complete && omittedIds != null && omittedIds.isNotEmpty) {
      throw const StudioException(silentTruncateForbidden, 'projection');
    }
  }

  final String id;
  final List<ProjectionChunk> chunks;
  final List<String> sourceArtifactIds;
  final bool complete;
  final List<String> omittedIds;

  String get projectionHash => fingerprintJson({
    'id': id,
    'chunks': [
      for (final c in chunks)
        {'id': c.id, 'text': c.text, 'kind': c.kind, 'citationIds': c.citationIds},
    ],
    'complete': complete,
    'omittedIds': omittedIds,
  });
}

/// Compiles artifacts into a cited text projection. Observations and
/// inferences stay labeled. A tight budget returns a partial projection
/// with omitted ids; it does not silently drop citations from a claim
/// and call the result complete.
final class ProjectionCompiler {
  TextProjection project({
    required String id,
    required List<AnalysisArtifact> artifacts,
    int? maxChunks,
  }) {
    requireId(id);
    final chunks = <ProjectionChunk>[];
    final omitted = <String>[];
    for (final artifact in artifacts) {
      for (final claim in artifact.claims) {
        if (maxChunks != null && chunks.length >= maxChunks) {
          omitted.add(claim.id);
          continue;
        }
        chunks.add(
          ProjectionChunk(
            id: 'proj-${claim.id}',
            text: _format(claim),
            kind: claim.kind.name,
            citationIds: [claim.id],
          ),
        );
      }
    }
    return TextProjection(
      id: id,
      chunks: chunks,
      sourceArtifactIds: [for (final a in artifacts) a.id],
      complete: omitted.isEmpty,
      omittedIds: omitted,
    );
  }

  static String _format(EvidenceUnit claim) {
    final loc = claim.evidence.first;
    final where = _where(loc);
    final label = switch (claim.kind) {
      EvidenceKind.observation => '观察',
      EvidenceKind.inference => '推断',
      EvidenceKind.userAssertion => '用户断言',
      EvidenceKind.derivedMetric => '派生度量',
    };
    final limits = claim.limitations.isEmpty
        ? ''
        : '；${claim.limitations.join('；')}';
    return '[${claim.id} $label $where] ${claim.text}$limits';
  }

  static String _where(EvidenceLocator loc) {
    return switch (loc.kind) {
      LocatorKind.page => 'page${loc.page} bytes[${loc.startByte},${loc.endByte})',
      LocatorKind.text => 'bytes[${loc.startByte},${loc.endByte})',
      LocatorKind.image => 'bbox=${loc.bbox}',
      LocatorKind.time => 'pts[${loc.startPtsMs},${loc.endPtsMs})',
    };
  }
}
