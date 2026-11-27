import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_video_tools/studio_video_tools.dart';
import 'package:test/test.dart';

/// Increment 2.66 official first I-045 slice: locked mask/caption
/// preservation, inferred-region marking, chunk resume, and no
/// auto-accept without V-012. This file does not invent a temporal
/// inpaint engine, does not claim V-012 or V-011, does not rewrite
/// I-044 MaskTrackService or I-043 EraseLayerSession, does not start
/// I-047/I-048, I-061, I-055, or I-035, and does not mark I-037,
/// I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053,
/// I-056, I-057, I-052, I-039, V-026, I-043, or I-044 complete.
/// InversePatch kind stays restoreSnapshot. Project user_version
/// stays 9. V-012 stays blocked.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

const originalHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

VideoEraseSession session() => VideoEraseSession(
  originalHash: originalHash,
  lockedMask: true,
  lockedCaption: true,
  lockedTrim: true,
);

void main() {
  test('locked mask, caption, and trim stay unchanged; the original and its audio are retained', () {
    final erase = session();
    final preview = erase.preview();
    expect(preview.lockedMaskUnchanged, isTrue);
    expect(preview.lockedCaptionUnchanged, isTrue);
    expect(preview.lockedTrimUnchanged, isTrue);
    expect(preview.originalHash, originalHash);
    expect(preview.originalAudioRetained, isTrue);
    expect(preview.autoAccepted, isFalse);
    expect(preview.userLayersWritten, 0);
    expect(() => erase.overwriteLockedMask(), code('MASK_LOCK_CONFLICT'));
    expect(() => erase.overwriteLockedCaption(), code('FIELD_LOCKED'));
    expect(() => erase.moveLockedTrim(), code('FIELD_LOCKED'));
    expect(erase.originalDeleted, isFalse);
    expect(erase.documentWrites, 0);
  });

  test('an interrupt resumes from the last valid chunk; inferred regions are marked and are not recovered facts', () {
    final erase = session();
    expect(erase.lastValidChunkIndex, 3);
    expect(erase.inferredRegionIndexes, [4, 5, 6, 7, 8, 9]);
    final resumed = erase.resumeAfterInterrupt();
    expect(resumed.resumedFromChunk, 3);
    expect(resumed.resumedFromChunk, isNot(0));
    expect(resumed.inferredRegionMarked, isTrue);
    expect(resumed.inferredBackgroundIsFact, isFalse);
    expect(resumed.autoAccepted, isFalse);
    expect(resumed.originalAudioRetained, isTrue);
    expect(erase.chunks, hasLength(10));
    erase.lateCancel();
    expect(erase.userLayersWritten, 0);
    expect(erase.originalDeleted, isFalse);
  });

  test('ten-segment temporal QA cannot auto-accept without V-012; frame-wise LaMa is not a stable temporal fill', () {
    final erase = session();
    expect(erase.v012Met, isFalse);
    expect(() => erase.autoAcceptTenSegments(), code('V012_GATE_UNMET'));
    expect(
      () => erase.claimFramewiseLamaStable(),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => erase.fillWithoutQualifiedPack(labelClassicAsTemporal: true),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => erase.fillWithoutQualifiedPack(),
      code('MODEL_ABI_UNVERIFIED'),
    );
    expect(
      () => erase.useNearStaticReconstruction(userConsent: false),
      code('APPROVAL_REQUIRED'),
    );
    expect(erase.temporalInpaintEngineInvented, isFalse);
    expect(erase.framewiseLamaClaimedStable, isFalse);
    expect(erase.v012Claimed, isFalse);
    expect(erase.v011Claimed, isFalse);
    expect(erase.submitted, isFalse);
    expect(erase.paidApiCalled, isFalse);
  });
}
