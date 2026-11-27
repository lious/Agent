import 'package:studio_contracts/studio_contracts.dart';

import 'context_codes.dart';
import 'hashing.dart';
import 'locators.dart';

enum EvidenceKind { observation, inference, userAssertion, derivedMetric }

enum ArtifactKind { probe, text, ocr, asr, visual, temporal }

enum Completeness { complete, partial }

final class EvidenceUnit {
  EvidenceUnit({
    required this.id,
    required this.kind,
    required this.text,
    required List<EvidenceLocator> evidence,
    List<String> limitations = const [],
    List<String> supports = const [],
    this.confidence,
  }) : evidence = List.unmodifiable(evidence),
       limitations = List.unmodifiable(limitations),
       supports = List.unmodifiable(supports) {
    requireId(id);
    if (evidence.isEmpty) {
      throw StudioException('INVALID_ID', 'evidence');
    }
    if (kind == EvidenceKind.inference && supports.isEmpty) {
      throw const StudioException(inferenceWithoutEvidence);
    }
  }

  final String id, text;
  final EvidenceKind kind;
  final List<EvidenceLocator> evidence;
  final List<String> limitations, supports;
  final num? confidence;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'text': text,
    'evidence': [for (final e in evidence) e.toJson()],
    'limitations': limitations,
    'supports': supports,
    'confidence': confidence,
  };
}

final class Coverage {
  Coverage({
    required this.requested,
    required List<EvidenceLocator> observed,
    required List<EvidenceLocator> gaps,
    required this.truncated,
    List<String>? capabilitiesUsed,
    List<String>? capabilitiesMissing,
    List<int>? sampledFramePtsMs,
  }) : observed = List.unmodifiable(observed),
       gaps = List.unmodifiable(gaps),
       capabilitiesUsed = List.unmodifiable(capabilitiesUsed ?? const []),
       capabilitiesMissing = List.unmodifiable(capabilitiesMissing ?? const []),
       sampledFramePtsMs = List.unmodifiable(sampledFramePtsMs ?? const []);

  final EvidenceLocator requested;
  final List<EvidenceLocator> observed, gaps;
  final bool truncated;
  final List<String> capabilitiesUsed, capabilitiesMissing;
  final List<int> sampledFramePtsMs;

  Map<String, Object?> toJson() => {
    'requested': requested.toJson(),
    'observed': [for (final o in observed) o.toJson()],
    'gaps': [for (final g in gaps) g.toJson()],
    'truncated': truncated,
    'capabilitiesUsed': capabilitiesUsed,
    'capabilitiesMissing': capabilitiesMissing,
    'sampledFramePtsMs': sampledFramePtsMs,
  };
}

final class AnalysisArtifact {
  AnalysisArtifact({
    required this.id,
    required this.kind,
    required this.requestHash,
    required this.inputHash,
    required this.extractorId,
    required this.extractorVersion,
    required this.parameterHash,
    required this.coverage,
    required List<EvidenceUnit> claims,
    this.modelProfileId,
    this.completeness = Completeness.complete,
  }) : claims = List.unmodifiable(claims) {
    requireId(id);
    if (coverage.truncated && completeness == Completeness.complete) {
      throw const StudioException(silentTruncateForbidden);
    }
    for (final claim in this.claims) {
      if (claim.kind == EvidenceKind.inference && claim.supports.isEmpty) {
        throw const StudioException(inferenceWithoutEvidence);
      }
    }
  }

  final String id, requestHash, inputHash, extractorId, extractorVersion, parameterHash;
  final ArtifactKind kind;
  final String? modelProfileId;
  final Completeness completeness;
  final Coverage coverage;
  final List<EvidenceUnit> claims;

  Iterable<EvidenceUnit> get observations =>
      claims.where((c) => c.kind == EvidenceKind.observation);

  Iterable<EvidenceUnit> get inferences =>
      claims.where((c) => c.kind == EvidenceKind.inference);

  String artifactHash() => fingerprintJson({
    'id': id,
    'kind': kind.name,
    'requestHash': requestHash,
    'inputHash': inputHash,
    'extractorId': extractorId,
    'extractorVersion': extractorVersion,
    'parameterHash': parameterHash,
    'modelProfileId': modelProfileId,
    'completeness': completeness.name,
    'coverage': coverage.toJson(),
    'claims': [for (final c in claims) c.toJson()],
  });
}
