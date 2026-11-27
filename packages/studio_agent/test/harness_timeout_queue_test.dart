import 'package:studio_agent/studio_agent.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

const digestA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const sigA = '1111111111111111111111111111111111111111111111111111111111111111';

Future<(AgentHarness, FakeLlmRuntime)> loadedHarness({
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
  final runtime = FakeLlmRuntime();
  await runtime.load(requestedPackId: 'qwen3-1p7b-q4', registry: packs);
  final h = AgentHarness(
    runtime: runtime,
    registry: ToolRegistry.officialDefaults(
      sideEffectCounts: sideEffects ?? <String, int>{},
    ),
    packRegistry: packs,
  );
  return (h, runtime);
}

TurnInput turn(String commandId) {
  return TurnInput(
    sessionId: 'sess-1',
    turnId: 'turn-1',
    messageId: 'msg-$commandId',
    commandId: commandId,
    segments: const [
      ContextSegment(role: 'user', body: 'inspect the clip', trusted: true),
    ],
  );
}

void main() {
  test('timeout mid-generate is recoverable and has zero tool side effects', () async {
    final effects = <String, int>{};
    final loaded = await loadedHarness(sideEffects: effects);
    final harness = loaded.$1;
    final runtime = loaded.$2;
    final clock = ManualClock();
    runtime.beforeEachChunk = () => clock.elapse(const Duration(seconds: 10));
    await expectLater(
      harness.runTurn(
        turn('cmd-timeout'),
        now: () => clock.value,
        timeout: const Duration(seconds: 5),
        startedAt: clock.value,
      ),
      code(recoverableTimeout),
    );
    expect(harness.budget.isCancelled, isFalse);
    expect(effects['edit.propose'] ?? 0, 0);
    final err = harness.journal.entries.where((e) => e.kind == 'error').single;
    expect(err.payload['code'], recoverableTimeout);
    expect(err.payload['recoverable'], isTrue);
    // A fresh command id can still run on the same harness.
    final recovered = await harness.runTurn(turn('cmd-retry'));
    expect(recovered.applied, isTrue);
    expect(recovered.toolName, 'timeline.inspect');
  });

  test('a queued job that times out can be followed by the next queued job', () async {
    final loaded = await loadedHarness();
    final runtime = loaded.$2;
    final clock = ManualClock();
    final scheduler = AgentScheduler(loaded.$1, clock: clock);
    runtime.beforeEachChunk = () => clock.elapse(const Duration(seconds: 10));
    scheduler.enqueue(
      turn('cmd-a'),
      jobId: 'job-a',
      timeout: const Duration(seconds: 5),
    );
    scheduler.enqueue(turn('cmd-b'), jobId: 'job-b');
    await expectLater(scheduler.runNext(), code(recoverableTimeout));
    expect(scheduler.jobs['job-a']!.phase, JobPhase.timedOut);
    expect(scheduler.jobs['job-a']!.recoverable, isTrue);
    expect(loaded.$1.budget.isCancelled, isFalse);
    runtime.beforeEachChunk = null;
    final second = await scheduler.runNext();
    expect(second.applied, isTrue);
    expect(scheduler.jobs['job-b']!.phase, JobPhase.completed);
  });

  test('steer on a queued job is applied to the next step, not a finished receipt', () async {
    final loaded = await loadedHarness();
    final runtime = loaded.$2;
    final scheduler = AgentScheduler(loaded.$1);
    scheduler.enqueue(turn('cmd-steer'), jobId: 'job-s');
    scheduler.steer(jobId: 'job-s', text: 'prefer clip-2');
    final result = await scheduler.runNext();
    expect(result.applied, isTrue);
    expect(runtime.lastPrompt, contains('steer: prefer clip-2'));
    expect(
      () => scheduler.steer(jobId: 'job-s', text: 'rewrite-me'),
      code(lateResultDropped),
    );
    expect(
      scheduler.jobs['job-s']!.steerText,
      'prefer clip-2',
    );
  });

  test('FIFO queue and cancel of a not-yet-run job leave side effects at zero', () async {
    final effects = <String, int>{};
    final loaded = await loadedHarness(sideEffects: effects);
    final scheduler = AgentScheduler(loaded.$1);
    scheduler.enqueue(turn('cmd-1'), jobId: 'job-1');
    scheduler.enqueue(turn('cmd-2'), jobId: 'job-2');
    scheduler.cancelJob('job-2');
    expect(scheduler.jobs['job-2']!.phase, JobPhase.cancelled);
    final first = await scheduler.runNext();
    expect(first.applied, isTrue);
    expect(scheduler.jobs['job-1']!.phase, JobPhase.completed);
    await expectLater(scheduler.runNext(), code(queueEmpty));
    expect(effects['edit.propose'] ?? 0, 0);
  });

  test('timeout before generate does not claim the command id', () async {
    final loaded = await loadedHarness();
    final clock = ManualClock();
    clock.elapse(const Duration(seconds: 30));
    expect(
      () => loaded.$1.runTurn(
        turn('cmd-late'),
        now: () => clock.value,
        timeout: const Duration(seconds: 5),
        startedAt: DateTime.utc(2026, 11, 27, 14),
      ),
      code(recoverableTimeout),
    );
    // Same command id can be retried because it was never claimed.
    clock.value = DateTime.utc(2026, 11, 27, 14);
    final recovered = await loaded.$1.runTurn(
      turn('cmd-late'),
      now: () => clock.value,
      timeout: const Duration(seconds: 5),
      startedAt: clock.value,
    );
    expect(recovered.applied, isTrue);
  });
}
