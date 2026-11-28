import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:studio_contracts/studio_contracts.dart';

import 'agent_codes.dart';
import 'agent_journal.dart';
import 'budget_controller.dart';
import 'llm_runtime.dart';
import 'plan_validator.dart';
import 'tool_registry.dart';

const repairPolicyVersion = 'portable-format-repair-v1';
const repairSuffix =
    '\n[portable-format-repair-v1]\nReturn exactly one complete JSON tool-call object for the SAME user task and current allowed tool schema. No prose, no additional keys, no new task or tool, and no tool execution.\n';
String repairHash(String value) =>
    sha256.convert(utf8.encode(value)).toString();

final class RepairCatalog {
  RepairCatalog(this.registry) : tools = List.of(registry.registeredTools);
  final ToolRegistry registry;
  final List<RegisteredTool> tools;

  String get hash {
    final sorted = List.of(tools)..sort((a, b) => a.name.compareTo(b.name));
    return repairHash(
      jsonEncode([
        for (final tool in sorted)
          {
            'name': tool.name,
            'sideEffect': tool.sideEffect.name,
            'requiresApproval': tool.requiresApproval,
            'arguments': [
              for (final arg in (List.of(
                tool.arguments,
              )..sort((a, b) => a.name.compareTo(b.name))))
                {
                  'name': arg.name,
                  'kind': arg.kind,
                  'required': arg.required,
                  'maxLength': arg.maxLength,
                  'allowed': arg.allowed == null
                      ? null
                      : (arg.allowed!.toList()..sort()),
                },
            ],
          },
      ]),
    );
  }

  void requireCurrent(String expectedHash) {
    if (registry.registeredTools.length != tools.length ||
        tools.any((t) => !identical(registry.lookup(t.name), t)) ||
        hash != expectedHash) {
      throw const StudioException(planInvalid, 'format-repair-catalog-drift');
    }
  }
}

final class RepairGeneration {
  const RepairGeneration(
    this.text,
    this.raw,
    this.repaired,
    this.promptHash,
    this.schemaHash,
  );
  final String text;
  final String? raw;
  final bool repaired;
  final String promptHash, schemaHash;
}

/// Pre-dispatch, bounded model formatting only. No tool handlers or providers
/// are called here other than the supplied portable model interface.
final class FormatRepairGeneration {
  FormatRepairGeneration({
    required this.runtime,
    required this.budget,
    required this.journal,
    required this.catalog,
    required this.identity,
    required this.checkFresh,
    required this.validate,
    required this.now,
  });
  final LlmRuntimeAdapter runtime;
  final BudgetController budget;
  final AgentJournal journal;
  final RepairCatalog catalog;
  final List<String> identity; // session, turn, message, command
  final void Function() checkFresh;
  final ToolCallPlan Function(String) validate;
  final DateTime Function() now;

  String id(int attempt, String phase) =>
      'fr1-${repairHash(jsonEncode([repairPolicyVersion, ...identity, attempt, phase]))}';

