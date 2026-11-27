import 'package:studio_contracts/studio_contracts.dart';

/// Normalized source presentation time. This is not a timeline frame
/// number and not a constant-fps guess.
final class SourcePts {
  const SourcePts(this.numerator, this.denominator) : assert(denominator > 0);

  final int numerator, denominator;

  double get seconds => numerator / denominator;

  int compareTo(SourcePts other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);

  bool equals(SourcePts other) => compareTo(other) == 0;
}

enum TrackFrameState { tracked, unreviewed, lost, waitingCorrection, locked }

enum TrackerKind { bboxOnly, flowAssisted, memory }

/// Official s8q FrameMaskRef: source PTS + decodeIndex, not an
/// edited-timeline frame number.
final class FrameMaskRef {
  FrameMaskRef({
    required this.sourceBlobId,
    required this.sourceVersion,
    required this.pts,
    required this.decodeIndex,
    required this.frameHash,
  }) {
    requireId(sourceBlobId);
  }

  final String sourceBlobId, sourceVersion, frameHash;
  final SourcePts pts;
  final int decodeIndex;
}

final class TrackFrame {
  TrackFrame({
    required this.ref,
    required this.objectId,
    this.state = TrackFrameState.tracked,
    this.correctionEpoch = 0,
    this.identityFromPreviousShot = false,
  }) {
    requireId(objectId);
  }

  final FrameMaskRef ref;
  final String objectId;
  final TrackFrameState state;
  final int correctionEpoch;
  final bool identityFromPreviousShot;

  bool get locked => state == TrackFrameState.locked;
}

final class CutCandidate {
  CutCandidate({required this.pts, this.confirmed = false});
  final SourcePts pts;
  final bool confirmed;
}

final class RetrackPlan {
  RetrackPlan({
    required this.invalidatedDecodeIndexes,
    required this.lockedFramePreserved,
    required this.acceptedMediaRetained,
    required this.sidesAveraged,
  });

  final List<int> invalidatedDecodeIndexes;
  final bool lockedFramePreserved, acceptedMediaRetained, sidesAveraged;
}

/// DEV-PURE I-044 MaskTrackService. Does not invent a real tracker,
/// auto-segmentation, or optical-flow interpolation.
final class MaskTrackService {
  MaskTrackService({
    required this.sourceBlobId,
    required List<FrameMaskRef> sourceFrames,
    this.speed = 1,
    this.trackerKind = TrackerKind.flowAssisted,
  }) : sourceFrames = List.unmodifiable(sourceFrames);

  final String sourceBlobId;
  final List<FrameMaskRef> sourceFrames;
  final num speed;
  final TrackerKind trackerKind;

  final _frames = <String, TrackFrame>{};
  final _cuts = <CutCandidate>[];
  final acceptedMediaHashes = <String>{};

  int documentWrites = 0;
  int userLayersWritten = 0;
  bool autoEraseStopped = false;
  bool memoryClearedAtCut = false;
  bool realTrackerInvented = false;
  bool autoSegmentationInvented = false;
  bool opticalFlowInvented = false;
  bool v012Claimed = false;
  bool submitted = false;
  bool paidApiCalled = false;

  bool get bboxOnlyIsPreciseMask => false;

  String _key(String objectId, SourcePts pts, int decodeIndex) =>
      '$objectId:${pts.numerator}/${pts.denominator}:$decodeIndex';

  /// Timeline time maps through TimeMap to source PTS. A 2× speed
  /// timeline 0.05s is source 0.1s — not floor(0.05×30).
  SourcePts sourceTimeForTimeline(SourcePts timeline) {
    return SourcePts(
      timeline.numerator * _speedNum,
      timeline.denominator * _speedDen,
    );
  }

  int get _speedNum => speed == 2
      ? 2
      : (speed == 1
            ? 1
            : throw const StudioException(
                'MASK_RETIME_INTERPOLATION_UNSUPPORTED',
                'speed',
              ));

  int get _speedDen => 1;

  FrameMaskRef lookupSource({
    required SourcePts timeline,
    bool useEditedFrameNumber = false,
    int? editedFps,
  }) {
    if (useEditedFrameNumber) {
      throw const StudioException(
        'UNSUPPORTED_EDIT_TECHNIQUE',
        'editedFrameNumber',
      );
    }
    if (editedFps != null) {
      throw const StudioException(
        'UNSUPPORTED_EDIT_TECHNIQUE',
        'constantFpsGuess',
      );
    }
    final source = sourceTimeForTimeline(timeline);
    FrameMaskRef? chosen;
    for (final frame in sourceFrames) {
      if (frame.pts.compareTo(source) <= 0) {
        if (chosen == null ||
            frame.pts.compareTo(chosen.pts) > 0 ||
            (frame.pts.equals(chosen.pts) &&
                frame.decodeIndex > chosen.decodeIndex)) {
          chosen = frame;
        }
      }
    }
    if (chosen == null) {
      throw const StudioException('MASK_OUT_OF_BOUNDS', 'sourcePts');
    }
    documentWrites = 0;
    return chosen;
  }

