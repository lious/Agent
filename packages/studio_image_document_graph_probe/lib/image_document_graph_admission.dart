import 'package:studio_contracts/studio_contracts.dart';

const sharedImageDocumentBindings = {'color', 'font', 'mask', 'effectRegistry'};

const imageDocumentGraphRoles = {
  'staticClip',
  'i2vFirstFrame',
  'productOverlay',
};

final class ImageDocumentGraphRequest {
  const ImageDocumentGraphRequest({
    required this.role,
    required this.bindings,
    this.separateImageEffectSystem = false,
  });

  /// One of `staticClip`, `i2vFirstFrame`, or `productOverlay`.
  final String role;

  /// Shared color, font, mask, and EffectRegistry bindings.
  final Set<String> bindings;
  final bool separateImageEffectSystem;
}

final class ImageDocumentGraphReceipt {
  const ImageDocumentGraphReceipt({
    required this.role,
    required this.sharedEffectPath,
  });

  final String role;
  final bool sharedEffectPath;
}

/// DEV-PURE I-026 / s4 admission: ImageDocument becomes a RenderGraph
/// node through the same color, font, mask, and EffectRegistry as
/// video. Allowed roles are a static clip, an I2V first frame, or a
/// product overlay. Images and video may not use two unrelated effect
/// systems.
///
/// This is not an I2V or EffectRegistry runtime, not an unregistered
/// plugin, and not a re-qualification of Increment 2.96–2.99 still-
/// image work, Increment 2.97 RenderNodeGraphAdmission, Increment
/// 3.00 GeneratedOutputAdmission, or I-026 template / graphics-library
/// suites.
final class ImageDocumentGraphAdmission {
  bool i2vRuntimeInvented = false;
  bool unregisteredPluginInvented = false;
  bool stillImageClipRequalified = false;
  bool imageDocumentTemplatesRequalified = false;
  bool renderNodeRequalified = false;
  bool generatedOutputRequalified = false;
  bool inpaintingInvented = false;
  bool paidGenerationStarted = false;
  bool paidApiCalled = false;
  bool workflowCoordinatorInvented = false;

  ImageDocumentGraphReceipt admit(ImageDocumentGraphRequest request) {
    if (request.separateImageEffectSystem) {
      throw const StudioException(
        'SEPARATE_IMAGE_EFFECT_SYSTEM',
        'imageDocument',
      );
    }
    if (!sharedImageDocumentBindings.every(request.bindings.contains)) {
      throw const StudioException(
        'SHARED_EFFECT_PATH_REQUIRED',
        'imageDocument',
      );
    }
    if (!imageDocumentGraphRoles.contains(request.role)) {
      throw const StudioException(
        'IMAGE_DOCUMENT_ROLE_UNKNOWN',
        'imageDocument',
      );
    }
    return ImageDocumentGraphReceipt(
      role: request.role,
      sharedEffectPath: true,
    );
  }
}
