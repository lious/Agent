import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';

import 'agent_availability.dart';
import 'agent_codes.dart';
import 'agent_journal.dart';
import 'budget_controller.dart';
import 'context_builder.dart';
import 'llm_runtime.dart';
import 'message_protocol.dart';
import 'model_pack.dart';
import 'plan_validator.dart';
import 'tool_registry.dart';

typedef Hook = void Function(String phase, Map<String, Object?> ctx);

final class TurnInput {
  TurnInput({
    required this.sessionId,
    required this.turnId,
    required this.messageId,
    required this.commandId,
    required List<ContextSegment> segments,
    this.toolsEnabled = true,
  }) : segments = List.unmodifiable(segments) {
    requireId(sessionId);
    requireId(turnId);
    requireId(messageId);
    requireId(commandId);
  }

  final String sessionId, turnId, messageId, commandId;
  final List<ContextSegment> segments;
  final bool toolsEnabled;
}

final class TurnResult {
  TurnResult({
    required this.text,
    this.toolName,
    this.toolResult,
    this.pendingApproval = false,
    this.applied = false,
  });

  final String text;
  final String? toolName;
  final Map<String, Object?>? toolResult;
  final bool pendingApproval;
  final bool applied;
}

/// turn / run / step loop with fail-closed middleware, approval gates,
/// duplicate-command suppression, and late-result CAS against hand edits.
final class AgentHarness {
  AgentHarness({
    required this.runtime,
    required this.registry,
    required this.packRegistry,
    List<Hook>? hooks,
  }) : hooks = List.unmodifiable(hooks ?? const []);

  final LlmRuntimeAdapter runtime;
  final ToolRegistry registry;
  final ModelPackRegistry packRegistry;
  final List<Hook> hooks;
  final MessageLog messages = MessageLog();
  final AgentJournal journal = AgentJournal();
  final BudgetController budget = BudgetController();
  final Map<String, int> projectRevision = {};
  final Set<String> approvedCommands = {};
  final Map<String, ToolCallPlan> pendingPlans = {};
  final Map<String, String> pendingText = {};
  String? pendingSteer;

  void _runHooks(String phase, Map<String, Object?> ctx) {
    for (final hook in hooks) {
      hook(phase, ctx);
    }
    // Hooks may not register tools or approve commands.
    if (ctx['escalate'] == true || ctx['registerTool'] != null) {
      throw const StudioException(hookPrivilegeEscalation);
    }
  }

  AgentAvailability availability() =>
      AgentAvailability.inspect(packRegistry);

  void steer([String text = 'steer']) {
    pendingSteer = text;
  }

  void cancel() {
    budget.cancel();
    runtime.cancel();
  }

  void approve(String commandId) {
    requireId(commandId);
    approvedCommands.add(commandId);
  }

  /// Record a user hand-edit so a late tool result cannot overwrite it.
  void handEdit(String projectId, {required int revision}) {
    requireId(projectId);
    projectRevision[projectId] = revision;
  }

