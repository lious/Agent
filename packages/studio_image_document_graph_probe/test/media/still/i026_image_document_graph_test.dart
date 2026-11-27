import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_image_document_graph_probe/studio_image_document_graph_probe.dart';
import 'package:test/test.dart';

/// Increment 3.01 official I-026 / s4 leftover: ImageDocument becomes
/// a RenderGraph node through the same color, font, mask, and
/// EffectRegistry as video. It may be used as a static clip, an I2V
/// first frame, or a product overlay. A separate image-only effect
/// system is refused.
///
/// This file does not invent an I2V runtime or an unregistered plugin,
/// and does not re-qualify Increments 2.96–2.99 still-image work,
/// Increment 2.97 RenderNodeGraphAdmission, Increment 3.00
/// GeneratedOutputAdmission, or I-026 template / graphics-library
/// suites. InversePatch kind stays restoreSnapshot. Project
/// user_version stays 9. I-026 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

const shared = {'color', 'font', 'mask', 'effectRegistry'};

void main() {
  test('an ImageDocument on the shared effect path is admitted as a static clip, I2V first frame, or product overlay', () {
    final admission = ImageDocumentGraphAdmission();
    for (final role in imageDocumentGraphRoles) {
      final receipt = admission.admit(
        ImageDocumentGraphRequest(role: role, bindings: shared),
      );
      expect(receipt.role, role);
      expect(receipt.sharedEffectPath, isTrue);
    }
  });

  test('a separate image effect system, a missing shared binding, or an unknown role is refused', () {
    final admission = ImageDocumentGraphAdmission();
    expect(
      () => admission.admit(
        ImageDocumentGraphRequest(
          role: 'staticClip',
          bindings: shared,
          separateImageEffectSystem: true,
        ),
      ),
      code('SEPARATE_IMAGE_EFFECT_SYSTEM'),
    );
    expect(
      () => admission.admit(
        const ImageDocumentGraphRequest(
          role: 'productOverlay',
          bindings: {'color', 'font', 'mask'},
        ),
      ),
      code('SHARED_EFFECT_PATH_REQUIRED'),
    );
    expect(
      () => admission.admit(
        ImageDocumentGraphRequest(role: 'editableMp4Object', bindings: shared),
      ),
      code('IMAGE_DOCUMENT_ROLE_UNKNOWN'),
    );
  });

  test('an I2V runtime, unregistered plugin, and already-official still-image, RenderNode, generated-output, and I-026 template suites stay closed', () {
    final admission = ImageDocumentGraphAdmission();
    expect(admission.i2vRuntimeInvented, isFalse);
    expect(admission.unregisteredPluginInvented, isFalse);
    expect(admission.stillImageClipRequalified, isFalse);
    expect(admission.imageDocumentTemplatesRequalified, isFalse);
    expect(admission.renderNodeRequalified, isFalse);
    expect(admission.generatedOutputRequalified, isFalse);
    expect(admission.inpaintingInvented, isFalse);
    expect(admission.paidGenerationStarted, isFalse);
    expect(admission.paidApiCalled, isFalse);
    expect(admission.workflowCoordinatorInvented, isFalse);
  });
}
