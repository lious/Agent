import 'package:studio_contracts/studio_contracts.dart';

import 'voice_codes.dart';

/// Sealed embedding record. These bytes never enter ordinary archives
/// or journals.
final class VoiceEmbedding {
  VoiceEmbedding({
    required this.embeddingId,
    required this.voiceProfileId,
    required this.traceId,
    required this.bytes,
  }) {
    requireId(embeddingId);
    requireId(voiceProfileId);
    requireId(traceId);
  }

  final String embeddingId, voiceProfileId, traceId;
  final List<int> bytes;
}

final class ArchiveManifest {
  ArchiveManifest(List<Map<String, Object?>> items)
    : items = List.unmodifiable(items);
  final List<Map<String, Object?>> items;

  bool containsKey(String key) =>
      items.any((e) => e.keys.contains(key) || e.values.contains(key));
}

/// Voice vault. Embeddings stay in the sealed store. Archive and log
/// exports refuse to include them.
final class VoiceStore {
  final Map<String, VoiceEmbedding> _vault = {};
  final List<String> _log = [];
  final Map<String, String> traces = {};

  void putEmbedding(VoiceEmbedding embedding) {
    _vault[embedding.embeddingId] = embedding;
    traces[embedding.embeddingId] = embedding.traceId;
    _log.add('stored:${embedding.embeddingId}:trace:${embedding.traceId}');
  }

  VoiceEmbedding readSealed(String embeddingId) {
    final row = _vault[embeddingId];
    if (row == null) {
      throw StudioException(voiceProfileMissing, embeddingId);
    }
    return row;
  }

  ArchiveManifest archiveProject({required String projectId}) {
    requireId(projectId);
    // Only references and traces, never raw embedding bytes or keys.
    return ArchiveManifest([
      {
        'projectId': projectId,
        'voiceRefs': [
          for (final e in _vault.values)
            {
              'embeddingId': e.embeddingId,
              'voiceProfileId': e.voiceProfileId,
              'traceId': e.traceId,
            },
        ],
      },
    ]);
  }

  List<String> exportLog() => List.unmodifiable(_log);

  void assertNoEmbeddingLeak(List<int> embeddingBytes) {
    final archive = archiveProject(projectId: 'proj-1');
    final blob = archive.items.toString() + exportLog().join('\n');
    final token = String.fromCharCodes(embeddingBytes);
    if (blob.contains(token)) {
      throw const StudioException(embeddingNotArchivable);
    }
    for (final item in archive.items) {
      if (item.containsKey('embedding') || item.containsKey('bytes')) {
        throw const StudioException(embeddingNotArchivable);
      }
    }
  }
}