  Future<TurnResult> runTurn(
    TurnInput input, {
    int? expectedRevision,
    DateTime Function()? now,
    Duration? timeout,
    DateTime? startedAt,
  }) async {
    budget.requireOpen();
    availability().requireAgent();
    DateTime stamp() => (now ?? DateTime.now)();
    final started = startedAt ?? stamp();
    void requireDeadline() {
      if (timeout == null) return;
      if (!stamp().difference(started).isNegative &&
          stamp().difference(started) >= timeout) {
        throw const StudioException(recoverableTimeout);
      }
    }

    try {
      requireDeadline();
      messages.requireFresh(input.commandId);
      messages.accept(
        AgentMessage(
          id: input.messageId,
          sessionId: input.sessionId,
          turnId: input.turnId,
          role: MessageRole.user,
          body: input.segments.map((s) => s.body).join('\n'),
          trusted: input.segments.every((s) => s.trusted),
        ),
      );
      _runHooks('beforeTurn', {});
      final prompt = ContextBuilder().build(
        segments: input.segments,
        runtime: runtime,
      );
      final cap = runtime.capabilities();
      if (input.toolsEnabled && !cap.supportsTools) {
        throw const StudioException(toolsUnsupported);
      }
      final assembler = StreamAssembler(expectTools: input.toolsEnabled);
      requireDeadline();
      await for (final chunk in runtime.generate(
        LlmGenerateRequest(
          prompt: prompt,
          maxOutputTokens: budget.maxOutputTokens,
          toolsEnabled: input.toolsEnabled,
        ),
      )) {
        budget.requireOpen();
        requireDeadline();
        assembler.accept(chunk);
        if (chunk.text.isNotEmpty) {
          budget.addOutputTokens(runtime.tokenize(chunk.text).length);
        }
      }
      final rawTool = assembler.finish();
      final turnPayload = <String, Object?>{
        'text': assembler.text.toString(),
      };
      if (rawTool != null) {
        turnPayload['toolCall'] = rawTool;
      }
      journal.append(
        id: 'j-${input.commandId}',
        kind: 'turn',
        commandId: input.commandId,
        payload: turnPayload,
        at: DateTime.now().toUtc(),
      );
      if (rawTool == null) {
        return TurnResult(text: assembler.text.toString());
      }
      final plan = PlanValidator(
        registry,
        untrustedBodies: ContextBuilder.untrustedBodies(input.segments),
      ).validate(rawTool);
      budget.recordToolCall(jsonEncode({'name': plan.name, 'args': plan.arguments}));
      final tool = registry.lookup(plan.name)!;
      if (tool.requiresApproval && !approvedCommands.contains(input.commandId)) {
        _runHooks('beforeApproval', {'tool': plan.name});
        journal.append(
          id: 'j-${input.commandId}-pending',
          kind: 'pendingApproval',
          commandId: '${input.commandId}-pending',
          payload: {'tool': plan.name},
          at: DateTime.now().toUtc(),
        );
        pendingPlans[input.commandId] = plan;
        pendingText[input.commandId] = assembler.text.toString();
        return TurnResult(
          text: assembler.text.toString(),
          toolName: plan.name,
          pendingApproval: true,
          applied: false,
        );
      }
      if (expectedRevision != null) {
        final current = projectRevision[plan.arguments['clipId'] as String? ?? 'project'] ?? 0;
        if (current != expectedRevision) {
          throw StudioException(handEditCas, 'revision');
        }
      }
      final result = await tool.handler(plan.arguments);
      journal.append(
        id: 'j-${input.commandId}-tool',
        kind: 'toolResult',
        commandId: '${input.commandId}-tool',
        payload: result,
        at: DateTime.now().toUtc(),
      );
      return TurnResult(
        text: assembler.text.toString(),
        toolName: plan.name,
        toolResult: result,
        applied: true,
      );
    } on StudioException catch (e) {
      if (e.code == hookPrivilegeEscalation) rethrow;
      final recoverable = e.code == recoverableTimeout;
      journal.append(
        id: 'j-${input.commandId}-err',
        kind: 'error',
        commandId: '${input.commandId}-err',
        payload: {
          'code': e.code,
          'path': e.path,
          'recoverable': recoverable,
        },
        at: stamp().toUtc(),
      );
      rethrow;
    }
  }

  /// Execute a previously previewed tool after an explicit approval.
  /// Side effects stay 0 until this method runs.
  Future<TurnResult> applyApproved(String commandId) async {
    budget.requireOpen();
    if (!approvedCommands.contains(commandId)) {
      throw StudioException(approvalRequired, commandId);
    }
    final plan = pendingPlans.remove(commandId);
    if (plan == null) {
      throw StudioException(planInvalid, commandId);
    }
    final tool = registry.lookup(plan.name)!;
    final result = await tool.handler(plan.arguments);
    journal.append(
      id: 'j-$commandId-tool',
      kind: 'toolResult',
      commandId: '$commandId-tool',
      payload: result,
      at: DateTime.now().toUtc(),
    );
    return TurnResult(
      text: pendingText[commandId] ?? '',
      toolName: plan.name,
      toolResult: result,
      applied: true,
    );
  }

  /// A late tool result arriving after a hand-edit is dropped, not applied.
  void applyLateResult({
    required String projectId,
    required int resultRevision,
    required Map<String, Object?> payload,
  }) {
    final current = projectRevision[projectId] ?? 0;
    if (resultRevision != current) {
      throw StudioException(lateResultDropped, projectId);
    }
  }
}