  Future<RepairGeneration> generate(
    String originalPrompt,
    bool toolsEnabled,
  ) async {
    final schemaHash = catalog.hash;
    final cap = runtime.capabilities();
    final firstMax = math.min(
      budget.maxOutputTokens - budget.outputTokens,
      cap.outputTokens,
    );
    for (var attempt = 1; attempt <= 2; attempt++) {
      final prompt = originalPrompt + (attempt == 2 ? repairSuffix : '');
      final promptHash = repairHash(prompt);
      final maxOutput = attempt == 1
          ? firstMax
          : math.min(
              firstMax ~/ 2,
              math.min(
                budget.maxOutputTokens - budget.outputTokens,
                cap.outputTokens,
              ),
            );
      final meter = _AttemptMeter(runtime, budget);
      var inputCharge = 0;
      void outcome(String status, String? code, int? next) {
        journal.append(
          id: id(attempt, 'outcome'),
          kind: 'modelAttemptOutcome',
          commandId: id(attempt, 'outcome'),
          at: now(),
          payload: {
            'parentCommandId': identity[3],
            'turnId': identity[1],
            'messageId': identity[2],
            'attempt': attempt,
            'modelCallId': id(attempt, 'modelCall'),
            'policyVersion': repairPolicyVersion,
            'status': status,
            'code': code,
            'inputTokenCharge': inputCharge,
            'textTokenCharge': meter.textCharge,
            'toolJsonTokenCharge': meter.jsonCharge,
            'metering': 'tokenizerEstimate',
            'cumulativeInputTokens': budget.inputTokens,
            'cumulativeOutputTokens': budget.outputTokens,
            'nextAttempt': next,
          },
        );
      }

      journal.append(
        id: id(attempt, 'request'),
        kind: 'modelAttemptRequest',
        commandId: id(attempt, 'request'),
        at: now(),
        payload: {
          'parentCommandId': identity[3],
          'turnId': identity[1],
          'messageId': identity[2],
          'attempt': attempt,
          'modelCallId': id(attempt, 'modelCall'),
          'policyVersion': repairPolicyVersion,
          'promptHash': promptHash,
          'toolSchemaHash': schemaHash,
          'maxOutputTokens': maxOutput,
        },
      );
      final assembler = StreamAssembler(expectTools: toolsEnabled);
      StudioException? failure;
      try {
        checkFresh();
        catalog.requireCurrent(schemaHash);
        if (maxOutput < 1) {
          throw const StudioException(budgetExceeded, 'output');
        }
        final input = runtime.tokenize(prompt).length;
        if (attempt == 2 && input + maxOutput > cap.contextTokens) {
          throw const StudioException('CONTEXT_BUDGET_EXCEEDED');
        }
        budget.addInputTokens(input);
        inputCharge = input;
        await for (final chunk in runtime.generate(
          LlmGenerateRequest(
            prompt: prompt,
            maxOutputTokens: maxOutput,
            toolsEnabled: toolsEnabled,
          ),
        )) {
          // Charge received data before cancellation/deadline validation.
          meter.accept(chunk);
          checkFresh();
          assembler.accept(chunk);
        }
        final raw = assembler.finish();
        if (raw != null) {
          _closedEnvelope(raw);
          validate(raw);
        }
        checkFresh();
        catalog.requireCurrent(schemaHash);
        outcome('valid', null, null);
        return RepairGeneration(
          assembler.text.toString(),
          raw,
          attempt == 2,
          promptHash,
          schemaHash,
        );
      } on StudioException catch (e) {
        failure = e;
      } on Object {
        try {
          meter.flushOrphans();
        } on StudioException {
          /* retain transport cause */
        }
        outcome('failed', 'MODEL_TRANSPORT_ERROR', null);
        rethrow;
      }
      try {
        meter.flushOrphans();
      } on StudioException catch (e) {
        failure = e;
      }
      var eligible = false;
      try {
        checkFresh();
        catalog.requireCurrent(schemaHash);
        eligible =
            attempt == 1 &&
            toolsEnabled &&
            meter.coherent &&
            meter.done &&
            (meter.finishReason == 'stop' || meter.finishReason == 'length') &&
            _eligible(assembler.toolCallJson, failure);
      } on StudioException {
        // Preserve the original refusal if repair cannot safely start.
      }
      outcome(
        eligible ? 'repairEligible' : 'failed',
        failure.code,
        eligible ? 2 : null,
      );
      if (!eligible) throw failure;
    }
    throw const StudioException(planInvalid, 'format-repair-limit');
  }

  void _closedEnvelope(String raw) {
    Object? value;
    try {
      value = jsonDecode(raw);
    } on Object {
      throw const StudioException(toolSchemaInvalid, 'json');
    }
    if (value is! Map) {
      throw const StudioException(toolSchemaInvalid, 'not-object');
    }
    if (value.keys.any((k) => !{'id', 'name', 'arguments'}.contains(k))) {
      throw const StudioException(toolSchemaInvalid, 'additional-properties');
    }
  }

