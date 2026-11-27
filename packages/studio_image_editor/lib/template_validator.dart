import 'package:studio_contracts/studio_contracts.dart';

import 'graphic_asset.dart';
import 'image_codes.dart';
import 'template_pack.dart';

/// Semantic checks for GraphicAsset and TemplatePack. The SQL store does
/// not re-implement these.
final class TemplateValidator {
  const TemplateValidator();

  void validatePack(TemplatePack pack) {
    requireGraphicName(pack.name);
    if (pack.slots.isEmpty || pack.slots.length > 128) {
      throw const StudioException(slotType, 'slots');
    }
  }

  void validateAsset(GraphicAsset asset) {
    requireGraphicName(asset.name);
  }

  /// Unknown template metadata must not block already materialized layers,
  /// but upgrade and rebind are refused.
  void requireKnownTemplate({required bool metadataRecognized}) {
    if (!metadataRecognized) {
      throw const StudioException(unknownTemplate);
    }
  }
}
