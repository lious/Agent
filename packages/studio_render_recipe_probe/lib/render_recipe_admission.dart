import 'package:studio_contracts/studio_contracts.dart';

final class RenderRecipeRequest {
  const RenderRecipeRequest({
    required this.previewRecipeHash,
    required this.finalRecipeHash,
  });

  final String previewRecipeHash, finalRecipeHash;
}

final class RenderRecipeReceipt {
  const RenderRecipeReceipt({required this.recipeHash});

  final String recipeHash;
}

/// DEV-PURE I-022 / s4 admission: preview and final share the same
/// RenderRecipe. This is not a V-003 pixel or duration measurement, not
/// a re-qualification of I-024 export suites or PREVIEW_SCREENSHOT_NOT_EXPORT,
/// and not a FrameLease or muxer.
final class RenderRecipeAdmission {
  bool v003Claimed = false;
  bool i024Requalified = false;
  bool rotationOnceRequalified = false;
  bool colorPipelineRequalified = false;
  bool muxerInvented = false;
  bool frameLeaseInvented = false;
  bool paidApiCalled = false;

  RenderRecipeReceipt admit(RenderRecipeRequest request) {
    if (request.previewRecipeHash.isEmpty || request.finalRecipeHash.isEmpty) {
      throw const StudioException('RENDER_RECIPE_REQUIRED', 'recipe');
    }
    if (request.previewRecipeHash != request.finalRecipeHash) {
      throw const StudioException('RENDER_RECIPE_MISMATCH', 'recipe');
    }
    return RenderRecipeReceipt(recipeHash: request.previewRecipeHash);
  }
}
