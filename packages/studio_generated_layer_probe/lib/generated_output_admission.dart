import 'package:studio_contracts/studio_contracts.dart';

const generatedCandidateKinds = {'raster', 'video'};

final class GeneratedOutputRequest {
  const GeneratedOutputRequest({
    required this.kind,
    this.promptExtractsMp4ObjectToEditableLayer = false,
    this.replacesDeterministicLayer = false,
  });

  /// `raster` or `video` candidate, or some other claimed kind.
  final String kind;
  final bool promptExtractsMp4ObjectToEditableLayer, replacesDeterministicLayer;
}

final class GeneratedOutputReceipt {
  const GeneratedOutputReceipt({
    required this.candidateKind,
    required this.editableObjectLayer,
  });

  final String candidateKind;
  final bool editableObjectLayer;
}

/// DEV-PURE I-040 / s4 admission: generated model output is only a
/// raster or video candidate. A prompt must not turn an object inside
/// an existing MP4 into a real independently editable layer. Canvas
/// text, captions, and brand logo stay deterministic layers.
///
/// This is not an inpainting, tracking, or segmentation runtime, not
/// a re-qualification of Increment 2.57 VideoGenerationProvider or
/// I-043/I-044/I-045, and not a WorkflowCoordinator or paid
/// generation path.
final class GeneratedOutputAdmission {
  bool inpaintingInvented = false;
  bool trackerInvented = false;
  bool autoSegmentationInvented = false;
  bool opticalFlowInvented = false;
  bool i043Requalified = false;
  bool i044Requalified = false;
  bool i045Requalified = false;
  bool i040ProviderRequalified = false;
  bool workflowCoordinatorInvented = false;
  bool paidGenerationStarted = false;
  bool paidApiCalled = false;

  GeneratedOutputReceipt admit(GeneratedOutputRequest request) {
    if (request.promptExtractsMp4ObjectToEditableLayer) {
      throw const StudioException(
        'PROMPT_OBJECT_LAYER_FORBIDDEN',
        'generation',
      );
    }
    if (request.replacesDeterministicLayer) {
      throw const StudioException('DETERMINISTIC_LAYER_REQUIRED', 'generation');
    }
    if (!generatedCandidateKinds.contains(request.kind)) {
      throw const StudioException(
        'GENERATED_OUTPUT_NOT_CANDIDATE',
        'generation',
      );
    }
    return GeneratedOutputReceipt(
      candidateKind: request.kind,
      editableObjectLayer: false,
    );
  }
}
