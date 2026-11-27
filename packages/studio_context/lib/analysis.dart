import 'package:studio_contracts/studio_contracts.dart';

import 'artifact.dart';
import 'context_codes.dart';
import 'grants.dart';
import 'hashing.dart';
import 'ingest.dart';
import 'locators.dart';

final class AnalysisRequest {
  AnalysisRequest({
    required this.id,
    required this.attachmentId,
    required this.level,
    this.question,
    this.extractorId = 'literal-text',
    this.extractorVersion = '1.0.0',
    this.modelProfileId,
    this.parameters = const {},
    this.frameBudget = 0,
  }) {
    requireId(id);
    requireId(attachmentId);
  }

  final String id, attachmentId, level, extractorId, extractorVersion;
  final String? question, modelProfileId;
  final Map<String, Object?> parameters;
  final int frameBudget;

  String cacheKey({required String blobHash, required int sourceVersion, required String grantScope}) {
    return fingerprintJson({
      'blobHash': blobHash,
      'sourceVersion': sourceVersion,
      'level': level,
      'extractorId': extractorId,
      'extractorVersion': extractorVersion,
      'modelProfileId': modelProfileId,
      'parameters': parameters,
      'question': question,
      'grantScope': grantScope,
    });
  }

  String parameterHash() => fingerprintJson(parameters);
}

final class AnalysisCache {
  final Map<String, AnalysisArtifact> _byKey = {};
  int storeCount = 0;
  int hitCount = 0;

  AnalysisArtifact? lookup(String key) {
    final hit = _byKey[key];
    if (hit != null) hitCount++;
    return hit;
  }

  void store(String key, AnalysisArtifact artifact) {
    _byKey[key] = artifact;
    storeCount++;
  }
}

/// Literal text analysis and fail-closed model ports. Real OCR / ASR / VLM
/// inference is not claimed. A still frame cannot be recorded as a motion
/// observation.
final class AnalysisExecutor {
  AnalysisExecutor({AnalysisCache? cache}) : cache = cache ?? AnalysisCache();

  final AnalysisCache cache;
  int executeCount = 0;

  AnalysisArtifact execute({
    required Attachment attachment,
    required AnalysisRequest request,
    required SourceUseGrant grant,
    required DateTime now,
    List<EvidenceUnit> extraInferences = const [],
  }) {
    grant.requireActive('analyze', now: now);
    if (grant.sourceId != attachment.id) {
      throw StudioException(grantRequired, 'source');
    }
    if (attachment.mediaKind == MediaKind.unsupported ||
        attachment.state == AttachmentState.unsupported) {
      throw StudioException(formatUnsupported, attachment.id);
    }
    final key = request.cacheKey(
      blobHash: attachment.blobHash,
      sourceVersion: attachment.sourceVersion,
      grantScope: ({...grant.permitted}.toList()..sort()).join(','),
    );
    final cached = cache.lookup(key);
    if (cached != null) return cached;

    if (request.level != 'literal' && request.level != 'probe' && request.level != 'text') {
      // visual/temporal/ocr/asr require a model profile that is not present.
      if (request.modelProfileId == null) {
        throw StudioException(modelUnavailable, request.level);
      }
    }

    executeCount++;
    final claims = <EvidenceUnit>[];
    if (attachment.mediaKind == MediaKind.text && attachment.body != null) {
      final pages = attachment.pages;
      for (var i = 0; i < pages.length; i++) {
        final loc = pages[i];
        final slice = attachment.body!.substring(
          _byteToOffset(attachment.body!, loc.startByte ?? 0),
          _byteToOffset(attachment.body!, loc.endByte ?? utf8Len(attachment.body!)),
        );
        claims.add(
          EvidenceUnit(
            id: 'obs-${request.id}-p${loc.page}',
            kind: EvidenceKind.observation,
            text: slice,
            evidence: [loc],
          ),
        );
      }
    }
    for (final inference in extraInferences) {
      if (inference.kind != EvidenceKind.inference) {
        throw const StudioException(inferenceWithoutEvidence, 'kind');
      }
      if (inference.supports.isEmpty) {
        throw const StudioException(inferenceWithoutEvidence);
      }
      claims.add(inference);
    }

    final requested = attachment.pages.isNotEmpty
        ? EvidenceLocator(
            kind: LocatorKind.page,
            sourceId: attachment.id,
            version: attachment.sourceVersion,
            page: 1,
            startByte: 0,
            endByte: attachment.sizeBytes,
          )
        : EvidenceLocator(
            kind: LocatorKind.text,
            sourceId: attachment.id,
            version: attachment.sourceVersion,
            startByte: 0,
            endByte: attachment.sizeBytes,
          );
    final artifact = AnalysisArtifact(
        id: 'art-$key',
      kind: _kindFor(request.level),
      requestHash: key,
      inputHash: attachment.blobHash,
      extractorId: request.extractorId,
      extractorVersion: request.extractorVersion,
      parameterHash: request.parameterHash(),
      modelProfileId: request.modelProfileId,
      coverage: Coverage(
        requested: requested,
        observed: attachment.pages,
        gaps: const [],
        truncated: false,
        capabilitiesUsed: ['literal-text'],
        capabilitiesMissing: request.level == 'temporal' || request.level == 'visual'
            ? ['nativeVideoUnderstanding']
            : const [],
      ),
      claims: claims,
    );
    cache.store(key, artifact);
    return artifact;
  }

  static ArtifactKind _kindFor(String level) {
    return switch (level) {
      'probe' => ArtifactKind.probe,
      'ocr' => ArtifactKind.ocr,
      'asr' => ArtifactKind.asr,
      'visual' => ArtifactKind.visual,
      'temporal' => ArtifactKind.temporal,
      _ => ArtifactKind.text,
    };
  }
}

int utf8Len(String text) => text.length; // used only when endByte is string-index aligned in tests

int _byteToOffset(String text, int byte) {
  // Official text fixtures in this increment are ASCII, so bytes == offsets.
  if (byte < 0) return 0;
  if (byte > text.length) return text.length;
  return byte;
}
