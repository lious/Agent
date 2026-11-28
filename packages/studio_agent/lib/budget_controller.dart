import 'package:studio_contracts/studio_contracts.dart';

import 'agent_codes.dart';
import 'context_builder.dart';

/// Stops a run on token budget, repeated identical tool calls, or no progress.
final class BudgetController {
  BudgetController({
    this.maxInputTokens = agentLocalContextTokens,
    this.maxToolSteps = agentLocalMaxToolSteps,
    this.maxOutputTokens = agentLocalOutputTokens,
    this.identicalCallLimit = 2,
  });

  final int maxInputTokens, maxToolSteps, maxOutputTokens, identicalCallLimit;
  int inputTokens = 0;

  void addInputTokens(int n) {
    requireOpen();
    if (n < 0 || inputTokens + n > maxInputTokens) {
      throw const StudioException(budgetExceeded, 'input');
    }
    inputTokens += n;
  }

  int toolSteps = 0;
  int outputTokens = 0;
  final List<String> _recentSignatures = [];
  bool isCancelled = false;

  void cancel() {
    isCancelled = true;
  }

  void requireOpen() {
    if (isCancelled) throw const StudioException(cancelled);
  }

  void addOutputTokens(int n) {
    requireOpen();
    outputTokens += n;
    if (outputTokens > maxOutputTokens) {
      throw const StudioException(budgetExceeded, 'output');
    }
  }

  void recordToolCall(String signature) {
    requireOpen();
    toolSteps++;
    if (toolSteps > maxToolSteps) {
      throw const StudioException(budgetExceeded, 'tool-steps');
    }
    _recentSignatures.add(signature);
    if (_recentSignatures.length >= identicalCallLimit) {
      final tail = _recentSignatures.sublist(
        _recentSignatures.length - identicalCallLimit,
      );
      if (tail.every((s) => s == tail.first)) {
        throw StudioException(noProgress, signature);
      }
    }
  }
}
