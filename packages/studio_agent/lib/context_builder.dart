import 'package:studio_contracts/studio_contracts.dart';

import 'agent_codes.dart';
import 'llm_runtime.dart';

/// Default portable budget for the local-agent profile `agent.local.v1`.
const agentLocalContextTokens = 4096;
const agentLocalOutputTokens = 512;
const agentLocalMaxToolSteps = 4;

final class ContextSegment {
  const ContextSegment({
    required this.role,
    required this.body,
    this.trusted = true,
  });

  final String role, body;
  final bool trusted;
}

/// Builds a pinned prompt. Untrusted segments are fenced so they cannot
/// be treated as executable instructions by the plan validator.
final class ContextBuilder {
  ContextBuilder({
    this.contextTokens = agentLocalContextTokens,
    this.outputTokens = agentLocalOutputTokens,
  });

  final int contextTokens, outputTokens;

  static const fenceOpen = '<<<UNTRUSTED_DATA>>>';
  static const fenceClose = '<<<END_UNTRUSTED_DATA>>>';

  String build({
    required List<ContextSegment> segments,
    required LlmRuntimeAdapter runtime,
  }) {
    final cap = runtime.capabilities();
    final budget = contextTokens < cap.contextTokens
        ? contextTokens
        : cap.contextTokens;
    final pieces = <String>[];
    for (final segment in segments) {
      if (segment.trusted) {
        pieces.add('[${segment.role}]\n${segment.body}');
      } else {
        final fenced = '$fenceOpen\n${segment.body}\n$fenceClose';
        pieces.add('[${segment.role}:untrusted]\n$fenced');
      }
    }
    final prompt = pieces.join('\n\n');
    final tokens = runtime.tokenize(prompt).length;
    if (tokens + outputTokens > budget) {
      throw StudioException(budgetExceeded, 'context');
    }
    return prompt;
  }

  /// Extract untrusted bodies so the validator can refuse injected verbs.
  static List<String> untrustedBodies(List<ContextSegment> segments) {
    return [
      for (final s in segments)
        if (!s.trusted) s.body,
    ];
  }
}
