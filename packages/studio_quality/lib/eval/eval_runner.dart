import 'package:studio_contracts/studio_contracts.dart';

/// Official s10g RegistryPin. This is not a new executable skill format
/// and not an I-037 CraftSkillCompiler rewrite.
final class RegistryPin {
  RegistryPin({
    required this.id,
    required this.semver,
    required this.contentHash,
  }) {
    requireId(id);
  }

  final String id, semver, contentHash;

  @override
  bool operator ==(Object other) =>
      other is RegistryPin &&
      other.id == id &&
      other.semver == semver &&
      other.contentHash == contentHash;

  @override
  int get hashCode => Object.hash(id, semver, contentHash);
}

enum EvalResult { pass, fail, blocked, unknown, inconclusive }

/// Pre-registered eval score. Post-hoc metric shopping is refused.
final class EvalScore {
  const EvalScore({
    required this.result,
    required this.sampleSize,
    this.minSampleSize = 1,
    this.offlineOraclePassed = false,
    this.postHocMetric = false,
  });

  final EvalResult result;
  final int sampleSize, minSampleSize;
  final bool offlineOraclePassed, postHocMetric;
}

final class ReleaseCandidate {
  ReleaseCandidate({
    required this.pin,
    this.producedByModel = false,
    this.requestsPrivilegeEscalation = false,
    this.requestsUploadBypass = false,
    this.requestsPaymentBypass = false,
    this.requestsExtraMedia = false,
    this.requestsSelfDeployTraining = false,
    this.requestsProjectWrite = false,
    this.requestsSelfHealInstall = false,
    this.requestedTools = const [],
  });

  final RegistryPin pin;
  final bool producedByModel,
      requestsPrivilegeEscalation,
      requestsUploadBypass,
      requestsPaymentBypass,
      requestsExtraMedia,
      requestsSelfDeployTraining,
      requestsProjectWrite,
      requestsSelfHealInstall;
  final List<String> requestedTools;
}

final class AbEnrollment {
  const AbEnrollment({
    required this.isUserContent,
    required this.unitId,
    this.researchConsent = false,
    this.uploadConsent = false,
    this.feeApproved = false,
    this.purchaseConsent = false,
  });

  final bool isUserContent,
      researchConsent,
      uploadConsent,
      feeApproved,
      purchaseConsent;
  final String unitId;
}

final class RollbackReceipt {
  RollbackReceipt({
    required this.newRunDefaultPin,
    required this.projectSkillPin,
    required this.inFlightPin,
    required this.artifactPin,
  });

  final RegistryPin newRunDefaultPin, projectSkillPin, inFlightPin, artifactPin;
}

final class PromotionDecision {
  const PromotionDecision({
    required this.result,
    required this.modelQualityWin,
  });

  final EvalResult result;
  final bool modelQualityWin;
}

/// DEV-PURE I-057 EvalRunner / ReleaseManifest. Does not invent training,
/// does not claim a model improvement, and is not I-037 compile-time
/// tool-allowlist enforcement.
final class EvalRunner {
  EvalRunner({
    required this.activePin,
    required this.projectSkillPin,
    required this.inFlightPin,
    required this.artifactPin,
    this.installedAllowlist = const [],
  }) : newRunDefaultPin = activePin;

  RegistryPin activePin;
  RegistryPin newRunDefaultPin;
  final RegistryPin projectSkillPin, inFlightPin, artifactPin;
  final List<String> installedAllowlist;

  int enrolledUserUnits = 0;
  int documentWrites = 0;
  bool trainingExecuted = false;
  bool modelImprovementClaimed = false;
  bool sftStarted = false;
  bool dpoStarted = false;
  bool rlhfStarted = false;
  bool v020EvalBaselineClaimed = false;
  bool paidApiCalled = false;
  bool submitted = false;

  /// A model may only produce a candidate pack. It cannot change the
  /// active pin, and a pack cannot grant itself new privileges.
  ReleaseCandidate acceptCandidate(ReleaseCandidate candidate) {
    _refusePrivilege(candidate);
    if (candidate.producedByModel && candidate.pin != activePin) {
      documentWrites = 0;
      return candidate;
    }
    documentWrites = 0;
    return candidate;
  }

  void promote(ReleaseCandidate candidate) {
    _refusePrivilege(candidate);
    throw const StudioException('TOOL_NOT_ALLOWED', 'selfPromote');
  }

  int enrollAb(AbEnrollment enrollment) {
    if (enrollment.isUserContent) {
      // A purchase-service consent cannot stand in as research consent.
      if (!enrollment.researchConsent) {
        throw const StudioException(
          'RESEARCH_CONSENT_REQUIRED',
          'abEnrollment',
        );
      }
      if (!enrollment.uploadConsent) {
        throw const StudioException('UPLOAD_CONSENT_REQUIRED', 'abEnrollment');
      }
      if (!enrollment.feeApproved) {
        throw const StudioException('APPROVAL_REQUIRED', 'abEnrollment');
      }
    }
    enrolledUserUnits += 1;
    documentWrites = 0;
    return enrolledUserUnits;
  }

  PromotionDecision decideWinner(EvalScore score) {
    if (score.postHocMetric) {
      throw const StudioException(
        'UNSUPPORTED_EDIT_TECHNIQUE',
        'postHocMetric',
      );
    }
    if (score.result == EvalResult.unknown ||
        score.sampleSize < score.minSampleSize) {
      return const PromotionDecision(
        result: EvalResult.inconclusive,
        modelQualityWin: false,
      );
    }
    if (score.offlineOraclePassed && score.result != EvalResult.pass) {
      return const PromotionDecision(
        result: EvalResult.inconclusive,
        modelQualityWin: false,
      );
    }
    if (score.offlineOraclePassed) {
      return PromotionDecision(result: score.result, modelQualityWin: false);
    }
    return PromotionDecision(
      result: score.result,
      modelQualityWin: score.result == EvalResult.pass,
    );
  }

  /// Rollback changes only the default pin for new runs. The project
  /// skill pin, in-flight plan pin, and artifact provenance stay put.
  RollbackReceipt rollback(RegistryPin previous) {
    newRunDefaultPin = previous;
    documentWrites = 0;
    return RollbackReceipt(
      newRunDefaultPin: newRunDefaultPin,
      projectSkillPin: projectSkillPin,
      inFlightPin: inFlightPin,
      artifactPin: artifactPin,
    );
  }

  void hotSwapInFlightPrompt() {
    throw const StudioException('FIELD_LOCKED', 'inFlightPin');
  }

  void claimImprovement({required bool trainingRan}) {
    if (!trainingRan || !trainingExecuted) {
      throw const StudioException('TRAINING_NOT_EXECUTED', 'modelImprovement');
    }
  }

  Map<String, Object?> exportAssignment({required String unitId}) {
    return {'unitId': unitId, 'experimentPinned': true};
  }

  void _refusePrivilege(ReleaseCandidate candidate) {
    if (candidate.requestsPrivilegeEscalation ||
        candidate.requestsUploadBypass ||
        candidate.requestsPaymentBypass ||
        candidate.requestsExtraMedia ||
        candidate.requestsSelfDeployTraining ||
        candidate.requestsProjectWrite ||
        candidate.requestsSelfHealInstall ||
        candidate.requestedTools.any(
          (tool) => !installedAllowlist.contains(tool),
        )) {
      throw const StudioException('TOOL_NOT_ALLOWED', 'privilegeEscalation');
    }
    documentWrites = 0;
  }
}
