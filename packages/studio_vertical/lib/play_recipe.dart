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

/// s8l hug@1.0.0 slot/route compiler. Auto-segmentation and paid
/// generation are not invented. miniature / animalHumanized /
/// babyDance library entries are not opened here.
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
