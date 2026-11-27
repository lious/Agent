import 'package:studio_agent/studio_agent.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

const digestA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const sigA = '1111111111111111111111111111111111111111111111111111111111111111';

Future<AgentHarness> harness({
  List<LlmChunk>? chunks,
  List<Hook>? hooks,
  Map<String, int>? sideEffects,
}) async {
  final packs = ModelPackRegistry(trustedSignatures: {'qwen3-1p7b-q4': sigA});
  packs.registerCatalog(
    ModelPackManifest(
      packId: 'qwen3-1p7b-q4',
      operatorId: 'fake.echo',
      digestSha256: digestA,
      signatureSha256: sigA,
      contextTokens: 4096,
      outputTokens: 512,
    ),
  );
  packs.admit(
    packId: 'qwen3-1p7b-q4',
    providedSignature: sigA,
    providedDigest: digestA,
  );
  final runtime = FakeLlmRuntime(scriptedChunks: chunks);
  await runtime.load(requestedPackId: 'qwen3-1p7b-q4', registry: packs);
  final effects = sideEffects ?? <String, int>{};
  return AgentHarness(
    runtime: runtime,
    registry: ToolRegistry.officialDefaults(sideEffectCounts: effects),
    packRegistry: packs,
    hooks: hooks,
  );
}

TurnInput turn(String commandId, {List<ContextSegment>? segments}) {
  return TurnInput(
    sessionId: 'sess-1',
    turnId: 'turn-1',
    messageId: 'msg-$commandId',
    commandId: commandId,
    segments: segments ??
        [
          const ContextSegment(role: 'user', body: 'inspect the clip', trusted: true),
        ],
  );
}

void main() {
  test('duplicate command ids execute only once', () async {
    final h = await harness();
    final first = await h.runTurn(turn('cmd-1'));
    expect(first.applied, isTrue);
    expect(first.toolName, 'timeline.inspect');
    expect(() => h.runTurn(turn('cmd-1')), code(duplicateCommand));
  });

  test('approval-required tools have zero side effects until approved', () async {
    const call =
        '{"id":"tool-1","name":"edit.propose","arguments":{"clipId":"clip-1","action":"rename"}}';
    final effects = <String, int>{};
    final h = await harness(
      chunks: [const LlmChunk(seq: 0, toolCallJson: call, done: true)],
      sideEffects: effects,
    );
    final preview = await h.runTurn(turn('cmd-edit'));
    expect(preview.pendingApproval, isTrue);
    expect(preview.applied, isFalse);
    expect(effects['edit.propose'] ?? 0, 0);
    expect(() => h.applyApproved('cmd-edit'), code(approvalRequired));
    expect(effects['edit.propose'] ?? 0, 0);
    h.approve('cmd-edit');
    final applied = await h.applyApproved('cmd-edit');
    expect(applied.applied, isTrue);
    expect(effects['edit.propose'], 1);
  });

  test('hooks cannot escalate privilege or register tools', () async {
    final h = await harness(
      hooks: [
        (phase, ctx) {
          ctx['escalate'] = true;
        },
      ],
    );
    expect(() => h.runTurn(turn('cmd-hook')), code(hookPrivilegeEscalation));
  });

  test('late tool results do not overwrite a hand edit', () async {
    final h = await harness();
    h.handEdit('clip-1', revision: 2);
    expect(
      () => h.applyLateResult(
        projectId: 'clip-1',
        resultRevision: 1,
        payload: {'body': 'stale'},
      ),
      code(lateResultDropped),
    );
  });

  test('journal omits private reasoning and records tool receipts', () async {
    final h = await harness();
    await h.runTurn(turn('cmd-j'));
    h.journal.append(
      id: 'j-reason',
      kind: 'reasoning',
      commandId: 'cmd-reason',
      payload: {'reasoning': 'secret-chain', 'note': 'drop-me'},
      at: DateTime.utc(2026, 11, 27),
    );
    expect(h.journal.persistsReasoning, isFalse);
    expect(h.journal.containsKind('reasoning'), isFalse);
    expect(h.journal.containsKind('reasoningOmitted'), isTrue);
    expect(h.journal.payloadContains('secret-chain'), isFalse);
    expect(h.journal.containsKind('toolResult'), isTrue);
  });

  test('cancel stops a subsequent turn', () async {
    final h = await harness();
    h.cancel();
    expect(() => h.runTurn(turn('cmd-cancel')), code(cancelled));
  });

  test('repeated identical tool calls stop for no progress', () {
    final budget = BudgetController(maxToolSteps: 4, identicalCallLimit: 2);
    budget.recordToolCall('timeline.inspect:clip-1');
    expect(
      () => budget.recordToolCall('timeline.inspect:clip-1'),
      code(noProgress),
    );
  });
}
