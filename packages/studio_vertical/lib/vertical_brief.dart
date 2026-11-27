import 'package:studio_contracts/studio_contracts.dart';

const verticalSchemaVersion = '1.0.0';

/// Official s8n compile/preflight codes. A compile error does not submit.
const unconfirmedFact = 'UNCONFIRMED_FACT';
const factExpired = 'FACT_EXPIRED';
const factSkuMismatch = 'FACT_SKU_MISMATCH';
const portraitConsentRequired = 'PORTRAIT_CONSENT_REQUIRED';
const capabilityUnsupported = 'CAPABILITY_UNSUPPORTED';
const overrideRebaseRequired = 'OVERRIDE_REBASE_REQUIRED';
const slotCount = 'SLOT_COUNT';
const generationDisabled = 'GENERATION_DISABLED';

/// s8h Purpose axis. Not mutually exclusive with input modes or recipes.
enum VerticalPurpose {
  marketing,
  showcase,
  story,
  social,
  tutorial,
  musicVisual,
}

/// s8h Input modes may be combined, e.g. story + script + i2v.
enum VerticalInputMode {
  text,
  script,
  mediaMontage,
  i2v,
  firstLast,
  nativeContinue,
  tailFrameBridge,
  referenceSynthesis,
  motionTransfer,
  videoRestyle,
}

enum VoiceMode { none, captions, uploadedAudio, nativeTrial }

enum SourceRole { front, detail, firstFrame, lastFrame, clip, image, script }

enum OverrideReviewState { unreviewed, confirmed }

final _hash = RegExp(r'^[a-f0-9]{64}$');

void requireHash(String value, [String path = 'hash']) {
  if (!_hash.hasMatch(value)) throw StudioException('INVALID_ID', path);
}

/// s8n SourceBinding used only for required front/detail and first/last
/// slots in this slice. This is not an I-004 AssetRepository.
final class SourceBinding {
  SourceBinding({required this.id, required this.role}) {
    requireId(id);
  }

  final String id;
  final SourceRole role;
}

/// s8n Override. A stale base template must rebase; it is not silently applied.
final class PromptOverride {
  PromptOverride({
    required this.baseTemplateHash,
    required this.text,
    this.reviewState = OverrideReviewState.unreviewed,
    this.reviewRef,
  }) {
    requireHash(baseTemplateHash, 'baseTemplateHash');
    if (text.length > 10000) {
      throw const StudioException('INVALID_ID', 'override.text');
    }
    if (reviewRef != null) requireId(reviewRef!);
  }

  final String baseTemplateHash, text;
  final OverrideReviewState reviewState;
  final String? reviewRef;
}

/// DEV-PURE portrait consent flag. This is not a live I-036 cloud check.
final class SubjectRights {
  SubjectRights({required this.subjectId, required this.portraitConsent}) {
    requireId(subjectId);
  }

  final String subjectId;
  final bool portraitConsent;
}

/// s8n VerticalBrief v1.0.0 subset used by the first I-038 compiler slice.
final class VerticalBrief {
  VerticalBrief({
    required this.id,
    required this.namespace,
    required this.purpose,
    required this.inputModes,
    this.productId,
    this.scriptBindingId,
    this.subjectIds = const [],
    this.factIds = const [],
    this.sourceBindings = const [],
    this.allowNewGeneration = false,
    this.voiceMode = VoiceMode.none,
    this.seed,
    this.requestedParameters = const {},
  }) {
    requireId(id);
    if (inputModes.isEmpty || inputModes.length > 10) {
      throw const StudioException(slotCount, 'inputModes');
    }
    if (inputModes.toSet().length != inputModes.length) {
      throw const StudioException('INVALID_ID', 'inputModes');
    }
    if (productId != null) requireId(productId!);
    if (scriptBindingId != null) requireId(scriptBindingId!);
    if (subjectIds.toSet().length != subjectIds.length) {
      throw const StudioException('INVALID_ID', 'subjectIds');
    }
    for (final id in [...subjectIds, ...factIds]) {
      requireId(id);
    }
    if (factIds.toSet().length != factIds.length) {
      throw const StudioException('INVALID_ID', 'factIds');
    }
  }

  final String id;
  final Namespace namespace;
  final VerticalPurpose purpose;
  final List<VerticalInputMode> inputModes;
  final String? productId, scriptBindingId;
  final List<String> subjectIds, factIds;
  final List<SourceBinding> sourceBindings;
  final bool allowNewGeneration;
  final VoiceMode voiceMode;
  final int? seed;
  final Map<String, Object?> requestedParameters;

  String get schemaVersion => verticalSchemaVersion;

  bool get requiresGeneration => inputModes.any(
    (m) =>
        m == VerticalInputMode.i2v ||
        m == VerticalInputMode.firstLast ||
        m == VerticalInputMode.nativeContinue ||
        m == VerticalInputMode.tailFrameBridge ||
        m == VerticalInputMode.referenceSynthesis ||
        m == VerticalInputMode.motionTransfer ||
        m == VerticalInputMode.videoRestyle,
  );
}
