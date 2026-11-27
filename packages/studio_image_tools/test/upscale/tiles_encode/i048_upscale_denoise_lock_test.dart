import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_image_tools/studio_image_tools.dart';
import 'package:test/test.dart';

/// Increment 2.68 official first I-048 slice: explicit native
/// scale and output preset, OS-pause resume, watermark/text
/// warnings retained, no full-film residency, failed frames not
/// auto-applied, and no auto-accept without V-013. This file does
/// not invent a real SR/denoise runtime, does not claim V-013,
/// does not treat generated detail as fact, does not rewrite
/// I-026, I-024, I-047, or I-046 official tests, does not invent
/// a limiter or a real RNNoise/stem engine, does not start I-049,
/// I-061, I-055, or I-035, and does not mark I-037, I-038, V-007,
/// V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, I-057,
/// I-052, I-039, V-026, I-043, I-044, I-045, or I-047 complete.
/// InversePatch kind stays restoreSnapshot. Project user_version
/// stays 9. V-013 stays blocked.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

const sourceHash =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

RestoreImageJob job() => RestoreImageJob(sourceHash: sourceHash);

void main() {
  test('native scale and output preset stay explicit; generated detail is not fact; OOM does not silently change the model', () {
    final enhance = job();
    final preview = enhance.preview();
    expect(preview.nativeScale, 4);
    expect(preview.outputPreset, 'realesrganX4plus');
    expect(preview.coreTile, 256);
    expect(preview.halo, 32);
    expect(preview.generatedDetailIsFact, isFalse);
    expect(preview.autoAccepted, isFalse);
    expect(preview.sourceHash, sourceHash);
    expect(
      () => enhance.claimScaleIsRecoveredFact(),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    final delivered = enhance.deliverDownsampledX2();
    expect(delivered.nativeScale, 4);
    expect(delivered.outputPreset, 'deliveryX2FromX4');
    expect(delivered.generatedDetailIsFact, isFalse);
    expect(
      () => enhance.relabelDownsampledX2AsNativeX2(),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    enhance.onOom(changeScale: false, changeModel: false, reducedCoreTile: 128);
    expect(enhance.coreTile, 128);
    expect(enhance.halo, 32);
    expect(enhance.nativeScale, 4);
    expect(enhance.outputPreset, 'realesrganX4plus');
    expect(
      () => enhance.onOom(changeScale: true, changeModel: false),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => enhance.onOom(changeScale: false, changeModel: true),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(() => enhance.feedBgrAsRgb(), code('UNSUPPORTED_EDIT_TECHNIQUE'));
    expect(() => enhance.swapToRealGan(), code('UNSUPPORTED_EDIT_TECHNIQUE'));
    expect(
      () => enhance.labelNlmeansAsAi(),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => enhance.addHqdn3dToLgplPack(),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => enhance.equateRnnoiseWithScunetOrSr(),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
  });

  test('an OS pause is resumable; the full film is not held in RAM; an image pass does not license video', () {
    final enhance = job();
    enhance.pauseForOs();
    expect(enhance.disposition, EnhanceDisposition.paused);
    final resumed = enhance.resumeAfterOs();
    expect(resumed.disposition, EnhanceDisposition.resumed);
    expect(resumed.sourceHash, sourceHash);
    expect(resumed.nativeScale, 4);
    expect(resumed.autoAccepted, isFalse);
    expect(resumed.fullFilmResident, isFalse);
    expect(() => enhance.loadFullFilmIntoRam(), code('FULL_FILM_RESIDENT'));
    expect(enhance.fullFilmResident, isFalse);
    expect(
      () => enhance.releaseVideoByImageQualification(),
      code('VIDEO_GATE_INDEPENDENT'),
    );
    expect(() => enhance.autoAddFps(), code('UNSUPPORTED_EDIT_TECHNIQUE'));
    expect(
      () => enhance.claimInverseTonemapRestoresHdr(),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(enhance.autoAddedFps, isFalse);
  });

  test('watermark and text warnings are kept; failed frames and unmet V-013 cannot auto-accept', () {
    final enhance = job();
    final preview = enhance.preview();
    expect(preview.warnings, isNotEmpty);
    expect(preview.warnings.single.id, 'watermark.logo');
    expect(
      () => enhance.dropWatermarkWarning(),
      code('WATERMARK_WARNING_REQUIRED'),
    );
    expect(
      () => enhance.replaceProtectedTextWithoutWarning(),
      code('WATERMARK_WARNING_REQUIRED'),
    );
    expect(
      enhance.preview().warnings.single.message,
      contains('logo and text'),
    );
    expect(() => enhance.removeCopyrightWatermark(), code('RIGHTS_FORBIDDEN'));
    expect(enhance.failedFrames, [7]);
    expect(
      () => enhance.autoApplyFailedFrame(),
      code('FAILED_FRAME_NOT_AUTO_APPLIED'),
    );
    expect(enhance.v013Met, isFalse);
    expect(() => enhance.autoAccept(), code('V013_GATE_UNMET'));
    expect(
      () => enhance.fillWithoutQualifiedPack(),
      code('MODEL_ABI_UNVERIFIED'),
    );
    expect(enhance.srEngineInvented, isFalse);
    expect(enhance.denoiseEngineInvented, isFalse);
    expect(enhance.v013Claimed, isFalse);
    expect(enhance.generatedDetailIsFact, isFalse);
    expect(enhance.paidApiCalled, isFalse);
    expect(enhance.submitted, isFalse);
  });
}
