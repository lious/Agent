import 'package:studio_contracts/studio_contracts.dart';

import 'vertical_brief.dart';
import 'workflow_compiler.dart';

/// s8l PlayRecipe is a Harness SkillPackage content subtype. This is
/// not a new executor, not signed-pack import, and not FTS recall.
const playRecipeContentType = 'playRecipe';
const hugRecipeId = 'hug';
const hugRecipeVersion = '1.0.0';
const hugTwoImagesTemplate = 'play.hug.two-images@1.0.0';

/// Official s8l two-images filled-slot golden, two fictional adults.
const hugLanIdentity = '蓝外套短发岚';
const hugHeIdentity = '米色开衫卷发禾';
const hugTwoImagesPrompt =
    'Image 1所示蓝外套短发岚在画面左侧，Image 2所示米色开衫卷发禾在右侧。\n'
    '两人向对方靠近并轻轻侧拥，中景，固定机位，柔和室内侧光。\n'
    '保持各自服装与面部区别，动作轻缓，避免复杂转身；这是合成互动。';

/// s8l required on-screen disclosure. This is not a real meeting.
const hugDisclaimer = 'AI合成互动，不表示人物真实相遇';
const hugOverlayText = 'AI合成互动';

enum HugVariant { onePersonImaginedPartner, twoPeoplePhoto, twoImages }

/// DEV-PURE hug subject. This is not a live I-036 cloud rights check
/// and not an I-004 asset attach.
final class HugSubject {
  HugSubject({
    required this.id,
    required this.identity,
    required this.fictional,
    required this.portraitConsent,
    this.isMinor = false,
    this.providerChildPolicyVerified = false,
    this.filename = '',
    this.peopleInImage = 1,
    this.hasImage = true,
  }) {
    requireId(id);
    if (peopleInImage < 1) {
      throw const StudioException(slotCount, 'peopleInImage');
    }
  }

  final String id, identity, filename;
  final bool fictional, portraitConsent, isMinor, providerChildPolicyVerified;
  final int peopleInImage;
  final bool hasImage;
}

/// s8l hug@1.0.0 request. leftSubjectId/rightSubjectId are stable and
/// are not reordered by filename.
final class HugRequest {
  HugRequest({
    required this.variant,
    required this.leftSubjectId,
    required this.rightSubjectId,
    required this.subjects,
    this.requestAutoSegmentation = false,
    this.lockedDisclaimer,
  }) {
    requireId(leftSubjectId);
    requireId(rightSubjectId);
    if (leftSubjectId == rightSubjectId) {
      throw const StudioException(subjectOrderUnresolved, 'subjects');
    }
  }

  final HugVariant variant;
  final String leftSubjectId, rightSubjectId;
  final List<HugSubject> subjects;
  final bool requestAutoSegmentation;
  final String? lockedDisclaimer;
}

/// s8l PlayRecipe compiler. Auto-segmentation, geometric
/// calibration, motion capture, and paid generation are not invented.
/// A babyDance library entry is not opened here.
final class PlayRecipeCompiler {
  int documentWrites = 0;

  CompiledShot compileHug(HugRequest request) {
    if (request.requestAutoSegmentation) {
      throw const StudioException(capabilityUnsupported, 'autoSegmentation');
    }
    final byId = {for (final s in request.subjects) s.id: s};
    final left = byId[request.leftSubjectId];
    final right = byId[request.rightSubjectId];
    if (left == null || right == null) {
      throw const StudioException(subjectOrderUnresolved, 'subjects');
    }
    for (final subject in [left, right]) {
      if (subject.isMinor && !subject.providerChildPolicyVerified) {
        throw StudioException(providerChildPolicyUnverified, subject.id);
      }
    }

    switch (request.variant) {
      case HugVariant.twoImages:
        _refuseTwoImages(left, right);
      case HugVariant.twoPeoplePhoto:
        _refuseTwoPeoplePhoto(left, right);
      case HugVariant.onePersonImaginedPartner:
        _refuseImaginedPartner(left, right);
    }

    final disclaimer = request.lockedDisclaimer ?? hugDisclaimer;
    final officialTwoImages =
        request.variant == HugVariant.twoImages &&
        left.identity == hugLanIdentity &&
        right.identity == hugHeIdentity;
    final prompt = officialTwoImages
        ? hugTwoImagesPrompt
        : _promptFor(request.variant, left, right);
    final route = switch (request.variant) {
      HugVariant.twoImages => 'r2v',
      HugVariant.twoPeoplePhoto => 'i2v',
      HugVariant.onePersonImaginedPartner => 'onePersonImaginedPartner',
    };
    documentWrites = 0;
    return CompiledShot(
      briefId: 'hug-${request.variant.name}',
      prompt: prompt,
      unsupportedFields: const [],
      requestedParameters: const {},
      seed: null,
      recipeId: '$hugRecipeId@$hugRecipeVersion',
      route: route,
      leftSubjectId: left.id,
      rightSubjectId: right.id,
      disclaimer: disclaimer,
      overlayText: hugOverlayText,
    );
  }

