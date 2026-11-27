import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_generated_layer_probe/studio_generated_layer_probe.dart';
import 'package:test/test.dart';

/// Increment 3.00 official I-040 / s4 leftover: generated model output
/// is only a raster or video candidate. A prompt must not turn an
/// object inside an existing MP4 into a real independently editable
/// layer. Canvas text, captions, and brand logo stay deterministic
/// layers.
///
/// This file does not invent an inpainting, tracking, or segmentation
/// engine, does not re-qualify Increment 2.57 VideoGenerationProvider
/// or I-043/I-044/I-045, and does not invent a WorkflowCoordinator or
/// start paid generation. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9. I-040 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a raster or video candidate is admitted; prompt-extracting an MP4 object into an editable layer is refused', () {
    final admission = GeneratedOutputAdmission();
    final raster = admission.admit(
      const GeneratedOutputRequest(kind: 'raster'),
    );
    expect(raster.candidateKind, 'raster');
    expect(raster.editableObjectLayer, isFalse);
    final video = admission.admit(const GeneratedOutputRequest(kind: 'video'));
    expect(video.candidateKind, 'video');
    expect(
      () => admission.admit(
        const GeneratedOutputRequest(
          kind: 'video',
          promptExtractsMp4ObjectToEditableLayer: true,
        ),
      ),
      code('PROMPT_OBJECT_LAYER_FORBIDDEN'),
    );
  });

  test('non-candidate generated output is refused; deterministic text, caption, and logo layers are not replaced', () {
    final admission = GeneratedOutputAdmission();
    expect(
      () =>
          admission.admit(const GeneratedOutputRequest(kind: 'editableLayer')),
      code('GENERATED_OUTPUT_NOT_CANDIDATE'),
    );
    expect(
      () => admission.admit(
        const GeneratedOutputRequest(
          kind: 'raster',
          replacesDeterministicLayer: true,
        ),
      ),
      code('DETERMINISTIC_LAYER_REQUIRED'),
    );
  });

  test('an inpainting, tracking, or segmentation runtime, I-040 provider re-qualification, and paid generation stay closed', () {
    final admission = GeneratedOutputAdmission();
    expect(admission.inpaintingInvented, isFalse);
    expect(admission.trackerInvented, isFalse);
    expect(admission.autoSegmentationInvented, isFalse);
    expect(admission.opticalFlowInvented, isFalse);
    expect(admission.i043Requalified, isFalse);
    expect(admission.i044Requalified, isFalse);
    expect(admission.i045Requalified, isFalse);
    expect(admission.i040ProviderRequalified, isFalse);
    expect(admission.workflowCoordinatorInvented, isFalse);
    expect(admission.paidGenerationStarted, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
