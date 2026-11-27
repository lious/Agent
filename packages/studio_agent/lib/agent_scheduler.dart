import 'package:studio_contracts/studio_contracts.dart';

import 'agent_codes.dart';
import 'agent_harness.dart';
import 'context_builder.dart';

/// Injectable clock so official timeout tests do not sleep.
final class ManualClock {
  ManualClock([DateTime? start])
    : value = start ?? DateTime.utc(2026, 11, 27, 14);

  DateTime value;

  void elapse(Duration duration) {
    value = value.add(duration);
  }
}

enum JobPhase { queued, running, completed, timedOut, cancelled, failed }

final class AgentJob {
  AgentJob({
    required this.id,
    required this.input,
    this.timeout,
  }) {
    requireId(id);
  }

  final String id;
  final TurnInput input;
  final Duration? timeout;
  JobPhase phase = JobPhase.queued;
  String? lastCode;
  bool recoverable = false;
  TurnResult? result;
  String? steerText;
}

/// FIFO job queue, steer, and recoverable timeout around [AgentHarness].
///
/// A timeout journals a recoverable error and does not cancel the budget.
/// A later job or a retry with a fresh command id can still run. Steer
/// recorded while a job is queued or running is applied to the next step,
/// not as a rewrite of a finished receipt.
final class AgentScheduler {
  AgentScheduler(this.harness, {ManualClock? clock})
    : clock = clock ?? ManualClock();

  final AgentHarness harness;
  final ManualClock clock;
  final List<AgentJob> queue = [];
  final Map<String, AgentJob> jobs = {};
  AgentJob? running;

  AgentJob enqueue(
    TurnInput input, {
    required String jobId,
    Duration? timeout,
  }) {
    requireId(jobId);
    if (jobs.containsKey(jobId)) {
      throw StudioException(duplicateCommand, jobId);
    }
    final job = AgentJob(id: jobId, input: input, timeout: timeout);
    jobs[jobId] = job;
    queue.add(job);
    harness.journal.append(
      id: 'j-$jobId-queued',
      kind: 'queued',
      commandId: '$jobId-queued',
      payload: {'jobId': jobId, 'commandId': input.commandId},
      at: clock.value,
    );
    return job;
  }

  /// Attach a steer instruction to a queued or running job, or to the
  /// next queued job when [jobId] is omitted.
  void steer({String? jobId, required String text}) {
    if (text.trim().isEmpty) {
      throw const StudioException(planInvalid, 'steer');
    }
    final job = jobId == null
        ? (running ?? (queue.isEmpty ? null : queue.first))
        : jobs[jobId];
    if (job == null) {
      throw StudioException(jobNotFound, jobId ?? 'next');
    }
    if (job.phase == JobPhase.completed ||
        job.phase == JobPhase.cancelled) {
      // A finished receipt is not rewritten.
      throw StudioException(lateResultDropped, job.id);
    }
    job.steerText = text;
    harness.journal.append(
      id: 'j-${job.id}-steer',
      kind: 'steer',
      commandId: '${job.id}-steer',
      payload: {'jobId': job.id, 'text': text},
      at: clock.value,
    );
  }

  void cancelJob(String jobId) {
    final job = jobs[jobId];
    if (job == null) throw StudioException(jobNotFound, jobId);
    if (job.phase == JobPhase.completed) {
      throw StudioException(lateResultDropped, jobId);
    }
    if (running?.id == jobId) {
      harness.cancel();
      job.phase = JobPhase.cancelled;
      job.lastCode = cancelled;
      running = null;
      return;
    }
    queue.removeWhere((j) => j.id == jobId);
    job.phase = JobPhase.cancelled;
    job.lastCode = cancelled;
    harness.journal.append(
      id: 'j-$jobId-cancelled',
      kind: 'cancelled',
      commandId: '$jobId-cancelled',
      payload: {'jobId': jobId, 'ran': false},
      at: clock.value,
    );
  }

  Future<TurnResult> runNext() async {
    if (running != null) {
      throw StudioException(jobBusy, running!.id);
    }
    if (queue.isEmpty) {
      throw const StudioException(queueEmpty);
    }
    final job = queue.removeAt(0);
    running = job;
    job.phase = JobPhase.running;
    final started = clock.value;
    final segments = [
      ...job.input.segments,
      if (job.steerText != null)
        ContextSegment(
          role: 'system',
          body: 'steer: ${job.steerText}',
          trusted: true,
        ),
    ];
    final steered = TurnInput(
      sessionId: job.input.sessionId,
      turnId: job.input.turnId,
      messageId: job.input.messageId,
      commandId: job.input.commandId,
      segments: segments,
      toolsEnabled: job.input.toolsEnabled,
    );
    try {
      final result = await harness.runTurn(
        steered,
        now: () => clock.value,
        timeout: job.timeout,
        startedAt: started,
      );
      job.phase = JobPhase.completed;
      job.result = result;
      return result;
    } on StudioException catch (e) {
      job.lastCode = e.code;
      if (e.code == recoverableTimeout) {
        job.phase = JobPhase.timedOut;
        job.recoverable = true;
      } else if (e.code == cancelled) {
        job.phase = JobPhase.cancelled;
      } else {
        job.phase = JobPhase.failed;
      }
      rethrow;
    } finally {
      running = null;
    }
  }
}
