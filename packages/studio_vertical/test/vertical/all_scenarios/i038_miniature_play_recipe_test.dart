import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_vertical/studio_vertical.dart';
import 'package:test/test.dart';

/// Increment 2.44 official I-038 leftover miniature@1.0.0 PlayRecipe
/// slot/scale refusals at the already-specified s8l bound. This file
/// does not invent auto-segmentation, geometric calibration, or paid
/// generation, does not open animalHumanized or babyDance library
/// entries, does not invent a PlanGraph manual-lock API, does not
/// mark I-037 complete, and does not rewrite the Increment 2.42 /
/// 2.43 suites or the frozen I-036 fts5Enabled==false assertions.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

MiniatureRequest official({
  String? subjectId = 'src-subject',
  String? referenceObjectId = 'src-cup',
  double scaleIntent = miniatureExampleScale,
  bool layeredAssets = true,
  bool deterministicComposite = true,
  bool requestAutoSegmentation = false,
  bool requestGeometricCalibration = false,
  bool requirePreciseScale = false,
  bool requirePreciseOcclusion = false,
  bool claimActualProductScale = false,
  String? lockedStance,
  bool lockedHandMask = false,
  String? subjectRegion,
  String? referenceRegion,
}) => MiniatureRequest(
  subjectId: subjectId,
  referenceObjectId: referenceObjectId,
  scaleIntent: scaleIntent,
  subjectIdentity: miniatureSubjectIdentity,
  referenceIdentity: miniatureReferenceIdentity,
  action: miniatureExampleAction,
  layeredAssets: layeredAssets,
  deterministicComposite: deterministicComposite,
  requestAutoSegmentation: requestAutoSegmentation,
  requestGeometricCalibration: requestGeometricCalibration,
  requirePreciseScale: requirePreciseScale,
  requirePreciseOcclusion: requirePreciseOcclusion,
  claimActualProductScale: claimActualProductScale,
  lockedStance: lockedStance,
  lockedHandMask: lockedHandMask,
  subjectRegion: subjectRegion,
  referenceRegion: referenceRegion,
);

void main() {
  test('miniature 1:20 contact compiles the official soft-intent golden, keeps locked stance and mask, and does not claim geometric calibration or submit', () {
    final compiler = PlayRecipeCompiler();
    final shot = compiler.compileMiniature(
      official(lockedStance: '杯把前方站位', lockedHandMask: true),
    );
    expect(shot.prompt, miniatureContactPrompt);
    expect(shot.recipeId, 'miniature@1.0.0');
    expect(shot.route, 'i2v');
    expect(shot.scaleIntent, miniatureExampleScale);
    expect(shot.scaleClaimsGeometricCalibration, isFalse);
    expect(shot.preciseOcclusionClaimed, isFalse);
    expect(shot.lockedStance, '杯把前方站位');
    expect(shot.lockedHandMask, isTrue);
    expect(shot.submitted, isFalse);
    expect(shot.documentWrites, 0);
    expect(compiler.documentWrites, 0);
    expect(shot.prompt.contains('真实3D'), isFalse);
  });

  test('missing refs, a same image without explicit regions, and a scale outside 0.005..0.2 are SLOT_COUNT and do not submit', () {
    final compiler = PlayRecipeCompiler();
    expect(
      () => compiler.compileMiniature(official(subjectId: null)),
      code(slotCount),
    );
    expect(
      () => compiler.compileMiniature(official(referenceObjectId: null)),
      code(slotCount),
    );
    expect(
      () => compiler.compileMiniature(
        official(subjectId: 'src-shared', referenceObjectId: 'src-shared'),
      ),
      code(slotCount),
    );
    final same = compiler.compileMiniature(
      official(
        subjectId: 'src-shared',
        referenceObjectId: 'src-shared',
        subjectRegion: 'region-figure',
        referenceRegion: 'region-cup',
      ),
    );
    expect(same.submitted, isFalse);
    expect(same.scaleClaimsGeometricCalibration, isFalse);
    expect(
      () => compiler.compileMiniature(official(scaleIntent: 0.004)),
      code(slotCount),
    );
    expect(
      () => compiler.compileMiniature(official(scaleIntent: 0.21)),
      code(slotCount),
    );
    expect(compiler.documentWrites, 0);
  });

  test('auto-segmentation, geometric calibration, precise scale or occlusion without layered deterministic composite, and actual product-size claims are refused', () {
    final compiler = PlayRecipeCompiler();
    expect(
      () => compiler.compileMiniature(official(requestAutoSegmentation: true)),
      code(capabilityUnsupported),
    );
    expect(
      () => compiler.compileMiniature(
        official(requestGeometricCalibration: true),
      ),
      code(capabilityUnsupported),
    );
    expect(
      () => compiler.compileMiniature(
        official(
          layeredAssets: false,
          deterministicComposite: false,
          requirePreciseScale: true,
        ),
      ),
      code(capabilityUnsupported),
    );
    expect(
      () => compiler.compileMiniature(
        official(layeredAssets: false, requirePreciseOcclusion: true),
      ),
      code(capabilityUnsupported),
    );
    expect(
      () => compiler.compileMiniature(official(claimActualProductScale: true)),
      code(capabilityUnsupported),
    );
    final fantasy = compiler.compileMiniature(
      official(layeredAssets: false, deterministicComposite: false),
    );
    expect(fantasy.artisticFantasy, isTrue);
    expect(fantasy.preciseOcclusionClaimed, isFalse);
    expect(fantasy.scaleClaimsGeometricCalibration, isFalse);
    expect(fantasy.submitted, isFalse);
    expect(compiler.documentWrites, 0);
  });
}
