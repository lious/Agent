import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_render_recipe_probe/studio_render_recipe_probe.dart';
import 'package:test/test.dart';

/// Increment 2.90 official I-022 / s4 leftover: preview and final use
/// the same RenderRecipe. This file does not claim a V-003 measurement,
/// does not rewrite I-024 export suites or ExportService, does not
/// re-qualify PREVIEW_SCREENSHOT_NOT_EXPORT, Increment 2.89
/// RotationOnceAdmission, or Increment 2.69 ColorPipelineAdmission,
/// and does not invent a muxer or FrameLease. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. I-022 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('preview and final share the same RenderRecipe hash', () {
    final admission = RenderRecipeAdmission();
    final receipt = admission.admit(
      const RenderRecipeRequest(
        previewRecipeHash: 'sha256:recipe-a',
        finalRecipeHash: 'sha256:recipe-a',
      ),
    );
    expect(receipt.recipeHash, 'sha256:recipe-a');
  });

  test('divergent preview and final recipes are refused; an empty recipe is refused', () {
    final admission = RenderRecipeAdmission();
    expect(
      () => admission.admit(
        const RenderRecipeRequest(
          previewRecipeHash: 'sha256:recipe-a',
          finalRecipeHash: 'sha256:recipe-b',
        ),
      ),
      code('RENDER_RECIPE_MISMATCH'),
    );
    expect(
      () => admission.admit(
        const RenderRecipeRequest(previewRecipeHash: '', finalRecipeHash: ''),
      ),
      code('RENDER_RECIPE_REQUIRED'),
    );
  });

  test('V-003 measurement, I-024 export suites, FrameLease, and muxer leftovers stay closed', () {
    final admission = RenderRecipeAdmission();
    expect(admission.v003Claimed, isFalse);
    expect(admission.i024Requalified, isFalse);
    expect(admission.rotationOnceRequalified, isFalse);
    expect(admission.colorPipelineRequalified, isFalse);
    expect(admission.muxerInvented, isFalse);
    expect(admission.frameLeaseInvented, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
