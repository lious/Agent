import 'package:studio_audio_tools/studio_audio_tools.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

/// Increment 2.67 official first I-047 slice: derived-stem
/// provenance, original-audio preservation, 100-cancel State
/// release, preprocess-cache invalidation that does not rewrite
/// locked captions, and no auto-accept without V-010. This file
/// does not invent a real RNNoise or stem-separation engine, does
/// not claim V-010 or V-009, does not rewrite I-046 locked
/// captions or I-046 official tests, does not invent a limiter,
/// does not start I-048, I-061, I-055, or I-035, and does not
/// mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041,
/// I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044,
/// or I-045 complete. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9. V-010 stays blocked.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

const originalHash =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

AudioRestoreSession session({bool resourceSufficient = true}) =>
    AudioRestoreSession(
      originalHash: originalHash,
      resourceSufficient: resourceSufficient,
    );

void main() {
  test('stems are derived candidates; the original is not overwritten and stays editable when resources are insufficient', () {
    final restore = session();
    final preview = restore.preview();
    expect(preview.stems, officialStemLabels);
    expect(preview.residualReported, isTrue);
    expect(preview.residualIsZeroClaimed, isFalse);
    expect(preview.originalHash, originalHash);
    expect(preview.originalOverwritten, isFalse);
    expect(preview.originalEditable, isTrue);
    expect(preview.autoAccepted, isFalse);
    expect(preview.disposition, RestoreDisposition.preview);
    expect(
      () => restore.overwriteOriginal(),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => restore.peakNormalizePerStem(),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => restore.claimResidualIsZero(),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => restore.treatSeparationAsDenoise(),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => restore.treatSeparationAsSpeakerSplit(),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );

    final paused = session(resourceSufficient: false).preview();
    expect(paused.disposition, RestoreDisposition.paused);
    expect(paused.originalOverwritten, isFalse);
    expect(paused.originalEditable, isTrue);
    expect(paused.originalHash, originalHash);
    final downgraded = restore.downgradeProposal();
    expect(downgraded.disposition, RestoreDisposition.downgraded);
    expect(downgraded.originalEditable, isTrue);
    expect(downgraded.originalOverwritten, isFalse);
  });

  test(
    '100 cancels each release DenoiseState; a released state cannot be reused',
    () {
      final restore = session();
      final leases = [for (var i = 0; i < 100; i++) restore.createState()];
      expect(restore.liveStates, 100);
      for (final lease in leases) {
        restore.cancel(lease);
      }
      expect(restore.cancelCount, 100);
      expect(restore.releasedStates, 100);
      expect(restore.liveStates, 0);
      expect(restore.attachedToTimeline, isFalse);
      expect(restore.originalOverwritten, isFalse);
      expect(restore.originalDeleted, isFalse);
      expect(restore.originalEditable, isTrue);
      expect(() => restore.useState(leases.first), code('STATE_RELEASED'));
      expect(() => restore.useState(leases.last), code('STATE_RELEASED'));
      expect(
        () => restore.recreateStateEveryFrame(),
        code('UNSUPPORTED_EDIT_TECHNIQUE'),
      );
    },
  );

  test('changing preprocess invalidates the ASR cache but does not rewrite locked captions; V-010 is required to auto-accept', () {
    final restore = session();
    expect(restore.asrCacheValid, isTrue);
    expect(restore.lockedCaptions.single.text, 'keep this line');
    restore.changePreprocess();
    expect(restore.asrCacheValid, isFalse);
    expect(restore.asrCacheGeneration, 1);
    expect(restore.lockedCaptions.single.id, 'cue.locked.1');
    expect(restore.lockedCaptions.single.text, 'keep this line');
    expect(
      () => restore.overwriteLockedCaption('cue.locked.1', 'rewritten'),
      code('FIELD_LOCKED'),
    );
    expect(restore.lockedCaptions.single.text, 'keep this line');
    expect(restore.v010Met, isFalse);
    expect(() => restore.autoAcceptRestore(), code('V010_GATE_UNMET'));
    expect(
      () => restore.fillWithoutQualifiedPack(),
      code('MODEL_ABI_UNVERIFIED'),
    );
    expect(
      () => restore.treatVadAsWordConfidence(),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );

    final chunks = [
      for (var i = 0; i < 4; i++) OlaChunk(index: i, present: true),
    ];
    restore.admitOla(
      sourceSampleCount: 44100,
      outputSampleCount: 44100,
      chunks: chunks,
    );
    expect(
      () => restore.admitOla(
        sourceSampleCount: 44100,
        outputSampleCount: 44000,
        chunks: chunks,
      ),
      code('CROSSFADE_SHORTENS'),
    );
    expect(
      () => restore.admitOla(
        sourceSampleCount: 44100,
        outputSampleCount: 44100,
        chunks: [OlaChunk(index: 0, present: false)],
      ),
      code('OLA_CHUNK_MISSING'),
    );
    expect(
      () => restore.admitOla(
        sourceSampleCount: 44100,
        outputSampleCount: 44100,
        chunks: [OlaChunk(index: 0, present: true, hasNan: true)],
      ),
      code('OLA_NAN_OUTPUT'),
    );
    expect(
      () => restore.admitOla(
        sourceSampleCount: 44100,
        outputSampleCount: 44100,
        chunks: [OlaChunk(index: 0, present: true, clipped: true)],
      ),
      code('OLA_CLIP'),
    );
    expect(
      () => restore.admitOla(
        sourceSampleCount: 44100,
        outputSampleCount: 44100,
        chunks: [OlaChunk(index: 0, present: true, boundaryWeight: 0)],
      ),
      code('OLA_ZERO_BOUNDARY_WEIGHT'),
    );
    expect(
      () => restore.admitOla(
        sourceSampleCount: 44100,
        outputSampleCount: 44100,
        chunks: chunks,
        doubleCompensateLatency: true,
      ),
      code('DOUBLE_LATENCY_COMPENSATION'),
    );
    expect(restore.rnnoiseEngineInvented, isFalse);
    expect(restore.stemEngineInvented, isFalse);
    expect(restore.v010Claimed, isFalse);
    expect(restore.v009Claimed, isFalse);
    expect(restore.limiterInvented, isFalse);
    expect(restore.paidApiCalled, isFalse);
    expect(restore.submitted, isFalse);
  });
}
