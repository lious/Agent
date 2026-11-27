import 'package:studio_contracts/studio_contracts.dart';

import 'agent_codes.dart';
import 'llm_runtime.dart';
import 'model_pack.dart';

/// Fail-closed llama.cpp facade.
///
/// The planned iOS delivery uses an XCFramework and a Qwen GGUF pack.
/// This Linux host has neither, and this increment does not download
/// weights or load a native library. [load] and [generate] stay refused
/// until a verified pack is admitted *and* a native backend is injected.
final class LlamaCppRuntimeAdapter implements LlmRuntimeAdapter {
  LlamaCppRuntimeAdapter({this.nativeBackendPresent = false});

  /// Tests may flip this to model a future native binding. The default
  /// on this host is false.
  final bool nativeBackendPresent;

  @override
  String get runtimeId => 'llamacpp.gguf';

  @override
  Future<ModelPin> load({
    required String requestedPackId,
    required ModelPackRegistry registry,
  }) async {
    if (registry.loadedPack == null ||
        registry.loadedPack!.packId != requestedPackId) {
      throw StudioException(modelPackMissing, requestedPackId);
    }
    if (!nativeBackendPresent) {
      throw const StudioException(runtimeUnavailable, 'llamacpp');
    }
    final manifest = registry.inspectCatalog(requestedPackId);
    return ModelPin(
      requestedPackId: requestedPackId,
      actualPackId: requestedPackId,
      actualDigest: manifest.digestSha256,
      actualOperator: manifest.operatorId,
      actualRuntime: runtimeId,
    );
  }

  @override
  Future<void> unload() async {}

  @override
  LlmCapabilities capabilities() => const LlmCapabilities(
    supportsTools: true,
    contextTokens: 4096,
    outputTokens: 512,
    runtimeId: 'llamacpp.gguf',
  );

  @override
  List<int> tokenize(String text) =>
      throw const StudioException(runtimeUnavailable, 'llamacpp');

  @override
  Stream<LlmChunk> generate(LlmGenerateRequest request) async* {
    throw const StudioException(runtimeUnavailable, 'llamacpp');
  }

  @override
  void cancel() {}
}
