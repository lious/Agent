import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

final _pluginId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$');

void requirePluginId(String value) {
  if (!_pluginId.hasMatch(value)) {
    throw const StudioException('INVALID_ID', 'plugin');
  }
}

/// s8f RegistryBridge. EffectRegistry remains the only operator catalog.
/// This bridge does not register a new I-008 plugin.
final class OperatorDescriptor {
  OperatorDescriptor({
    required this.id,
    required this.version,
    required this.backend,
    required this.enabled,
    required this.requiredFeatures,
  });

  final String id, version, backend;
  final bool enabled;
  final List<String> requiredFeatures;
}

final class RegistryBridge {
  const RegistryBridge();

  /// Resolves a requested plugin against the already-admitted I-008
  /// catalog. Unregistered or disabled backends are
  /// [UNSUPPORTED_EDIT_TECHNIQUE]; existence of a skill is not consulted.
  OperatorDescriptor resolve({
    required String pluginType,
    required String pluginVersion,
    required String backend,
  }) {
    requirePluginId(pluginType);
    requirePluginId(pluginVersion);
    requireId(backend);
    if (pluginType == lumaWipeEffectType &&
        pluginVersion == lumaWipePluginVersion &&
        lumaWipeBackendEnabled(backend)) {
      return OperatorDescriptor(
        id: pluginType,
        version: pluginVersion,
        backend: backend,
        enabled: true,
        requiredFeatures: const [lumaWipeRequiredFeature],
      );
    }
    throw StudioException('UNSUPPORTED_EDIT_TECHNIQUE', pluginType);
  }
}