  /// s8l miniature@1.0.0. Scale is a creative soft intent, not real
  /// geometric calibration. Precise pixel scale requires layered
  /// assets and deterministic compositing. Auto-segmentation is not
  /// invented.
  CompiledShot compileMiniature(MiniatureRequest request) {
    if (request.requestAutoSegmentation) {
      throw const StudioException(capabilityUnsupported, 'autoSegmentation');
    }
    if (request.requestGeometricCalibration ||
        request.claimActualProductScale) {
      throw const StudioException(
        capabilityUnsupported,
        'geometricCalibration',
      );
    }
    if (request.requirePreciseScale &&
        !(request.layeredAssets && request.deterministicComposite)) {
      throw const StudioException(capabilityUnsupported, 'preciseScale');
    }
    if (request.requirePreciseOcclusion && !request.layeredAssets) {
      throw const StudioException(capabilityUnsupported, 'preciseOcclusion');
    }
    if (request.subjectId == null || request.referenceObjectId == null) {
      throw const StudioException(slotCount, 'miniature.refs');
    }
    if (request.scaleIntent < miniatureScaleMin ||
        request.scaleIntent > miniatureScaleMax) {
      throw const StudioException(slotCount, 'scaleIntent');
    }
    if (request.subjectId == request.referenceObjectId &&
        (request.subjectRegion == null || request.referenceRegion == null)) {
      throw const StudioException(slotCount, 'regions');
    }

    final official =
        request.subjectIdentity == miniatureSubjectIdentity &&
        request.referenceIdentity == miniatureReferenceIdentity &&
        request.scaleIntent == miniatureExampleScale &&
        request.action == miniatureExampleAction;
    final artistic = !request.layeredAssets;
    documentWrites = 0;
    return CompiledShot(
      briefId: 'miniature-contact',
      prompt: official ? miniatureContactPrompt : _miniaturePrompt(request),
      unsupportedFields: const [],
      requestedParameters: const {},
      seed: null,
      recipeId: '$miniatureRecipeId@$miniatureRecipeVersion',
      route: request.route,
      scaleIntent: request.scaleIntent,
      scaleClaimsGeometricCalibration: false,
      preciseOcclusionClaimed: false,
      artisticFantasy: artistic,
      lockedStance: request.lockedStance,
      lockedHandMask: request.lockedHandMask,
    );
  }

  /// s8l animalHumanized@1.0.0. clothingOnly does not become an
  /// upright human body; uprightCartoon does not replace the species
  /// face with an adult human face. Animal image plus human motion is
  /// not reliable mocap. This is not paid generation.
  CompiledShot compileAnimalHumanized(AnimalHumanizedRequest request) {
    if (request.requestAutoSegmentation) {
      throw const StudioException(capabilityUnsupported, 'autoSegmentation');
    }
    if (request.requestMotionTransfer || request.claimReliableMocap) {
      throw const StudioException(capabilityUnsupported, 'motionCapture');
    }
    if (request.requestAdultHumanFace) {
      throw const StudioException(mediaCombination, 'adultHumanFace');
    }
    if (request.humanization == AnimalHumanization.clothingOnly &&
        request.forceUprightBody) {
      throw const StudioException(mediaCombination, 'clothingOnly.upright');
    }
    if (request.animalReferenceId == null ||
        request.species.isEmpty ||
        request.speciesIdentity.isEmpty ||
        request.wardrobe.isEmpty ||
        request.action.isEmpty) {
      throw const StudioException(slotCount, 'animalHumanized');
    }
    if (!request.hasImageLicense) {
      throw const StudioException(rightsRequired, 'imageLicense');
    }
    if (request.requestHumanVoice && !request.hasHumanVoiceAuthorization) {
      throw const StudioException(rightsRequired, 'humanVoice');
    }

    final action = _safeAnimalAction(request.action);
    final official =
        request.species == animalOrangeCatSpecies &&
        request.speciesIdentity == animalOrangeCatIdentity &&
        request.humanization == AnimalHumanization.uprightCartoon &&
        request.wardrobe == animalOrangeCatWardrobe &&
        action == animalOrangeCatAction;
    documentWrites = 0;
    return CompiledShot(
      briefId: 'animal-identity',
      prompt: official ? animalIdentityPrompt : _animalPrompt(request, action),
      unsupportedFields: const [],
      requestedParameters: const {},
      seed: null,
      recipeId: '$animalRecipeId@$animalRecipeVersion',
      route: request.route,
      humanization: request.humanization.name,
      safeAction: action,
      lockedExpressionCaption: request.lockedExpressionCaption,
      claimsRealAnimalActed: false,
      claimsReliableMocap: false,
      adultFaceReplaced: false,
    );
  }
}

