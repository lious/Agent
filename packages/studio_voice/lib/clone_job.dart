import 'package:studio_contracts/studio_contracts.dart';

import 'voice_codes.dart';
import 'voice_consent.dart';
import 'voice_store.dart';

abstract interface class CloneBackend {
  /// Official tests use a backend that never runs clone inference.
  VoiceEmbedding infer({
    required String voiceProfileId,
    required String traceId,
    required List<int> referencePcm,
  });
}

/// Fail-closed clone backend. Real clone inference is not claimed.
final class FakeCloneBackend implements CloneBackend {
  @override
  VoiceEmbedding infer({
    required String voiceProfileId,
    required String traceId,
    required List<int> referencePcm,
  }) {
    throw const StudioException(cloneInferenceUnavailable);
  }
}

final class CloneJob {
  CloneJob({
    required this.id,
    required this.voiceProfileId,
    required this.traceId,
    required this.ledger,
    required this.store,
    required this.backend,
    this.subjectIsOwner = true,
  }) {
    requireId(id);
    requireId(voiceProfileId);
    requireId(traceId);
    if (traceId.isEmpty) {
      throw const StudioException(traceRequired);
    }
  }

  final String id, voiceProfileId, traceId;
  final VoiceConsentLedger ledger;
  final VoiceStore store;
  final CloneBackend backend;
  final bool subjectIsOwner;
  int attempts = 0;

  /// Consent is required for a real-person clone. A third-party
  /// impersonation without consent is refused; this is not a blanket ban.
  VoiceEmbedding execute({required List<int> referencePcm}) {
    if (!subjectIsOwner) {
      ledger.require(voiceProfileId, 'voiceClone');
    } else {
      ledger.require(voiceProfileId, 'voiceClone');
    }
    attempts++;
    try {
      final embedding = backend.infer(
        voiceProfileId: voiceProfileId,
        traceId: traceId,
        referencePcm: referencePcm,
      );
      ledger.recordExecution(voiceProfileId);
      store.putEmbedding(embedding);
      return embedding;
    } on StudioException {
      // Failures, including missing inference, must not increment
      // successful new-execution counts.
      rethrow;
    }
  }
}
