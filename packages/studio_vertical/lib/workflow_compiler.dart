import 'package:studio_contracts/studio_contracts.dart';

import 'fact_ledger.dart';
import 'vertical_brief.dart';

/// Default official template pin for this DEV-PURE compiler slice.
const defaultVerticalTemplateHash =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

/// s8h CompiledShot value. The compiler never writes a project or
/// submits a paid generation.
final class CompiledShot {
  CompiledShot({
    required this.briefId,
    required this.prompt,
    required this.unsupportedFields,
    required this.requestedParameters,
    required this.seed,
    this.inputModes = const [],
    this.recipeId,
    this.route,
    this.leftSubjectId,
    this.rightSubjectId,
    this.disclaimer,
    this.overlayText,
    this.scaleIntent,
    this.scaleClaimsGeometricCalibration = false,
    this.preciseOcclusionClaimed = false,
    this.artisticFantasy = false,
    this.lockedStance,
    this.lockedHandMask = false,
  });

  final String briefId, prompt;
  final List<String> unsupportedFields;
  final Map<String, Object?> requestedParameters;
  final int? seed;
  final List<VerticalInputMode> inputModes;
  final String? recipeId, route, leftSubjectId, rightSubjectId;
  final String? disclaimer, overlayText;
  final double? scaleIntent;
  final bool scaleClaimsGeometricCalibration;
  final bool preciseOcclusionClaimed, artisticFantasy, lockedHandMask;
  final String? lockedStance;

  /// Protocol proof: compile errors and successes do not submit.
  int get documentWrites => 0;
  bool get submitted => false;

  /// s8 / s8m: seed is a same-profile similarity hint only.
  bool get seedClaimsCrossModelConsistency => false;
}

/// s8h VerticalWorkflowCompiler first I-038 slice: preflight/compile
/// fixtures, confirmed facts, portrait and firstLast refusals, and
/// override/template rebase. This is not a paid generator, not SQL
/// vertical.v1, and not production FTS/RAG.
final class VerticalWorkflowCompiler {
  VerticalWorkflowCompiler({
    this.supportedModes = const {
      VerticalInputMode.text,
      VerticalInputMode.script,
      VerticalInputMode.mediaMontage,
      VerticalInputMode.i2v,
    },
    this.supportedParameters = const {'duration', 'aspect', 'seed'},
    this.currentTemplateHash = defaultVerticalTemplateHash,
  });

  final Set<VerticalInputMode> supportedModes;
  final Set<String> supportedParameters;
  final String currentTemplateHash;
  int documentWrites = 0;

  CompiledShot compile({
    required VerticalBrief brief,
    required FactLedger facts,
    List<SubjectRights> subjects = const [],
    PromptOverride? override,
    Map<String, bool> untrustedFactClaims = const {},
    DateTime? now,
  }) {
    final clock = now ?? DateTime.utc(2026, 11, 28);
    _refuseUnconfirmedFacts(brief, facts, untrustedFactClaims, clock);
    _refuseUnauthorizedSubjects(brief, subjects);
    _refuseUnsupportedModes(brief);
    _refuseGenerationPolicy(brief);
    _refuseSlotCounts(brief);
    _refuseStaleOverride(override);

    final unsupported = [
      for (final name in brief.requestedParameters.keys)
        if (!supportedParameters.contains(name)) name,
    ]..sort();
    // Unsupported parameters stay listed and are not truncated away.
    documentWrites = 0;
    return CompiledShot(
      briefId: brief.id,
      prompt:
          'vertical:${brief.purpose.name}:'
          '${brief.inputModes.map((m) => m.name).join("+")}',
      unsupportedFields: unsupported,
      requestedParameters: Map<String, Object?>.from(brief.requestedParameters),
      seed: brief.seed,
      inputModes: List.of(brief.inputModes),
    );
  }

  void _refuseUnconfirmedFacts(
    VerticalBrief brief,
    FactLedger facts,
    Map<String, bool> untrustedFactClaims,
    DateTime now,
  ) {
    for (final e in untrustedFactClaims.entries) {
      facts.ignoreUntrustedClaim(id: e.key, claimedConfirmed: e.value);
    }
    final needsProduct =
        brief.purpose == VerticalPurpose.marketing ||
        brief.purpose == VerticalPurpose.showcase;
    if (needsProduct) {
      final productId = brief.productId;
      if (productId == null || brief.factIds.isEmpty) {
        throw StudioException(unconfirmedFact, brief.id);
      }
      for (final id in brief.factIds) {
        facts.requireConfirmed(id: id, productId: productId, now: now);
      }
      return;
    }
    if (brief.factIds.isNotEmpty) {
      final productId = brief.productId;
      if (productId == null) {
        throw StudioException(unconfirmedFact, brief.id);
      }
      for (final id in brief.factIds) {
        facts.requireConfirmed(id: id, productId: productId, now: now);
      }
    }
  }

  void _refuseUnauthorizedSubjects(
    VerticalBrief brief,
    List<SubjectRights> subjects,
  ) {
    final byId = {for (final s in subjects) s.subjectId: s};
    for (final id in brief.subjectIds) {
      final rights = byId[id];
      if (rights == null || !rights.portraitConsent) {
        throw StudioException(portraitConsentRequired, id);
      }
    }
  }

  void _refuseUnsupportedModes(VerticalBrief brief) {
    for (final mode in brief.inputModes) {
      if (!supportedModes.contains(mode)) {
        // firstLast is a real dual-anchor route, not an i2v rename.
        throw StudioException(capabilityUnsupported, mode.name);
      }
    }
  }

  void _refuseGenerationPolicy(VerticalBrief brief) {
    if (brief.requiresGeneration && !brief.allowNewGeneration) {
      throw StudioException(generationDisabled, brief.id);
    }
  }

  void _refuseSlotCounts(VerticalBrief brief) {
    if (brief.inputModes.contains(VerticalInputMode.script) &&
        brief.scriptBindingId == null) {
      throw const StudioException(slotCount, 'scriptBindingId');
    }
    if (brief.purpose == VerticalPurpose.showcase) {
      final roles = {for (final b in brief.sourceBindings) b.role};
      if (!roles.contains(SourceRole.front) ||
          !roles.contains(SourceRole.detail)) {
        throw const StudioException(slotCount, 'showcase.bindings');
      }
    }
    if (brief.inputModes.contains(VerticalInputMode.firstLast)) {
      final roles = [for (final b in brief.sourceBindings) b.role];
      final first = roles.where((r) => r == SourceRole.firstFrame).length;
      final last = roles.where((r) => r == SourceRole.lastFrame).length;
      if (first != 1 || last != 1) {
        throw const StudioException(slotCount, 'firstLast');
      }
    }
  }

  void _refuseStaleOverride(PromptOverride? override) {
    if (override == null) return;
    if (override.baseTemplateHash != currentTemplateHash) {
      throw StudioException(overrideRebaseRequired, 'baseTemplateHash');
    }
  }
}