void _requirePortrait(HugSubject subject) {
  if (!subject.portraitConsent) {
    throw StudioException(portraitConsentRequired, subject.id);
  }
}

void _refuseTwoImages(HugSubject left, HugSubject right) {
  if (!left.hasImage || !right.hasImage) {
    throw const StudioException(slotCount, 'twoImages');
  }
  // A single dual-person still cannot pretend to be two single-subject refs.
  if (left.peopleInImage != 1 || right.peopleInImage != 1) {
    throw const StudioException(mediaCombination, 'twoImages.singleSubject');
  }
  _requirePortrait(left);
  _requirePortrait(right);
}

void _refuseTwoPeoplePhoto(HugSubject left, HugSubject right) {
  // One group photo, two separately authorized people, I2V.
  if (!left.hasImage && !right.hasImage) {
    throw const StudioException(slotCount, 'twoPeoplePhoto');
  }
  _requirePortrait(left);
  _requirePortrait(right);
}

void _refuseImaginedPartner(HugSubject left, HugSubject right) {
  // One real (or authorized) single image + an explicit fictional partner.
  // A real stranger cannot be auto-paired.
  final images = [left, right].where((s) => s.hasImage).toList();
  if (images.length != 1) {
    throw const StudioException(slotCount, 'onePersonImaginedPartner');
  }
  final partner = left.hasImage ? right : left;
  if (!partner.fictional) {
    throw const StudioException(mediaCombination, 'realStranger');
  }
  _requirePortrait(images.single);
}

String _promptFor(HugVariant variant, HugSubject left, HugSubject right) {
  if (variant == HugVariant.onePersonImaginedPartner) {
    final photo = left.hasImage ? left : right;
    final partner = left.hasImage ? right : left;
    return '参考图所示${photo.identity}与明确指定的虚构伙伴${partner.identity}轻轻侧拥，'
        '中景，固定机位；这是合成互动，不假装第二张参考图存在。';
  }
  return 'Image 1所示${left.identity}在画面左侧，Image 2所示${right.identity}在右侧。\n'
      '两人向对方靠近并轻轻侧拥，中景，固定机位，柔和室内侧光。\n'
      '保持各自服装与面部区别，动作轻缓，避免复杂转身；这是合成互动。';
}

/// s8l miniature@1.0.0 relative scale intent bounds. The 1:20 example
/// is a creative soft constraint, not geometric calibration.
const miniatureRecipeId = 'miniature';
const miniatureRecipeVersion = '1.0.0';
const miniatureContactTemplate = 'play.miniature.contact@1.0.0';
const miniatureScaleMin = 0.005;
const miniatureScaleMax = 0.2;
const miniatureExampleScale = 0.05;

const miniatureSubjectIdentity = '穿黄色雨衣的虚构小人物';
const miniatureReferenceIdentity = '普通白瓷杯';
const miniatureExampleAction = '扶着杯把向上张望';

const miniatureContactPrompt =
    '穿黄色雨衣的虚构小人物以约1:20的幻想微缩比例置于普通白瓷杯旁，扶着杯把向上张望。\n'
    '从桌面低机位观察，保持杯把在人物前方的遮挡关系，手脚接触处有柔和阴影；\n'
    '窗光从左后方照入。不要把杯子变成建筑或修改杯把数量。';

