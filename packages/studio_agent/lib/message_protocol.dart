import 'package:studio_contracts/studio_contracts.dart';

import 'agent_codes.dart';

enum MessageRole { system, user, assistant, tool }

final class AgentMessage {
  AgentMessage({
    required this.id,
    required this.sessionId,
    required this.turnId,
    required this.role,
    required this.body,
    this.toolCallId,
    this.trusted = true,
  }) {
    requireId(id);
    requireId(sessionId);
    requireId(turnId);
    if (toolCallId != null) requireId(toolCallId!);
  }

  final String id, sessionId, turnId, body;
  final String? toolCallId;
  final MessageRole role;
  final bool trusted;
}

/// Deduplicates messages by id so a retried delivery executes once.
final class MessageLog {
  final Map<String, AgentMessage> _byId = {};
  final List<String> _order = [];
  final Set<String> _executed = {};

  bool accept(AgentMessage message) {
    if (_byId.containsKey(message.id)) {
      return false;
    }
    _byId[message.id] = message;
    _order.add(message.id);
    return true;
  }

  /// Returns true the first time [commandId] is executed, false after.
  bool claimExecution(String commandId) {
    requireId(commandId);
    if (_executed.contains(commandId)) return false;
    _executed.add(commandId);
    return true;
  }

  void requireFresh(String commandId) {
    if (!claimExecution(commandId)) {
      throw StudioException(duplicateCommand, commandId);
    }
  }

  List<AgentMessage> get messages =>
      [for (final id in _order) _byId[id]!];
}
