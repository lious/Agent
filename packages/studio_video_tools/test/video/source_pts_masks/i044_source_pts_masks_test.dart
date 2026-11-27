import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_video_tools/studio_video_tools.dart';
import 'package:test/test.dart';

/// Increment 2.65 official first I-044 slice: source-PTS lookup, cut
/// reset, locked-keyframe invalidation, and lost→waitingCorrection.
/// This file does not invent a real tracker, auto-segmentation, or
/// optical-flow interpolation, does not claim V-012, does not start
/// I-045, does not re-qualify I-043 or I-026, and does not mark
/// I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040,
/// I-053, I-056, I-057, I-052, I-039, V-026, or I-043 complete.
/// InversePatch kind stays restoreSnapshot. Project user_version
/// stays 9.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

FrameMaskRef frame(int decodeIndex, int num, int den) => FrameMaskRef(
  sourceBlobId: 'src-1',
  sourceVersion: 'v1',
  pts: SourcePts(num, den),
  decodeIndex: decodeIndex,
  frameHash: 'frame-$decodeIndex',
);

List<FrameMaskRef> vfrSource() => [
  frame(0, 0, 1),
  frame(1, 1, 24),
  frame(2, 1, 10),
  frame(3, 1, 5),
];

MaskTrackService service({num speed = 1}) => MaskTrackService(
  sourceBlobId: 'src-1',
  sourceFrames: vfrSource(),
  speed: speed,
);

void main() {
  test('VFR and 2x retime look up masks by source PTS, not edited frame numbers; trim does not change the source index', () {
    final track = service(speed: 2);
    final mapped = track.lookupSource(timeline: const SourcePts(1, 20));
    expect(mapped.pts.seconds, closeTo(0.1, 1e-12));
    expect(mapped.decodeIndex, 2);
    expect(mapped.pts.equals(const SourcePts(1, 10)), isTrue);
    expect(
      () => track.lookupSource(
        timeline: const SourcePts(1, 20),
        useEditedFrameNumber: true,
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => track.lookupSource(timeline: const SourcePts(1, 20), editedFps: 30),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => track.interpolateRetime(),
      code('MASK_RETIME_INTERPOLATION_UNSUPPORTED'),
    );

    final afterTrim = track.lookupSource(timeline: const SourcePts(1, 20));
    expect(afterTrim.decodeIndex, mapped.decodeIndex);
    expect(afterTrim.pts.equals(mapped.pts), isTrue);
    expect(afterTrim.sourceBlobId, 'src-1');
    expect(track.documentWrites, 0);
    expect(track.opticalFlowInvented, isFalse);
    expect(track.v012Claimed, isFalse);
  });

  test('a confirmed cut clears memory and does not inherit identity; a keyframe correction only invalidates the block to the next lock or cut', () {
    final track = service();
    track.proposeCut(const SourcePts(1, 10));
    expect(track.memoryClearedAtCut, isFalse);
    track.confirmCut(const SourcePts(1, 10));
    expect(track.memoryClearedAtCut, isTrue);
    expect(
      () => track.place(
        TrackFrame(
          ref: frame(3, 1, 5),
          objectId: 'obj-1',
          identityFromPreviousShot: true,
        ),
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );

    for (final ref in vfrSource()) {
      track.place(TrackFrame(ref: ref, objectId: 'obj-1'));
    }
    track.acceptedMediaHashes.add('accepted-nle-1');
    final plan = track.correct(
      objectId: 'obj-1',
      frameKey: frame(1, 1, 24),
      expectedCorrectionEpoch: 0,
    );
    expect(plan.lockedFramePreserved, isTrue);
    expect(plan.sidesAveraged, isFalse);
    expect(plan.acceptedMediaRetained, isTrue);
    expect(plan.invalidatedDecodeIndexes, [0]);
    expect(plan.invalidatedDecodeIndexes, isNot(contains(1)));
    expect(plan.invalidatedDecodeIndexes, isNot(contains(2)));
    expect(plan.invalidatedDecodeIndexes, isNot(contains(3)));
    expect(track.frameAt('obj-1', const SourcePts(1, 24), 1)?.locked, isTrue);
    expect(
      () => track.correct(
        objectId: 'obj-1',
        frameKey: frame(1, 1, 24),
        expectedCorrectionEpoch: 1,
      ),
      code('MASK_LOCK_CONFLICT'),
    );
    expect(
      () => track.correct(
        objectId: 'obj-1',
        frameKey: frame(0, 0, 1),
        expectedCorrectionEpoch: 99,
      ),
      code('CORRECTION_EPOCH_STALE'),
    );
  });

  test('a lost object becomes waitingCorrection; an empty mask is not treated as gone; auto-erase stops; bbox-only is not a precise mask', () {
    final track = service();
    track.place(TrackFrame(ref: frame(1, 1, 24), objectId: 'obj-1'));
    expect(
      () => track.markLost(
        objectId: 'obj-1',
        frameKey: frame(1, 1, 24),
        treatEmptyAsGone: true,
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    final lost = track.markLost(objectId: 'obj-1', frameKey: frame(1, 1, 24));
    expect(lost.state, TrackFrameState.waitingCorrection);
    expect(track.autoEraseStopped, isTrue);
    expect(track.bboxOnlyIsPreciseMask, isFalse);
    expect(track.trackerKind, TrackerKind.flowAssisted);
    expect(track.realTrackerInvented, isFalse);
    expect(track.autoSegmentationInvented, isFalse);
    expect(track.v012Claimed, isFalse);
    expect(track.userLayersWritten, 0);
    expect(track.submitted, isFalse);
    expect(track.paidApiCalled, isFalse);
  });
}
