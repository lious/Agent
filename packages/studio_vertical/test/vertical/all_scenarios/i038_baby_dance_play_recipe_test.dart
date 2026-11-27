import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_vertical/studio_vertical.dart';
import 'package:test/test.dart';

/// Increment 2.46 official I-038 leftover babyDance@1.0.0 safety and
/// guardian refusals at the already-specified s8l bound. This file
/// implements only those official refusal bounds. It does not invent
/// motion capture, adult-motion retargeting, auto-segmentation, paid
/// generation, or any new child-related surface, imagery, or motion
/// path beyond the spec. It does not invent a PlanGraph manual-lock
/// API, does not mark I-037 complete, and does not rewrite the
/// Increment 2.42–2.45 suites or the frozen I-036
/// fts5Enabled==false assertions.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

BabyDanceRequest fictional({
  String? appearanceId = 'src-cartoon-figure',
  BabyDanceAction? action = BabyDanceAction.gentleSway,
  bool fullyClothed = true,
  bool hasImageLicense = true,
  bool requestAdultMotionRetarget = false,
  bool requestMotionCapture = false,
  bool claimFramePerfectDance = false,
  bool requestSexualizedAction = false,
  bool requestAdultSeductiveChoreography = false,
  bool requestDangerousTwistOrHighJump = false,
  bool requestAutoSegmentation = false,
  bool requestAutoPublish = false,
  bool hasMusic = false,
  bool musicLicensed = false,
  bool hasReferenceMotion = false,
  bool referenceMotionLicensed = false,
  bool rightsEpochRevoked = false,
  bool privateStatusLocked = false,
  String? lockedParentCaption,
}) => BabyDanceRequest(
  appearanceId: appearanceId,
  action: action,
  fullyClothed: fullyClothed,
  hasImageLicense: hasImageLicense,
  isRealChild: false,
  requestAdultMotionRetarget: requestAdultMotionRetarget,
  requestMotionCapture: requestMotionCapture,
  claimFramePerfectDance: claimFramePerfectDance,
  requestSexualizedAction: requestSexualizedAction,
  requestAdultSeductiveChoreography: requestAdultSeductiveChoreography,
  requestDangerousTwistOrHighJump: requestDangerousTwistOrHighJump,
  requestAutoSegmentation: requestAutoSegmentation,
  requestAutoPublish: requestAutoPublish,
  hasMusic: hasMusic,
  musicLicensed: musicLicensed,
  hasReferenceMotion: hasReferenceMotion,
  referenceMotionLicensed: referenceMotionLicensed,
  rightsEpochRevoked: rightsEpochRevoked,
  privateStatusLocked: privateStatusLocked,
  lockedParentCaption: lockedParentCaption,
);

BabyDanceRequest realChild({
  bool hasGuardianAuthorization = false,
  bool hasPortraitScope = false,
  bool minimalUpload = false,
  bool providerChildPolicyVerified = false,
}) => BabyDanceRequest(
  appearanceId: 'src-real-subject',
  action: BabyDanceAction.gentleSway,
  fullyClothed: true,
  hasImageLicense: true,
  isRealChild: true,
  hasGuardianAuthorization: hasGuardianAuthorization,
  hasPortraitScope: hasPortraitScope,
  minimalUpload: minimalUpload,
  providerChildPolicyVerified: providerChildPolicyVerified,
);

void main() {
  test('babyDance official fictional clothed-cartoon safe-sway compiles the golden, keeps locked parent caption and private status, and does not auto-publish, retarget, or submit', () {
    final compiler = PlayRecipeCompiler();
    final shot = compiler.compileBabyDance(
      fictional(lockedParentCaption: '已锁家长字幕', privateStatusLocked: true),
    );
    expect(shot.prompt, babyDanceSafeSwayPrompt);
    expect(shot.recipeId, 'babyDance@1.0.0');
    expect(shot.route, 'i2v');
    expect(shot.safeAction, 'gentleSway');
    expect(shot.lockedExpressionCaption, '已锁家长字幕');
    expect(shot.privateStatusLocked, isTrue);
    expect(shot.autoPublished, isFalse);
    expect(shot.framePerfectDanceClaimed, isFalse);
    expect(shot.adultMotionRetargeted, isFalse);
    expect(shot.submitted, isFalse);
    expect(shot.documentWrites, 0);
    expect(compiler.documentWrites, 0);
  });

  test('a real-child path without guardian or with unverified provider policy is refused and does not submit; missing slots and a revoked rights epoch are also refused', () {
    final compiler = PlayRecipeCompiler();
    expect(() => compiler.compileBabyDance(realChild()), code(rightsRequired));
    expect(
      () => compiler.compileBabyDance(
        realChild(
          hasGuardianAuthorization: true,
          hasPortraitScope: true,
          minimalUpload: true,
        ),
      ),
      code(providerChildPolicyUnverified),
    );
    expect(
      () => compiler.compileBabyDance(fictional(appearanceId: null)),
      code(slotCount),
    );
    expect(
      () => compiler.compileBabyDance(fictional(action: null)),
      code(slotCount),
    );
    expect(
      () => compiler.compileBabyDance(fictional(rightsEpochRevoked: true)),
      code(rightsRequired),
    );
    expect(compiler.documentWrites, 0);
  });

  test('adult-motion retargeting, mocap, auto-segmentation, unsafe choreography, and auto social publish are refused; a dangerous jump is reduced to gentle sway and still does not auto-publish or submit', () {
    final compiler = PlayRecipeCompiler();
    expect(
      () => compiler.compileBabyDance(
        fictional(requestAdultMotionRetarget: true),
      ),
      code(capabilityUnsupported),
    );
    expect(
      () => compiler.compileBabyDance(fictional(requestMotionCapture: true)),
      code(capabilityUnsupported),
    );
    expect(
      () => compiler.compileBabyDance(fictional(claimFramePerfectDance: true)),
      code(capabilityUnsupported),
    );
    expect(
      () => compiler.compileBabyDance(fictional(requestAutoSegmentation: true)),
      code(capabilityUnsupported),
    );
    expect(
      () => compiler.compileBabyDance(fictional(requestSexualizedAction: true)),
      code(mediaCombination),
    );
    expect(
      () => compiler.compileBabyDance(
        fictional(requestAdultSeductiveChoreography: true),
      ),
      code(mediaCombination),
    );
    expect(
      () => compiler.compileBabyDance(fictional(requestAutoPublish: true)),
      code(approvalRequired),
    );
    expect(
      () => compiler.compileBabyDance(fictional(fullyClothed: false)),
      code(mediaCombination),
    );
    final reduced = compiler.compileBabyDance(
      fictional(requestDangerousTwistOrHighJump: true),
    );
    expect(reduced.safeAction, 'gentleSway');
    expect(reduced.autoPublished, isFalse);
    expect(reduced.adultMotionRetargeted, isFalse);
    expect(reduced.framePerfectDanceClaimed, isFalse);
    expect(reduced.submitted, isFalse);
    expect(compiler.documentWrites, 0);
  });
}
