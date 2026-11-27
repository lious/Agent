import 'package:studio_contracts/studio_contracts.dart';

/// s10e RoleProfile roles. Critic is read-only QA; Editor only proposes
/// EditCommand patches and does not apply document writes.
enum AgentRole { director, writer, visual, editor, sound, critic }

enum ScopePolicy {
  intentPlanning,
  scriptCandidate,
  visualObserve,
  editCommandProposal,
  audioCandidate,
  readOnlyQa,
}

final class RoleProfile {
  RoleProfile({
    required this.role,
    required this.pin,
    required this.allowedToolPins,
    required this.scopePolicy,
    required this.maxChildRuns,
    required this.budgetShare,
    required this.modelProfilePin,
  }) {
    requireId(pin);
    requireId(modelProfilePin);
    for (final tool in allowedToolPins) {
      requireId(tool);
    }
    if (maxChildRuns < 0) {
      throw const StudioException('INVALID_ID', 'maxChildRuns');
    }
    if (budgetShare < 0) {
      throw const StudioException('INVALID_ID', 'budgetShare');
    }
    if (role == AgentRole.editor &&
        scopePolicy != ScopePolicy.editCommandProposal) {
      throw const StudioException('ROLE_SCOPE_MISMATCH', 'editor');
    }
    if (role == AgentRole.critic && scopePolicy != ScopePolicy.readOnlyQa) {
      throw const StudioException('ROLE_SCOPE_MISMATCH', 'critic');
    }
  }

  final AgentRole role;
  final String pin, modelProfilePin;
  final List<String> allowedToolPins;
  final ScopePolicy scopePolicy;
  final int maxChildRuns, budgetShare;

  bool get isReadOnly => role == AgentRole.critic;
  bool get proposesEditsOnly => role == AgentRole.editor;
}
