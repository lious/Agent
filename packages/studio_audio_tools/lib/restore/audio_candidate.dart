import 'package:studio_contracts/studio_contracts.dart';

const officialStemLabels = ['drums', 'bass', 'other', 'vocals'];

enum RestoreDisposition { preview, paused, downgraded, cancelled }

final class LockedCaptionRef {
  const LockedCaptionRef({required this.id, required this.text});

  final String id;
  final String text;
}

final class DenoiseStateLease {
  DenoiseStateLease({required this.id});

  final int id;
  bool released = false;
}

final class OlaChunk {
  OlaChunk({
    required this.index,
    required this.present,
    this.hasNan = false,
    this.clipped = false,
    this.boundaryWeight = 1,
  });

  final int index;
  final bool present, hasNan, clipped;
  final int boundaryWeight;
}

final class AudioDerivedCandidate {
  AudioDerivedCandidate({
    required this.originalHash,
    required this.stems,
    required this.residualReported,
    required this.residualIsZeroClaimed,
    required this.originalOverwritten,
    required this.originalEditable,
    required this.asrCacheValid,
    required this.lockedCaptions,
    required this.autoAccepted,
    required this.disposition,
  });

  final String originalHash;
  final List<String> stems;
  final bool residualReported,
      residualIsZeroClaimed,
      originalOverwritten,
      originalEditable,
      asrCacheValid,
      autoAccepted;
  final List<LockedCaptionRef> lockedCaptions;
  final RestoreDisposition disposition;
}

/// DEV-PURE I-047 AudioDerivedCandidate protocol. This is not a
/// real RNNoise or stem-separation engine and not a V-010
/// qualification.
final class AudioRestoreSession {
  AudioRestoreSession({
    required this.originalHash,
    this.v010Met = false,
    this.resourceSufficient = true,
    List<LockedCaptionRef>? lockedCaptions,
  }) : lockedCaptions = List.unmodifiable(
         lockedCaptions ??
             const [
               LockedCaptionRef(id: 'cue.locked.1', text: 'keep this line'),
             ],
       );

  final String originalHash;
  final bool v010Met, resourceSufficient;
  final List<LockedCaptionRef> lockedCaptions;

  int _nextStateId = 1;
  int cancelCount = 0;
  int liveStates = 0;
  int releasedStates = 0;
  int asrCacheGeneration = 0;
  bool asrCacheValid = true;
  bool originalOverwritten = false;
  bool originalDeleted = false;
  bool originalEditable = true;
  bool attachedToTimeline = false;
  bool rnnoiseEngineInvented = false;
  bool stemEngineInvented = false;
  bool v010Claimed = false;
  bool v009Claimed = false;
  bool limiterInvented = false;
  bool paidApiCalled = false;
  bool submitted = false;

  final List<DenoiseStateLease> _leases = [];

  DenoiseStateLease createState() {
    final lease = DenoiseStateLease(id: _nextStateId++);
    _leases.add(lease);
    liveStates++;
    return lease;
  }

  void cancel(DenoiseStateLease lease) {
    if (!lease.released) {
      lease.released = true;
      liveStates--;
      releasedStates++;
    }
    cancelCount++;
    attachedToTimeline = false;
    originalOverwritten = false;
    originalDeleted = false;
    originalEditable = true;
  }

  void useState(DenoiseStateLease lease) {
    if (lease.released) {
      throw const StudioException('STATE_RELEASED', 'denoiseState');
    }
  }

  void recreateStateEveryFrame() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'perFrameCreate');
  }

  AudioDerivedCandidate preview() {
    if (!resourceSufficient) {
      return AudioDerivedCandidate(
        originalHash: originalHash,
        stems: officialStemLabels,
        residualReported: true,
        residualIsZeroClaimed: false,
        originalOverwritten: false,
        originalEditable: true,
        asrCacheValid: asrCacheValid,
        lockedCaptions: lockedCaptions,
        autoAccepted: false,
        disposition: RestoreDisposition.paused,
      );
    }
    return AudioDerivedCandidate(
      originalHash: originalHash,
      stems: officialStemLabels,
      residualReported: true,
      residualIsZeroClaimed: false,
      originalOverwritten: false,
      originalEditable: true,
      asrCacheValid: asrCacheValid,
      lockedCaptions: lockedCaptions,
      autoAccepted: false,
      disposition: RestoreDisposition.preview,
    );
  }

  AudioDerivedCandidate downgradeProposal() {
    return AudioDerivedCandidate(
      originalHash: originalHash,
      stems: officialStemLabels,
      residualReported: true,
      residualIsZeroClaimed: false,
      originalOverwritten: false,
      originalEditable: true,
      asrCacheValid: asrCacheValid,
      lockedCaptions: lockedCaptions,
      autoAccepted: false,
      disposition: RestoreDisposition.downgraded,
    );
  }

  void peakNormalizePerStem() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'perStemGain');
  }

  void claimResidualIsZero() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'residualZero');
  }

  void treatSeparationAsDenoise() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'sepAsDenoise');
  }

  void treatSeparationAsSpeakerSplit() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'speakerSplit');
  }

  void treatVadAsWordConfidence() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'vadAsWord');
  }

  void overwriteOriginal() {
    throw const StudioException(
      'UNSUPPORTED_EDIT_TECHNIQUE',
      'overwriteOriginal',
    );
  }

  void admitOla({
    required int sourceSampleCount,
    required int outputSampleCount,
    required List<OlaChunk> chunks,
    bool doubleCompensateLatency = false,
  }) {
    if (doubleCompensateLatency) {
      throw const StudioException('DOUBLE_LATENCY_COMPENSATION', 'latency');
    }
    if (outputSampleCount < sourceSampleCount) {
      throw const StudioException('CROSSFADE_SHORTENS', 'ola');
    }
    for (final chunk in chunks) {
      if (!chunk.present) {
        throw const StudioException('OLA_CHUNK_MISSING', 'ola');
      }
      if (chunk.hasNan) {
        throw const StudioException('OLA_NAN_OUTPUT', 'ola');
      }
      if (chunk.clipped) {
        throw const StudioException('OLA_CLIP', 'ola');
      }
      if (chunk.boundaryWeight == 0) {
        throw const StudioException('OLA_ZERO_BOUNDARY_WEIGHT', 'ola');
      }
    }
  }

  void changePreprocess() {
    asrCacheGeneration++;
    asrCacheValid = false;
  }

  void overwriteLockedCaption(String id, String newText) {
    final locked = lockedCaptions.any((c) => c.id == id);
    if (locked) {
      throw const StudioException('FIELD_LOCKED', 'lockedCue');
    }
  }

  void autoAcceptRestore() {
    if (!v010Met) {
      throw const StudioException('V010_GATE_UNMET', 'autoAccept');
    }
  }

  void fillWithoutQualifiedPack() {
    throw const StudioException('MODEL_ABI_UNVERIFIED', 'restorePack');
  }
}
