import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_vertical/studio_vertical.dart';
import 'package:test/test.dart';

/// Increment 2.45 official I-038 leftover animalHumanized@1.0.0
/// PlayRecipe slot/identity refusals at the already-specified s8l
/// bound. This file does not invent motion capture, geometric
/// calibration, auto-segmentation, or paid generation, does not open
/// a babyDance library entry, does not invent a PlanGraph
/// manual-lock API, does not mark I-037 complete, and does not
/// rewrite the Increment 2.42 / 2.43 / 2.44 suites or the frozen
/// I-036 fts5Enabled==false assertions.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

AnimalHumanizedRequest official({
  String? animalReferenceId = 'src-orange-cat',
  String species = animalOrangeCatSpecies,
  String speciesIdentity = animalOrangeCatIdentity,
  AnimalHumanization humanization = AnimalHumanization.uprightCartoon,
  String wardrobe = animalOrangeCatWardrobe,
  String action = animalOrangeCatAction,
  bool hasImageLicense = true,
  bool requestHumanVoice = false,
  bool hasHumanVoiceAuthorization = false,
  bool requestMotionTransfer = false,
  bool claimReliableMocap = false,
  bool requestAdultHumanFace = false,
  bool forceUprightBody = false,
  bool requestAutoSegmentation = false,
  String? lockedExpressionCaption,
}) => AnimalHumanizedRequest(
  animalReferenceId: animalReferenceId,
  species: species,
  speciesIdentity: speciesIdentity,
  humanization: humanization,
  wardrobe: wardrobe,
  action: action,
  hasImageLicense: hasImageLicense,
  requestHumanVoice: requestHumanVoice,
  hasHumanVoiceAuthorization: hasHumanVoiceAuthorization,
  requestMotionTransfer: requestMotionTransfer,
  claimReliableMocap: claimReliableMocap,
  requestAdultHumanFace: requestAdultHumanFace,
  forceUprightBody: forceUprightBody,
  requestAutoSegmentation: requestAutoSegmentation,
  lockedExpressionCaption: lockedExpressionCaption,
);

void main() {
  test('animalHumanized official orange-cat uprightCartoon compiles the identity golden, keeps a locked caption, and does not replace the face, claim mocap, or submit', () {
    final compiler = PlayRecipeCompiler();
    final shot = compiler.compileAnimalHumanized(
      official(lockedExpressionCaption: '已锁表情字幕'),
    );
    expect(shot.prompt, animalIdentityPrompt);
    expect(shot.recipeId, 'animalHumanized@1.0.0');
    expect(shot.route, 'i2v');
    expect(shot.humanization, 'uprightCartoon');
    expect(shot.safeAction, animalOrangeCatAction);
    expect(shot.lockedExpressionCaption, '已锁表情字幕');
    expect(shot.adultFaceReplaced, isFalse);
    expect(shot.claimsReliableMocap, isFalse);
    expect(shot.claimsRealAnimalActed, isFalse);
    expect(shot.submitted, isFalse);
    expect(shot.documentWrites, 0);
    expect(compiler.documentWrites, 0);
  });

  test('missing animal ref or required slots, missing image license, and clothingOnly forced upright are refused; clothingOnly does not become an upright body', () {
    final compiler = PlayRecipeCompiler();
    expect(
      () => compiler.compileAnimalHumanized(official(animalReferenceId: null)),
      code(slotCount),
    );
    expect(
      () => compiler.compileAnimalHumanized(official(species: '')),
      code(slotCount),
    );
    expect(
      () => compiler.compileAnimalHumanized(official(speciesIdentity: '')),
      code(slotCount),
    );
    expect(
      () => compiler.compileAnimalHumanized(official(wardrobe: '')),
      code(slotCount),
    );
    expect(
      () => compiler.compileAnimalHumanized(official(action: '')),
      code(slotCount),
    );
    expect(
      () => compiler.compileAnimalHumanized(official(hasImageLicense: false)),
      code(rightsRequired),
    );
    expect(
      () => compiler.compileAnimalHumanized(
        official(
          humanization: AnimalHumanization.clothingOnly,
          forceUprightBody: true,
        ),
      ),
      code(mediaCombination),
    );
    final clothing = compiler.compileAnimalHumanized(
      official(humanization: AnimalHumanization.clothingOnly),
    );
    expect(clothing.humanization, 'clothingOnly');
    expect(clothing.humanization, isNot('uprightCartoon'));
    expect(clothing.adultFaceReplaced, isFalse);
    expect(clothing.submitted, isFalse);
    expect(compiler.documentWrites, 0);
  });

  test('adult human face, motion-transfer mocap, unlicensed human voice, and auto-segmentation are refused; a dangerous action is downgraded and does not claim the real animal acted', () {
    final compiler = PlayRecipeCompiler();
    expect(
      () => compiler.compileAnimalHumanized(
        official(requestAdultHumanFace: true),
      ),
      code(mediaCombination),
    );
    expect(
      () => compiler.compileAnimalHumanized(
        official(requestMotionTransfer: true),
      ),
      code(capabilityUnsupported),
    );
    expect(
      () => compiler.compileAnimalHumanized(official(claimReliableMocap: true)),
      code(capabilityUnsupported),
    );
    expect(
      () => compiler.compileAnimalHumanized(
        official(requestHumanVoice: true, hasHumanVoiceAuthorization: false),
      ),
      code(rightsRequired),
    );
    expect(
      () => compiler.compileAnimalHumanized(
        official(requestAutoSegmentation: true),
      ),
      code(capabilityUnsupported),
    );
    final downgraded = compiler.compileAnimalHumanized(
      official(action: '复杂烹饪'),
    );
    expect(downgraded.safeAction, animalSimpleFallbackAction);
    expect(downgraded.safeAction, isNot('复杂烹饪'));
    expect(downgraded.claimsRealAnimalActed, isFalse);
    expect(downgraded.claimsReliableMocap, isFalse);
    expect(downgraded.prompt.contains('复杂烹饪'), isFalse);
    expect(downgraded.prompt.contains('虚构卡通行为'), isTrue);
    expect(downgraded.submitted, isFalse);
    expect(compiler.documentWrites, 0);
  });
}
