import 'package:studio_contracts/studio_contracts.dart';

import 'agent_codes.dart';
import 'model_pack.dart';

/// When the local model pack is missing the agent is unavailable, but
/// manual tools in the registry remain independently callable.
final class AgentAvailability {
  const AgentAvailability({
    required this.agentReady,
    required this.manualToolsReady,
    this.code,
  });

  final bool agentReady;
  final bool manualToolsReady;
  final String? code;

  static AgentAvailability inspect(ModelPackRegistry registry) {
    final ready = registry.loadedPack;
    if (ready == null) {
      return const AgentAvailability(
        agentReady: false,
        manualToolsReady: true,
        code: agentUnavailable,
      );
    }
    return const AgentAvailability(
      agentReady: true,
      manualToolsReady: true,
    );
  }

  void requireAgent() {
    if (!agentReady) {
      throw StudioException(code ?? agentUnavailable);
    }
  }
}
