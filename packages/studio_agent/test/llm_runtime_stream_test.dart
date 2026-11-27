import 'dart:convert';

import 'package:studio_agent/studio_agent.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

const digestA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const sigA = '1111111111111111111111111111111111111111111111111111111111111111';

Future<(ModelPackRegistry, FakeLlmRuntime, ModelPin)> loadedFake() async {
  final registry = ModelPackRegistry(trustedSignatures: {'qwen3-1p7b-q4': sigA});
  registry.registerCatalog(
    ModelPackManifest(
      packId: 'qwen3-1p7b-q4',
      operatorId: 'fake.echo',
      digestSha256: digestA,
      signatureSha256: sigA,
      contextTokens: 4096,
      outputTokens: 512,
    ),
  );
  registry.admit(
    packId: 'qwen3-1p7b-q4',
    providedSignature: sigA,
    providedDigest: digestA,
  );
  final runtime = FakeLlmRuntime();
  final pin = await runtime.load(
    requestedPackId: 'qwen3-1p7b-q4',
    registry: registry,
  );
  return (registry, runtime, pin);
}

void main() {
  test('model pin records the actual admitted pack, digest, and runtime', () async {
    final loaded = await loadedFake();
    final pin = loaded.$3;
    expect(pin.requestedPackId, 'qwen3-1p7b-q4');
    expect(pin.actualPackId, 'qwen3-1p7b-q4');
    expect(pin.actualDigest, digestA);
    expect(pin.actualOperator, 'fake.echo');
    expect(pin.actualRuntime, 'fake.echo');
  });

  test('load refuses when the requested pack is not the admitted one', () async {
    final registry = ModelPackRegistry(trustedSignatures: {'qwen3-1p7b-q4': sigA});
    registry.registerCatalog(
      ModelPackManifest(
        packId: 'qwen3-1p7b-q4',
        operatorId: 'fake.echo',
        digestSha256: digestA,
        signatureSha256: sigA,
        contextTokens: 4096,
        outputTokens: 512,
      ),
    );
    registry.admit(
      packId: 'qwen3-1p7b-q4',
      providedSignature: sigA,
      providedDigest: digestA,
    );
    final runtime = FakeLlmRuntime();
    expect(
      () => runtime.load(requestedPackId: 'other-pack', registry: registry),
      code(modelPackMissing),
    );
  });

  test('duplicate and out-of-order chunks do not execute a half tool call', () {
    final call = jsonEncode({
      'id': 'tool-1',
      'name': 'timeline.inspect',
      'arguments': {'clipId': 'clip-1'},
    });
    final assembler = StreamAssembler();
    assembler.accept(LlmChunk(seq: 1, toolCallJson: call, done: true));
    assembler.accept(const LlmChunk(seq: 0, text: 'ok '));
    // Duplicate of seq 1 is ignored.
    assembler.accept(LlmChunk(seq: 1, toolCallJson: '{"partial"', done: true));
    expect(assembler.finish(), call);
    expect(assembler.text.toString(), 'ok ');
  });

  test('truncated tool JSON is refused and is not executable', () {
    final assembler = StreamAssembler();
    assembler.accept(const LlmChunk(seq: 0, toolCallJson: '{"name":"timeline.inspect"', done: true));
    expect(assembler.finish, code(toolSchemaInvalid));
  });

  test('truncated stream without done is refused', () {
    final assembler = StreamAssembler();
    assembler.accept(const LlmChunk(seq: 0, text: 'ok'));
    expect(assembler.finish, code(planInvalid));
  });

  test('a model that does not support tools is explicitly refused', () async {
    final loaded = await loadedFake();
    final runtime = loaded.$2;
    runtime.supportsTools = false;
    expect(
      () => runtime
          .generate(
            const LlmGenerateRequest(
              prompt: 'hi',
              maxOutputTokens: 16,
              toolsEnabled: true,
            ),
          )
          .toList(),
      code(toolsUnsupported),
    );
  });

  test('llama.cpp adapter is fail-closed without a native backend', () async {
    final loaded = await loadedFake();
    final adapter = LlamaCppRuntimeAdapter();
    expect(
      () => adapter.load(
        requestedPackId: 'qwen3-1p7b-q4',
        registry: loaded.$1,
      ),
      code(runtimeUnavailable),
    );
    expect(
      () => adapter
          .generate(
            const LlmGenerateRequest(prompt: 'hi', maxOutputTokens: 8),
          )
          .toList(),
      code(runtimeUnavailable),
    );
  });

  test('cloud text adapter is unconfigured and opens zero sockets', () {
    final adapter = CloudTextAdapter();
    expect(
      () => adapter.load(
        requestedPackId: 'cloud-text',
        registry: ModelPackRegistry(),
      ),
      code(cloudProviderNotConfigured),
    );
    expect(adapter.networkRequestCount, 0);
  });
}