/// DEV-PURE miniature request. This is not a 3D calibrator and not
/// an auto-segmentation or I-004 attach path.
final class MiniatureRequest {
  MiniatureRequest({
    required this.subjectId,
    required this.referenceObjectId,
    required this.scaleIntent,
    required this.subjectIdentity,
    required this.referenceIdentity,
    required this.action,
    this.subjectRegion,
    this.referenceRegion,
    this.route = 'i2v',
    this.layeredAssets = false,
    this.deterministicComposite = false,
    this.requestAutoSegmentation = false,
    this.requestGeometricCalibration = false,
    this.requirePreciseScale = false,
    this.requirePreciseOcclusion = false,
    this.claimActualProductScale = false,
    this.lockedStance,
    this.lockedHandMask = false,
  }) {
    if (subjectId != null) requireId(subjectId!);
    if (referenceObjectId != null) requireId(referenceObjectId!);
    if (subjectRegion != null) requireId(subjectRegion!);
    if (referenceRegion != null) requireId(referenceRegion!);
  }

  final String? subjectId, referenceObjectId, subjectRegion, referenceRegion;
  final double scaleIntent;
  final String subjectIdentity, referenceIdentity, action, route;
  final bool layeredAssets, deterministicComposite;
  final bool requestAutoSegmentation, requestGeometricCalibration;
  final bool requirePreciseScale, requirePreciseOcclusion;
  final bool claimActualProductScale, lockedHandMask;
  final String? lockedStance;
}

String _miniaturePrompt(MiniatureRequest request) {
  final ratio = request.scaleIntent == 0
      ? '0'
      : '1:${(1 / request.scaleIntent).round()}';
  return '${request.subjectIdentity}以约$ratio的幻想微缩比例置于'
      '${request.referenceIdentity}旁，${request.action}。'
      '比例只是模型意图，未作真实3D尺度保证。';
}

enum AnimalHumanization { clothingOnly, uprightCartoon }

const animalRecipeId = 'animalHumanized';
const animalRecipeVersion = '1.0.0';
const animalIdentityTemplate = 'play.animal.identity@1.0.0';

const animalOrangeCatSpecies = '橘猫';
const animalOrangeCatIdentity = '短鼻口、三角耳、橘色额纹与蓬松尾巴';
const animalOrangeCatWardrobe = '蓝色围裙';
const animalOrangeCatAction = '轻轻翻开一本无字绘本';
const animalSimpleFallbackAction = '挥爪';

const animalIdentityPrompt =
    '参考中的橘猫保留短鼻口、三角耳、橘色额纹与蓬松尾巴，拟人程度=卡通直立。\n'
    '穿蓝色围裙，在明亮书桌旁轻轻翻开一本无字绘本；固定中景、柔和正侧光。\n'
    '不要以人类面孔替代猫脸；这是虚构卡通行为。';

const _unsafeAnimalActions = {'复杂烹饪', '危险动作', '跳高', '驾驶'};

/// DEV-PURE animal-humanization request. This is not motion capture,
/// auto-segmentation, or a paid generator.
final class AnimalHumanizedRequest {
  AnimalHumanizedRequest({
    required this.animalReferenceId,
    required this.species,
    required this.speciesIdentity,
    required this.humanization,
    required this.wardrobe,
    required this.action,
    this.setting = '明亮书桌旁',
    this.cameraLight = '固定中景、柔和正侧光',
    this.route = 'i2v',
    this.hasImageLicense = false,
    this.requestHumanVoice = false,
    this.hasHumanVoiceAuthorization = false,
    this.requestMotionTransfer = false,
    this.claimReliableMocap = false,
    this.requestAdultHumanFace = false,
    this.forceUprightBody = false,
    this.requestAutoSegmentation = false,
    this.lockedExpressionCaption,
  }) {
    if (animalReferenceId != null) requireId(animalReferenceId!);
  }

  final String? animalReferenceId;
  final String species, speciesIdentity, wardrobe, action;
  final String setting, cameraLight, route;
  final AnimalHumanization humanization;
  final bool hasImageLicense,
      requestHumanVoice,
      hasHumanVoiceAuthorization,
      requestMotionTransfer,
      claimReliableMocap,
      requestAdultHumanFace,
      forceUprightBody,
      requestAutoSegmentation;
  final String? lockedExpressionCaption;
}

String _safeAnimalAction(String action) {
  if (_unsafeAnimalActions.contains(action)) return animalSimpleFallbackAction;
  return action;
}

String _animalPrompt(AnimalHumanizedRequest request, String action) {
  final degree = request.humanization == AnimalHumanization.uprightCartoon
      ? '卡通直立'
      : '仅服装';
  return '参考中的${request.species}保留${request.speciesIdentity}，拟人程度=$degree。\n'
      '穿${request.wardrobe}，在${request.setting}做$action；${request.cameraLight}。\n'
      '不要以人类面孔替代物种面部；这是虚构卡通行为。';
}
