import 'dart:convert';

import 'package:studio_agent/studio_agent.dart';
import 'package:studio_agent/format_repair.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

const valid =
    '{"id":"t1","name":"timeline.inspect","arguments":{"clipId":"clip-1"}}';
const broken = '{"id":"t1","name":"timeline.inspect","arguments":{';
Matcher errorCode(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

/// Scripted interface only: no inference, weights, network, or provider usage.
final class ScriptRuntime implements LlmRuntimeAdapter {
  ScriptRuntime(this.attempts);
  final List<List<LlmChunk>> attempts;
  final requests = <LlmGenerateRequest>[];
  final inner = FakeLlmRuntime();
  void Function(int)? afterAttempt;
  bool transportError = false;
  bool expensiveRepair = false;
  @override
  String get runtimeId => inner.runtimeId;
  @override
  Future<ModelPin> load({
    required String requestedPackId,
    required ModelPackRegistry registry,
  }) => inner.load(requestedPackId: requestedPackId, registry: registry);
  @override
  Future<void> unload() => inner.unload();
  @override
  LlmCapabilities capabilities() => inner.capabilities();
  @override
  List<int> tokenize(String text) =>
      expensiveRepair && text.contains('[portable-format-repair-v1]')
      ? List.filled(text.length + 600, 0)
      : inner.tokenize(text);
  @override
  void cancel() => inner.cancel();
  @override
  Stream<LlmChunk> generate(LlmGenerateRequest request) async* {
    requests.add(request);
    final index = requests.length - 1;
    if (index >= attempts.length) throw StateError('unexpected attempt');
    for (final chunk in attempts[index]) {
      yield chunk;
    }
    afterAttempt?.call(index);
    if (transportError) throw StateError('transport disconnected');
  }
}

List<LlmChunk> response(
  String raw, {
  String? finish = 'stop',
  bool done = true,
  String text = '',
}) => [
  LlmChunk(
    seq: 0,
    text: text,
    toolCallJson: raw,
    done: done,
    finishReason: finish,
  ),
];
TurnInput input([String command = 'command-1']) => TurnInput(
  sessionId: 's1',
  turnId: 'turn1',
  messageId: 'msg-$command',
  commandId: command,
  segments: [
    const ContextSegment(role: 'user', body: 'inspect clip-1', trusted: true),
  ],
);

Future<(AgentHarness, ScriptRuntime, Map<String, int>)> fixture(
  List<List<LlmChunk>> attempts,
) async {
  final effects = <String, int>{};
  final packs = ModelPackRegistry(trustedSignatures: {'pack1': '1' * 64});
  packs.registerCatalog(
    ModelPackManifest(
      packId: 'pack1',
      operatorId: 'fake.echo',
      digestSha256: 'a' * 64,
      signatureSha256: '1' * 64,
      contextTokens: 4096,
      outputTokens: 512,
    ),
  );
  packs.admit(
    packId: 'pack1',
    providedSignature: '1' * 64,
    providedDigest: 'a' * 64,
  );
  final runtime = ScriptRuntime(attempts);
  await runtime.load(requestedPackId: 'pack1', registry: packs);
  final registry = ToolRegistry.officialDefaults(sideEffectCounts: effects);
  final inspect = registry.lookup('timeline.inspect')!;
  registry.register(
    RegisteredTool(
      name: inspect.name,
      sideEffect: inspect.sideEffect,
      arguments: inspect.arguments,
      handler: (args) async {
        effects['timeline.inspect'] = (effects['timeline.inspect'] ?? 0) + 1;
        return inspect.handler(args);
      },
    ),
  );
  return (
    AgentHarness(runtime: runtime, registry: registry, packRegistry: packs),
    runtime,
    effects,
  );
}

void main() {
  test('single claim, retained attempt outcomes, exact identities, smaller request and fresh approval', () async {
    final (h, r, effects) = await fixture([response(broken), response(valid)]);
    h.approve('command-1'); // Cannot authorize repaired output.
    final result = await h.runTurn(input());
    expect(result.pendingApproval, isTrue);
    expect(result.applied, isFalse);
    expect(effects, isEmpty);
    expect(h.messages.messages, hasLength(1));
    expect(r.requests, hasLength(2));
    expect(r.requests[1].prompt, r.requests[0].prompt + repairSuffix);
    expect(r.requests[1].maxOutputTokens, 256);
    final records = h.journal.entries
        .where((e) => e.kind.startsWith('modelAttempt'))
        .toList();
    expect(records, hasLength(4));
    expect(records.map((e) => e.commandId).toSet(), hasLength(4));
    expect(
      records[0].id,
      'fr1-${repairHash(jsonEncode([repairPolicyVersion, 's1', 'turn1', 'msg-command-1', 'command-1', 1, 'request']))}',
    );
    expect(records[1].payload['status'], 'repairEligible');
    expect(records[3].payload['status'], 'valid');
    expect(records[2].payload['promptHash'], repairHash(r.requests[1].prompt));
    expect(
      records.every(
        (e) =>
            !e.payload.containsKey('text') && !e.payload.containsKey('prompt'),
      ),
      isTrue,
    );
    expect(
      records[3].payload['cumulativeInputTokens'],
      r.requests.fold<int>(0, (sum, q) => sum + r.tokenize(q.prompt).length),
    );
    expect(h.budget.outputTokens, broken.length + valid.length);
    expect(records[3].payload['metering'], 'tokenizerEstimate');
    expect(result.approvalCommandId, startsWith('fra1-'));
    expect(
      () => h.applyApproved(result.approvalCommandId!),
      errorCode(approvalRequired),
    );
    expect(() => h.applyApproved('command-1'), errorCode(planInvalid));
    expect(() => h.runTurn(input()), errorCode(duplicateCommand));
    expect(r.requests, hasLength(2));
    h.approve(result.approvalCommandId!);
    expect((await h.applyApproved(result.approvalCommandId!)).applied, isTrue);
    expect(
      h.journal.entries.where((e) => e.kind == 'toolResult'),
      hasLength(1),
    );
    expect(
      () => h.applyApproved(result.approvalCommandId!),
      errorCode(planInvalid),
    );
  });

  test('second format failure is terminal with no third attempt', () async {
    final (h, r, effects) = await fixture([response(broken), response(broken)]);
    await expectLater(h.runTurn(input()), errorCode(toolSchemaInvalid));
    expect(r.requests, hasLength(2));
    expect(effects, isEmpty);
    expect(
      h.journal.entries
          .where((e) => e.kind == 'modelAttemptOutcome')
          .last
          .payload['status'],
      'failed',
    );
    expect(h.journal.entries.where((e) => e.kind == 'error'), hasLength(1));
  });

  final negatives = <String, List<LlmChunk>>{
    'missing done': response(broken, done: false, finish: null),
    'missing finish evidence': response(broken, finish: null),
    'unknown finish evidence': response(broken, finish: 'unknown'),
    'missing required fields': response(
      '{"id":"t1","name":"timeline.inspect","arguments":{}}',
    ),
    'wrong type': response(
      '{"id":"t1","name":"timeline.inspect","arguments":{"clipId":1}}',
    ),
    'unknown tool': response('{"id":"t1","name":"shell","arguments":{}}'),
    'unknown tool with extras': response(
      '{"id":"t1","name":"shell","arguments":{},"extra":1}',
    ),
    'non-object': response('[]'),
    'empty call': response(''),
    'sequence gap': [
      const LlmChunk(
        seq: 1,
        toolCallJson: broken,
        done: true,
        finishReason: 'length',
      ),
    ],
    'conflicting seq': [
      const LlmChunk(seq: 0, toolCallJson: broken),
      const LlmChunk(
        seq: 0,
        toolCallJson: valid,
        done: true,
        finishReason: 'stop',
      ),
    ],
  };
  for (final entry in negatives.entries) {
    test('${entry.key} never repairs or dispatches', () async {
      final (h, r, effects) = await fixture([entry.value, response(valid)]);
      await expectLater(h.runTurn(input()), throwsA(isA<StudioException>()));
      expect(r.requests, hasLength(1));
      expect(effects, isEmpty);
      expect(
        h.journal.entries.where((e) => e.kind == 'modelAttemptOutcome'),
        hasLength(1),
      );
    });
  }

  for (final raw in [
    valid.replaceFirst('"arguments":', '"extra":true,"arguments":'),
    valid.replaceFirst('"clipId":', '"extra":true,"clipId":'),
  ]) {
    test(
      'extra keys trigger regeneration, never projection execution: $raw',
      () async {
        final (h, r, effects) = await fixture([response(raw), response(valid)]);
        final result = await h.runTurn(input());
        expect(r.requests, hasLength(2));
        expect(effects, isEmpty);
        expect(result.pendingApproval, isTrue);
      },
    );
  }

  test('extra fields cannot conceal invalid required argument', () async {
    final (h, r, effects) = await fixture([
      response(
        '{"id":"t1","name":"timeline.inspect","arguments":{"clipId":1,"extra":true}}',
      ),
    ]);
    await expectLater(h.runTurn(input()), errorCode(toolSchemaInvalid));
    expect(r.requests, hasLength(1));
    expect(effects, isEmpty);
  });

  test(
    'duplicate and reordered chunks are charged once; tool JSON is not free',
    () async {
      final (h, r, _) = await fixture([
        [
          const LlmChunk(
            seq: 1,
            toolCallJson: broken,
            done: true,
            finishReason: 'length',
          ),
          const LlmChunk(seq: 0, text: 'hello'),
          const LlmChunk(seq: 0, text: 'hello'),
        ],
        response(valid),
      ]);
      await h.runTurn(input());
      expect(h.budget.outputTokens, 5 + broken.length + valid.length);
      expect(r.requests, hasLength(2));
    },
  );

  test('transport exception does not become format repair', () async {
    final (h, r, effects) = await fixture([response(broken)]);
    r.transportError = true;
    await expectLater(h.runTurn(input()), throwsStateError);
    expect(r.requests, hasLength(1));
    expect(effects, isEmpty);
    expect(
      h.journal.entries
          .where((e) => e.kind == 'modelAttemptOutcome')
          .single
          .payload['code'],
      'MODEL_TRANSPORT_ERROR',
    );
  });

  test(
    'cancel between attempts retains received costs and forbids retry',
    () async {
      final (h, r, _) = await fixture([response(broken), response(valid)]);
      r.afterAttempt = (_) => h.cancel();
      await expectLater(h.runTurn(input()), throwsA(isA<StudioException>()));
      expect(r.requests, hasLength(1));
      expect(h.budget.outputTokens, broken.length);
    },
  );

  for (final drift in ['model', 'catalog', 'revision', 'cancel', 'deadline']) {
    test('$drift after preview invalidates apply without dispatch', () async {
      final (h, r, effects) = await fixture([
        response(broken),
        response(valid),
      ]);
      var clock = DateTime(2026);
      final result = await h.runTurn(
        input(),
        now: () => clock,
        timeout: const Duration(seconds: 5),
      );
      h.approve(result.approvalCommandId!);
      switch (drift) {
        case 'model':
          r.inner.outputTokens = 511;
        case 'catalog':
          h.registry.register(
            ToolRegistry.officialDefaults(sideEffectCounts: effects)
                .lookup('timeline.inspect')!,
          );
        case 'revision':
          h.handEdit('project', revision: 1);
        case 'cancel':
          h.cancel();
        case 'deadline':
          clock = clock.add(const Duration(seconds: 6));
      }
      await expectLater(
        h.applyApproved(result.approvalCommandId!),
        throwsA(isA<StudioException>()),
      );
      expect(effects, isEmpty);
    });
  }

  test(
    'input exhaustion before second request charges no unsent input',
    () async {
      final (h, r, _) = await fixture([response(broken), response(valid)]);
      h.budget.inputTokens = 4000;
      await expectLater(h.runTurn(input()), errorCode(budgetExceeded));
      expect(r.requests.length, lessThan(2));
      final out = h.journal.entries
          .where((e) => e.kind == 'modelAttemptOutcome')
          .last;
      expect(out.payload['inputTokenCharge'], 0);
    },
  );

  test(
    'output exhausted by incomplete JSON stops without reset or retry',
    () async {
      final (h, r, _) = await fixture([response(broken), response(valid)]);
      h.budget.outputTokens = 500;
      await expectLater(h.runTurn(input()), errorCode(budgetExceeded));
      expect(r.requests, hasLength(1));
      expect(h.budget.outputTokens, greaterThan(512));
      expect(
        h.journal.entries.where((e) => e.kind == 'modelAttemptOutcome'),
        hasLength(1),
      );
    },
  );

  test('repair context overflow does not strip original prompt', () async {
    final (h, r, _) = await fixture([response(broken), response(valid)]);
    r.inner.contextTokens = 600;
    r.expensiveRepair = true;
    await expectLater(h.runTurn(input()), errorCode('CONTEXT_BUDGET_EXCEEDED'));
    expect(r.requests, hasLength(1));
  });
  for (final drift in ['model', 'catalog', 'revision', 'deadline']) {
    test('$drift between attempts prevents generation two', () async {
      final (h, r, effects) = await fixture([
        response(broken),
        response(valid),
      ]);
      var clock = DateTime(2026);
      r.afterAttempt = (index) {
        if (index != 0) return;
        switch (drift) {
          case 'model':
            r.inner.contextTokens = 4095;
          case 'catalog':
            h.registry.register(
              ToolRegistry.officialDefaults(sideEffectCounts: effects)
                  .lookup('timeline.inspect')!,
            );
          case 'revision':
            h.handEdit('project', revision: 1);
          case 'deadline':
            clock = clock.add(const Duration(seconds: 6));
        }
      };
      await expectLater(
        h.runTurn(
          input(),
          now: () => clock,
          timeout: const Duration(seconds: 5),
        ),
        throwsA(isA<StudioException>()),
      );
      expect(r.requests, hasLength(1));
      expect(effects, isEmpty);
    });
  }

  test(
    'byte-limit violation never triggers repair or retains payload in journal',
    () async {
      final huge = 'x' * (64 * 1024 + 1);
      final (h, r, effects) = await fixture([response(huge), response(valid)]);
      await expectLater(h.runTurn(input()), errorCode(planInvalid));
      expect(r.requests, hasLength(1));
      expect(effects, isEmpty);
      expect(h.journal.payloadContains(huge), isFalse);
    },
  );

  test(
    'untrusted semantic refusal is not treated as extra-field format repair',
    () async {
      final (h, r, effects) = await fixture([
        response(
          '{"id":"t1","name":"timeline.inspect","arguments":{"clipId":"shell"},"extra":1}',
        ),
      ]);
      final t = TurnInput(
        sessionId: 's1',
        turnId: 'turn1',
        messageId: 'm1',
        commandId: 'c1',
        segments: [
          const ContextSegment(role: 'user', body: 'shell', trusted: false),
        ],
      );
      await expectLater(h.runTurn(t), throwsA(isA<StudioException>()));
      expect(r.requests, hasLength(1));
      expect(effects, isEmpty);
    },
  );
}
