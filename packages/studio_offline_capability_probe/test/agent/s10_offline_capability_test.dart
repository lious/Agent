import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_offline_capability_probe/studio_offline_capability_probe.dart';
import 'package:test/test.dart';

/// Increment 3.38 official s10 leftover: a preset script must not
/// be disguised as a real LLM; a missing model must not block
/// manual editing; offline mode must clearly show that cloud
/// video generation is unsupported; and a text model must not be
/// pretended to generate video.
///
/// This file does not invent a real LLM or video-generation
/// runtime, and does not re-qualify Increment 3.37
/// ModelContextAdmission, I-030 StreamAssembler, or Increment
/// 3.00 GeneratedOutputAdmission. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. This is not an
/// I-013 packing or archive slice, not an I-002 measurement
/// claim, and not a license, session-navigation, or model-context
/// leftover already officialized in 3.32, 3.35, 3.36, or 3.37.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a preset script must not be disguised as a real LLM, offline cloud video generation must be disclosed as unsupported, and a text model must not be pretended to generate video', () {
    final admission = OfflineCapabilityAdmission();
    final receipt = admission.admit(
      const OfflineCapabilityRequest(kind: 'offlineCapability'),
    );
    expect(receipt.admitted, isTrue);
    expect(receipt.presetScriptDisguisedAsLlm, isFalse);
    expect(receipt.manualEditBlocked, isFalse);
    expect(receipt.cloudVideoDisclosedUnavailable, isTrue);
    expect(receipt.textModelClaimedAsVideo, isFalse);

    expect(
      () => admission.admit(const OfflineCapabilityRequest(kind: 'unknown')),
      code('OFFLINE_CAPABILITY_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const OfflineCapabilityRequest(
          kind: 'offlineCapability',
          disguisesPresetScriptAsLlm: true,
        ),
      ),
      code('PRESET_SCRIPT_NOT_LLM'),
    );
    expect(
      () => admission.admit(
        const OfflineCapabilityRequest(
          kind: 'offlineCapability',
          modelMissingBlocksManualEdit: true,
        ),
      ),
      code('MODEL_MISSING_BLOCKS_MANUAL_EDIT'),
    );
    expect(
      () => admission.admit(
        const OfflineCapabilityRequest(
          kind: 'offlineCapability',
          offlineCloudVideoUndisclosed: true,
        ),
      ),
      code('OFFLINE_CLOUD_VIDEO_UNDISCLOSED'),
    );
    expect(
      () => admission.admit(
        const OfflineCapabilityRequest(
          kind: 'offlineCapability',
          pretendsTextModelGeneratesVideo: true,
        ),
      ),
      code('TEXT_MODEL_NOT_VIDEO'),
    );
  });

  test('a real LLM, video-generation runtime, ModelContextAdmission, StreamAssembler, and GeneratedOutputAdmission stay closed', () {
    final admission = OfflineCapabilityAdmission();
    expect(admission.realLlmInvented, isFalse);
    expect(admission.videoGenerationInvented, isFalse);
    expect(admission.modelContextRequalified, isFalse);
    expect(admission.streamAssemblerRequalified, isFalse);
    expect(admission.generatedOutputRequalified, isFalse);
    expect(admission.videoProviderRequalified, isFalse);
    expect(admission.i034HandoffClaimed, isFalse);
    expect(admission.v019Claimed, isFalse);
    expect(admission.quoteApplyStarted, isFalse);
    expect(admission.paidApiCalled, isFalse);
    expect(admission.executableScriptPathInvented, isFalse);
  });
}
