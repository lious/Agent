import 'package:studio_contracts/studio_contracts.dart';

import 'registry_bridge.dart';

/// Official already-admitted codes. A skill signature is not a user
/// approval, and a skill cannot enlarge the session tool grant.
const skillToolNotAllowed = 'TOOL_NOT_ALLOWED';
const skillApprovalRequired = 'APPROVAL_REQUIRED';
const skillPlanInvalid = 'PLAN_INVALID';

/// s8g FilmSkill SkillStep toolId whitelist. This is not a new
/// executable plugin system and cannot add shell or network tools.
const admittedFilmCraftTools = {
  'stage.proposeShot',
  'project.proposeEdit',
  'media.analyze',
  'model.generateCandidate',
  'skill.invoke',
};

const _forbiddenToolIds = {
  'shell',
  'exec',
  'eval',
  'dynamicCode',
  'http',
  'https',
  'installModel',
  'loadShader',
  'networkUrl',
};

/// s8f execute: requiredTools ⊆ installedAllowlist ∩ sessionGrant ∩
/// branchScope. A skill cannot add tools to this intersection.
final class SkillExecutionScope {
  SkillExecutionScope({
    required this.installedAllowlist,
    required this.sessionGrant,
    required this.branchScope,
  }) {
    for (final id in [...installedAllowlist, ...sessionGrant, ...branchScope]) {
      requireId(id);
    }
  }

  final Set<String> installedAllowlist, sessionGrant, branchScope;

  Set<String> get allowedTools =>
      installedAllowlist.intersection(sessionGrant).intersection(branchScope);
}

/// s8g SkillStep declaration used only to bound DAG size and refuse
/// cycles. This is not a DAG scheduler.
final class ExternalSkillStep {
  ExternalSkillStep({
    required this.id,
    required this.toolId,
    this.dependsOn = const [],
  }) {
    requireId(id);
    requireId(toolId);
    for (final dep in dependsOn) {
      requireId(dep);
    }
  }

  final String id, toolId;
  final List<String> dependsOn;
}

/// s8f external / imported skill request. Signature trust-chain import
/// and FTS recall are not opened here. This holds privilege fields
/// only; it is not a SkillPackage loader.
final class ExternalSkillRequest {
  ExternalSkillRequest({
    required this.skillId,
    required this.contentHash,
    required this.pluginType,
    this.introducesUnreviewedOperator = false,
    required this.requiredTools,
    this.steps = const [],
    this.signed = false,
    this.userConfirmed = false,
    this.claimedApproved = false,
    this.hasRemoteRef = false,
    this.hasDynamicCode = false,
    this.hasShellStep = false,
    this.hasNetworkUrlTool = false,
    this.hasInstallModelStep = false,
  }) {
    requireId(skillId);
    requirePluginId(pluginType);
    for (final tool in requiredTools) {
      requireId(tool);
    }
  }

  final String skillId, contentHash, pluginType;
  final bool introducesUnreviewedOperator;
  final List<String> requiredTools;
  final List<ExternalSkillStep> steps;
  final bool signed, userConfirmed, claimedApproved;
  final bool hasRemoteRef,
      hasDynamicCode,
      hasShellStep,
      hasNetworkUrlTool,
      hasInstallModelStep;
}

/// Unsigned packs may be previewed as untrusted knowledge. Preview
/// never grants tools and never writes a project document.
final class SkillImportPreview {
  SkillImportPreview({
    required this.skillSnapshotHash,
    required this.untrusted,
    this.addedTools = const [],
    this.requiredApprovals = const [],
  });

  final String skillSnapshotHash;
  final bool untrusted;
  final List<String> addedTools, requiredApprovals;

  int get documentWrites => 0;
}

void refuseForbiddenSkillPayload(ExternalSkillRequest request) {
  if (request.introducesUnreviewedOperator ||
      request.hasRemoteRef ||
      request.hasDynamicCode ||
      request.hasShellStep ||
      request.hasNetworkUrlTool ||
      request.hasInstallModelStep) {
    throw StudioException('UNSUPPORTED_EDIT_TECHNIQUE', request.pluginType);
  }
  for (final tool in request.requiredTools) {
    if (_forbiddenToolIds.contains(tool) ||
        tool.startsWith('http:') ||
        tool.startsWith('https:') ||
        tool.contains('\$ref')) {
      throw StudioException('UNSUPPORTED_EDIT_TECHNIQUE', tool);
    }
  }
  for (final step in request.steps) {
    if (_forbiddenToolIds.contains(step.toolId) ||
        !admittedFilmCraftTools.contains(step.toolId)) {
      throw StudioException('UNSUPPORTED_EDIT_TECHNIQUE', step.toolId);
    }
  }
  if (request.steps.length > 16 || _skillDagHasCycle(request.steps)) {
    throw const StudioException(skillPlanInvalid, 'steps');
  }
}

void requireSkillToolGrant(
  ExternalSkillRequest request,
  SkillExecutionScope scope,
) {
  final allowed = scope.allowedTools;
  for (final tool in request.requiredTools) {
    if (!allowed.contains(tool)) {
      throw StudioException(skillToolNotAllowed, tool);
    }
  }
}

bool _skillDagHasCycle(List<ExternalSkillStep> steps) {
  final byId = {for (final step in steps) step.id: step};
  const visiting = 1, done = 2;
  final state = <String, int>{};
  bool walk(String id) {
    final seen = state[id];
    if (seen == visiting) return true;
    if (seen == done) return false;
    state[id] = visiting;
    final step = byId[id];
    if (step != null) {
      for (final dep in step.dependsOn) {
        if (walk(dep)) return true;
      }
    }
    state[id] = done;
    return false;
  }

  for (final step in steps) {
    if (walk(step.id)) return true;
  }
  return false;
}
