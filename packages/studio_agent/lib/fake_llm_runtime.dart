import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';

import 'agent_codes.dart';
import 'llm_runtime.dart';
import 'model_pack.dart';

/// Deterministic in-process runtime used by official Linux tests.
/// It never loads weights and never opens a network socket.
final class FakeLlmRuntime implements LlmRuntimeAdapter {
  FakeLlmRuntime({
    this.scriptedChunks,
    this.supportsTools = true,
    this.contextTokens = 4096,
    this.outputTokens = 512,
  });

  /// When set, [generate] emits this list instead of the default echo plan.
  List<LlmChunk>? scriptedChunks;
  bool supportsTools;
  int contextTokens, outputTokens;
  ModelPin? pin;
  bool _loaded = false;
  bool _cancelled = false;
  int networkRequestCount = 0;

  @override
  String get runtimeId => 'fake.echo';

  @override
  Future<ModelPin> load({
    required String requestedPackId,
    required ModelPackRegistry registry,
  }) async {
    final handle = registry.loadedPack;
    if (handle == null || handle.packId != requestedPackId) {
      throw StudioException(modelPackMissing, requestedPackId);
    }
    registry.requireLive(handle);
    final manifest = registry.inspectCatalog(requestedPackId);
    pin = ModelPin(
      requestedPackId: requestedPackId,
      actualPackId: handle.packId,
      actualDigest: manifest.digestSha256,
      actualOperator: manifest.operatorId,
      actualRuntime: runtimeId,
    );
    if (pin!.actualPackId != requestedPackId) {
      throw StudioException(modelMismatch, requestedPackId);
    }
    _loaded = true;
    return pin!;
  }

  @override
  Future<void> unload() async {
    _loaded = false;
    pin = null;
  }

  @override
  LlmCapabilities capabilities() => LlmCapabilities(
    supportsTools: supportsTools,
    contextTokens: contextTokens,
    outputTokens: outputTokens,
    runtimeId: runtimeId,
  );

  @override
  List<int> tokenize(String text) =>
      [for (final cu in text.codeUnits) cu & 0xffff];

  @override
  Stream<LlmChunk> generate(LlmGenerateRequest request) async* {
    if (!_loaded) {
      throw const StudioException(runtimeUnavailable);
    }
    if (_cancelled) {
      throw const StudioException(cancelled);
    }
    if (request.toolsEnabled && !supportsTools) {
      throw const StudioException(toolsUnsupported);
    }
    final chunks = scriptedChunks ?? _defaultChunks(request);
    for (final chunk in chunks) {
      if (_cancelled) {
        throw const StudioException(cancelled);
      }
      yield chunk;
    }
  }

  @override
  void cancel() {
    _cancelled = true;
  }

  void resetCancel() {
    _cancelled = false;
  }

  List<LlmChunk> _defaultChunks(LlmGenerateRequest request) {
    if (request.toolsEnabled && supportsTools) {
      final call = jsonEncode({
        'id': 'tool-1',
        'name': 'timeline.inspect',
        'arguments': {'clipId': 'clip-1'},
      });
      return [
        LlmChunk(seq: 0, text: 'ok '),
        LlmChunk(seq: 1, toolCallJson: call, done: true),
      ];
    }
    return [const LlmChunk(seq: 0, text: 'ok', done: true)];
  }
}