  bool _eligible(String? raw, StudioException error) {
    if (raw == null || raw.isEmpty || error.code != toolSchemaInvalid) {
      return false;
    }
    Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } on FormatException {
      return error.path == 'truncated' || error.path == 'json';
    }
    if (parsed is! Map ||
        parsed['arguments'] is! Map ||
        parsed['id'] is! String ||
        parsed['name'] is! String) {
      return false;
    }
    final tool = catalog.registry.lookup(parsed['name'] as String);
    if (tool == null) return false;
    final args = Map<String, Object?>.from(parsed['arguments'] as Map);
    final known = tool.arguments.map((a) => a.name).toSet();
    final extra =
        parsed.keys.any((k) => !{'id', 'name', 'arguments'}.contains(k)) ||
        args.keys.any((k) => !known.contains(k));
    if (!extra) return false;
    try {
      validate(
        jsonEncode({
          'id': parsed['id'],
          'name': parsed['name'],
          'arguments': {
            for (final e in args.entries)
              if (known.contains(e.key)) e.key: e.value,
          },
        }),
      );
      // Permission/injection diagnostics must include rejected fields too.
      final marker = RegExp(
        r'deleteProject|uploadAll|chargeCard|shell|formatDisk',
        caseSensitive: false,
      );
      if (marker.hasMatch(raw)) return false;
      return true;
    } on StudioException {
      return false;
    }
  }
}

final class _AttemptMeter {
  _AttemptMeter(this.runtime, this.budget);
  final LlmRuntimeAdapter runtime;
  final BudgetController budget;
  final Map<int, LlmChunk> seen = {};
  final Set<int> metered = {};
  var next = 0;
  var bytes = 0;
  var textCharge = 0;
  var jsonCharge = 0;
  var done = false;
  var coherent = true;
  String? finishReason;
  final text = StringBuffer();
  String signature(LlmChunk c) =>
      jsonEncode([c.seq, c.text, c.toolCallJson, c.done, c.finishReason]);

  void charge(int textDelta, int jsonDelta) {
    textCharge += textDelta;
    jsonCharge += jsonDelta;
    // Meter received cancelled output without treating it as a refund.
    budget.outputTokens += textDelta + jsonDelta;
    if (budget.outputTokens > budget.maxOutputTokens) {
      throw const StudioException(budgetExceeded, 'output');
    }
  }

  void chargeRejected(LlmChunk c) {
    // Received payload still consumes estimate units even when rejected before
    // retention. Preserve the structural error while retaining its charge.
    final textDelta = runtime.tokenize(c.text).length;
    final jsonDelta = math.max(
      0,
      runtime.tokenize(c.toolCallJson ?? '').length - jsonCharge,
    );
    textCharge += textDelta;
    jsonCharge += jsonDelta;
    budget.outputTokens += textDelta + jsonDelta;
  }

  void accept(LlmChunk c) {
    final prior = seen[c.seq];
    if (prior != null) {
      if (signature(prior) != signature(c)) {
        coherent = false;
        charge(
          runtime.tokenize(c.text).length,
          math.max(
            0,
            runtime.tokenize(c.toolCallJson ?? '').length - jsonCharge,
          ),
        );
        throw const StudioException(planInvalid, 'stream-conflict');
      }
      return;
    }
    if (c.seq < 0 || done || (c.finishReason != null && !c.done)) {
      coherent = false;
      chargeRejected(c);
      throw const StudioException(planInvalid, 'stream-terminal');
    }
    final size = utf8.encode(c.text).length;
    bytes += size;
    if (bytes > 256 * 1024 ||
        utf8.encode(c.toolCallJson ?? '').length > 64 * 1024) {
      coherent = false;
      chargeRejected(c);
      throw const StudioException(planInvalid, 'stream-byte-limit');
    }
    seen[c.seq] = c;
    while (seen.containsKey(next)) {
      final item = seen[next++]!;
      if (done) {
        coherent = false;
        throw const StudioException(planInvalid, 'stream-terminal');
      }
      metered.add(item.seq);
      text.write(item.text);
      charge(
        math.max(0, runtime.tokenize(text.toString()).length - textCharge),
        math.max(
          0,
          runtime.tokenize(item.toolCallJson ?? '').length - jsonCharge,
        ),
      );
      if (item.done) {
        done = true;
        finishReason = item.finishReason;
      }
    }
  }

  void flushOrphans() {
    if (metered.length != seen.length) coherent = false;
    for (final item in seen.values.toList()) {
      if (!metered.add(item.seq)) continue;
      charge(
        runtime.tokenize(item.text).length,
        math.max(
          0,
          runtime.tokenize(item.toolCallJson ?? '').length - jsonCharge,
        ),
      );
    }
  }
}
