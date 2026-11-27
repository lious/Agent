import 'package:studio_contracts/studio_contracts.dart';

enum CoverageKind { observed, inferred }

final class EraseChunk {
  EraseChunk({
    required this.index,
    required this.valid,
    this.coverage = CoverageKind.observed,
  });

  final int index;
  final bool valid;
  final CoverageKind coverage;
}

final class VideoEraseReceipt {
  VideoEraseReceipt({
    required this.originalHash,
    required this.inferredRegionMarked,
    required this.inferredBackgroundIsFact,
    required this.lockedMaskUnchanged,
    required this.lockedCaptionUnchanged,
    required this.lockedTrimUnchanged,
    required this.originalAudioRetained,
    required this.resumedFromChunk,
    required this.autoAccepted,
    required this.userLayersWritten,
  });

  final String originalHash;
  final bool inferredRegionMarked,
      inferredBackgroundIsFact,
      lockedMaskUnchanged,
      lockedCaptionUnchanged,
      lockedTrimUnchanged,
      originalAudioRetained,
      autoAccepted;
  final int resumedFromChunk, userLayersWritten;
}

/// DEV-PURE I-045 VideoEraseCandidate protocol. This is not a
/// temporal inpaint engine and not a V-012 qualification.
final class VideoEraseSession {
  VideoEraseSession({
    required this.originalHash,
    this.lockedMask = false,
    this.lockedCaption = false,
    this.lockedTrim = false,
    this.v012Met = false,
    List<EraseChunk>? chunks,
  }) : chunks = List.unmodifiable(
         chunks ??
             [
               for (var i = 0; i < 10; i++)
                 EraseChunk(
                   index: i,
                   valid: i < 4,
                   coverage: i < 4
                       ? CoverageKind.observed
                       : CoverageKind.inferred,
                 ),
             ],
       );

  final String originalHash;
  final bool lockedMask, lockedCaption, lockedTrim, v012Met;
  final List<EraseChunk> chunks;

  int documentWrites = 0;
  int userLayersWritten = 0;
  bool originalDeleted = false;
  bool temporalInpaintEngineInvented = false;
  bool framewiseLamaClaimedStable = false;
  bool v012Claimed = false;
  bool v011Claimed = false;
  bool submitted = false;
  bool paidApiCalled = false;

  int get lastValidChunkIndex {
    var last = -1;
    for (final chunk in chunks) {
      if (chunk.valid) last = chunk.index;
    }
    return last;
  }

  List<int> get inferredRegionIndexes => [
    for (final chunk in chunks)
      if (chunk.coverage == CoverageKind.inferred) chunk.index,
  ];

  VideoEraseReceipt preview() {
    documentWrites = 0;
    return VideoEraseReceipt(
      originalHash: originalHash,
      inferredRegionMarked: inferredRegionIndexes.isNotEmpty,
      inferredBackgroundIsFact: false,
      lockedMaskUnchanged: true,
      lockedCaptionUnchanged: true,
      lockedTrimUnchanged: true,
      originalAudioRetained: true,
      resumedFromChunk: 0,
      autoAccepted: false,
      userLayersWritten: 0,
    );
  }

  VideoEraseReceipt resumeAfterInterrupt() {
    final lastValid = lastValidChunkIndex;
    if (lastValid < 0) {
      throw const StudioException('MASK_OUT_OF_BOUNDS', 'noValidChunk');
    }
    documentWrites = 0;
    submitted = false;
    return VideoEraseReceipt(
      originalHash: originalHash,
      inferredRegionMarked: inferredRegionIndexes.isNotEmpty,
      inferredBackgroundIsFact: false,
      lockedMaskUnchanged: true,
      lockedCaptionUnchanged: true,
      lockedTrimUnchanged: true,
      originalAudioRetained: true,
      resumedFromChunk: lastValid,
      autoAccepted: false,
      userLayersWritten: 0,
    );
  }

  void overwriteLockedMask() {
    throw const StudioException('MASK_LOCK_CONFLICT', 'lockedMask');
  }

  void overwriteLockedCaption() {
    throw const StudioException('FIELD_LOCKED', 'lockedCaption');
  }

  void moveLockedTrim() {
    throw const StudioException('FIELD_LOCKED', 'lockedTrim');
  }

  void autoAcceptTenSegments() {
    if (!v012Met) {
      throw const StudioException('V012_GATE_UNMET', 'autoAccept');
    }
  }

  void claimFramewiseLamaStable() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'framewiseLama');
  }

  void fillWithoutQualifiedPack({bool labelClassicAsTemporal = false}) {
    if (labelClassicAsTemporal) {
      throw const StudioException(
        'UNSUPPORTED_EDIT_TECHNIQUE',
        'classicMislabel',
      );
    }
    throw const StudioException('MODEL_ABI_UNVERIFIED', 'temporalFill');
  }

  void useNearStaticReconstruction({required bool userConsent}) {
    if (!userConsent) {
      throw const StudioException('APPROVAL_REQUIRED', 'staticAnchor');
    }
  }

  void lateCancel() {
    userLayersWritten = 0;
    documentWrites = 0;
    originalDeleted = false;
  }
}