  void interpolateRetime() {
    throw const StudioException(
      'MASK_RETIME_INTERPOLATION_UNSUPPORTED',
      'opticalFlow',
    );
  }

  void proposeCut(SourcePts pts) {
    _cuts.add(CutCandidate(pts: pts));
    memoryClearedAtCut = false;
  }

  void confirmCut(SourcePts pts) {
    _cuts
      ..removeWhere((cut) => cut.pts.equals(pts))
      ..add(CutCandidate(pts: pts, confirmed: true));
    memoryClearedAtCut = true;
    documentWrites = 0;
  }

  void place(TrackFrame frame) {
    if (frame.ref.sourceBlobId != sourceBlobId) {
      throw const StudioException('MASK_SOURCE_CHANGED', 'track');
    }
    if (_crossesConfirmedCut(frame) && frame.identityFromPreviousShot) {
      throw const StudioException(
        'UNSUPPORTED_EDIT_TECHNIQUE',
        'identityAcrossCut',
      );
    }
    _frames[_key(frame.objectId, frame.ref.pts, frame.ref.decodeIndex)] = frame;
    documentWrites = 0;
  }

  bool _crossesConfirmedCut(TrackFrame frame) {
    return _cuts.any(
      (cut) => cut.confirmed && frame.ref.pts.compareTo(cut.pts) >= 0,
    );
  }

  TrackFrame? frameAt(String objectId, SourcePts pts, int decodeIndex) =>
      _frames[_key(objectId, pts, decodeIndex)];

  RetrackPlan correct({
    required String objectId,
    required FrameMaskRef frameKey,
    required int expectedCorrectionEpoch,
  }) {
    final key = _key(objectId, frameKey.pts, frameKey.decodeIndex);
    final current = _frames[key];
    if (current == null) {
      throw const StudioException('MASK_OUT_OF_BOUNDS', 'correct');
    }
    if (current.correctionEpoch != expectedCorrectionEpoch) {
      throw const StudioException('CORRECTION_EPOCH_STALE', 'correct');
    }
    if (current.locked) {
      throw const StudioException('MASK_LOCK_CONFLICT', 'lockedKeyframe');
    }
    final lockedEpoch = current.correctionEpoch + 1;
    _frames[key] = TrackFrame(
      ref: current.ref,
      objectId: current.objectId,
      state: TrackFrameState.locked,
      correctionEpoch: lockedEpoch,
    );
    final invalidated = <int>[];
    for (final frame in _frames.values) {
      if (frame.objectId != objectId) continue;
      if (frame.ref.decodeIndex == frameKey.decodeIndex) continue;
      if (frame.locked) continue;
      if (_blockedByAnchorOrCut(frameKey, frame)) continue;
      invalidated.add(frame.ref.decodeIndex);
    }
    documentWrites = 0;
    return RetrackPlan(
      invalidatedDecodeIndexes: invalidated..sort(),
      lockedFramePreserved: true,
      acceptedMediaRetained: acceptedMediaHashes.isNotEmpty,
      sidesAveraged: false,
    );
  }

  bool _blockedByAnchorOrCut(FrameMaskRef origin, TrackFrame candidate) {
    final originPts = origin.pts;
    final otherPts = candidate.ref.pts;
    final lo = originPts.compareTo(otherPts) <= 0 ? originPts : otherPts;
    final hi = originPts.compareTo(otherPts) <= 0 ? otherPts : originPts;
    for (final frame in _frames.values) {
      if (frame.objectId != candidate.objectId) continue;
      if (!frame.locked) continue;
      if (frame.ref.decodeIndex == origin.decodeIndex) continue;
      if (frame.ref.pts.compareTo(lo) > 0 && frame.ref.pts.compareTo(hi) < 0) {
        return true;
      }
    }
    for (final cut in _cuts) {
      if (!cut.confirmed) continue;
      final originAfter = origin.pts.compareTo(cut.pts) >= 0;
      final candidateAfter = candidate.ref.pts.compareTo(cut.pts) >= 0;
      if (originAfter != candidateAfter) {
        return true;
      }
    }
    return false;
  }

  TrackFrame markLost({
    required String objectId,
    required FrameMaskRef frameKey,
    bool treatEmptyAsGone = false,
  }) {
    if (treatEmptyAsGone) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'emptyAsGone');
    }
    final key = _key(objectId, frameKey.pts, frameKey.decodeIndex);
    final current = _frames[key];
    if (current == null) {
      throw const StudioException('MASK_OUT_OF_BOUNDS', 'lost');
    }
    if (current.locked) {
      throw const StudioException('MASK_LOCK_CONFLICT', 'lost');
    }
    final updated = TrackFrame(
      ref: current.ref,
      objectId: current.objectId,
      state: TrackFrameState.waitingCorrection,
      correctionEpoch: current.correctionEpoch,
    );
    _frames[key] = updated;
    autoEraseStopped = true;
    documentWrites = 0;
    return updated;
  }
}
