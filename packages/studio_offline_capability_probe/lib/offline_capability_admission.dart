import 'package:studio_contracts/studio_contracts.dart';

const offlineCapabilityKinds = {'offlineCapability'};

final class OfflineCapabilityRequest {
  const OfflineCapabilityRequest({
    required this.kind,
    this.disguisesPresetScriptAsLlm = false,
    this.modelMissingBlocksManualEdit = false,
    this.offlineCloudVideoUndisclosed = false,
    this.pretendsTextModelGeneratesVideo = false,
  });

  /// `offlineCapability`.
  final String kind;

  /// True when a preset script is presented as a real LLM.
  final bool disguisesPresetScriptAsLlm;

  /// True when a missing model blocks manual editing.
  final bool modelMissingBlocksManualEdit;

  /// True when offline mode does not clearly show that cloud
  /// video generation is unsupported.
  final bool offlineCloudVideoUndisclosed;

  /// True when a text model is pretended to generate video.
  final bool pretendsTextModelGeneratesVideo;
}

final class OfflineCapabilityReceipt {
  const OfflineCapabilityReceipt({
    required this.admitted,
    required this.presetScriptDisguisedAsLlm,
    required this.manualEditBlocked,
    required this.cloudVideoDisclosedUnavailable,
    required this.textModelClaimedAsVideo,
  });

  final bool admitted;
  final bool presetScriptDisguisedAsLlm;
  final bool manualEditBlocked;
  final bool cloudVideoDisclosedUnavailable;
  final bool textModelClaimedAsVideo;
}

/// DEV-PURE s10 admission: a preset script must not be disguised
/// as a real LLM; if a model is not installed, manual editing
/// must still be possible; offline mode must clearly show that
/// cloud video generation is unsupported; and a 1.7B text model
/// must not be pretended to generate video.
///
/// This does not invent a real LLM or video-generation runtime,
/// and does not re-qualify Increment 3.37 ModelContextAdmission,
/// I-030 StreamAssembler, Increment 3.00 GeneratedOutputAdmission,
/// or Increment 2.57 VideoGenerationProvider. Quote/apply and
/// paid APIs are not started. V-019 is not claimed.
final class OfflineCapabilityAdmission {
  bool realLlmInvented = false;
  bool videoGenerationInvented = false;
  bool modelContextRequalified = false;
  bool streamAssemblerRequalified = false;
  bool generatedOutputRequalified = false;
  bool videoProviderRequalified = false;
  bool i034HandoffClaimed = false;
  bool v019Claimed = false;
  bool quoteApplyStarted = false;
  bool paidApiCalled = false;
  bool executableScriptPathInvented = false;

  OfflineCapabilityReceipt admit(OfflineCapabilityRequest request) {
    if (!offlineCapabilityKinds.contains(request.kind)) {
      throw const StudioException(
        'OFFLINE_CAPABILITY_KIND_UNKNOWN',
        'validator',
      );
    }
    if (request.disguisesPresetScriptAsLlm) {
      throw const StudioException('PRESET_SCRIPT_NOT_LLM', 'validator');
    }
    if (request.modelMissingBlocksManualEdit) {
      throw const StudioException(
        'MODEL_MISSING_BLOCKS_MANUAL_EDIT',
        'validator',
      );
    }
    if (request.offlineCloudVideoUndisclosed) {
      throw const StudioException(
        'OFFLINE_CLOUD_VIDEO_UNDISCLOSED',
        'validator',
      );
    }
    if (request.pretendsTextModelGeneratesVideo) {
      throw const StudioException('TEXT_MODEL_NOT_VIDEO', 'validator');
    }
    return const OfflineCapabilityReceipt(
      admitted: true,
      presetScriptDisguisedAsLlm: false,
      manualEditBlocked: false,
      cloudVideoDisclosedUnavailable: true,
      textModelClaimedAsVideo: false,
    );
  }
}
