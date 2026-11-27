import 'package:studio_contracts/studio_contracts.dart';

import 'agent_codes.dart';
import 'llm_runtime.dart';
import 'model_pack.dart';

/// Cloud text provider port. This increment does not configure, call, or
/// pay for any cloud API. [networkRequestCount] remains 0.
final class CloudTextAdapter implements LlmRuntimeAdapter {
  int networkRequestCount = 0;

  @override
  String get runtimeId => 'cloud.text.unconfigured';

  @override
  Future<ModelPin> load({
    required String requestedPackId,
    required ModelPackRegistry registry,
  }) async {
    throw const StudioException(cloudProviderNotConfigured);
  }

  @override
  Future<void> unload() async {}

  @override
  LlmCapabilities capabilities() => const LlmCapabilities(
    supportsTools: true,
    contextTokens: 4096,
    outputTokens: 512,
    runtimeId: 'cloud.text.unconfigured',
  );

  @override
  List<int> tokenize(String text) =>
      throw const StudioException(cloudProviderNotConfigured);

  @override
  Stream<LlmChunk> generate(LlmGenerateRequest request) async* {
    // Fail closed before any socket is opened.
    throw const StudioException(cloudProviderNotConfigured);
  }

  @override
  void cancel() {}
}
