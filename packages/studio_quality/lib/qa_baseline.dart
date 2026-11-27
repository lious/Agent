import 'package:studio_contracts/studio_contracts.dart';

/// Official s10i QAFinding dimension / mode / status / severity.
enum QaDimension {
  semantic,
  story,
  identity,
  sku,
  motion,
  av,
  caption,
  instruction,
  emotion,
  rights,
}

enum QaMode { deterministic, model, human }

enum QaStatus { pass, fail, unknown }

enum QaSeverity { hard, soft }

const qaSchemaVersion = '1.0.0';

/// DEV-PURE V-020 subject. This is not a paid generation request and
/// not a production QAService.
final class QaSubject {
  QaSubject({
    required this.id,
    required this.dimension,
    this.humanLabel,
    this.modelScore,
    this.modelConfidence,
    this.calibrationHash,
    this.evidenceRefs = const [],
    this.affectedScopeHash,
    this.alreadyPassed = false,
    this.lockedFields = const [],
    this.unregisteredEffect = false,
    this.ocrOnlyPictureClaim = false,
    this.lipSyncConnected = false,
    this.hasVideoUnderstanding = false,
    this.severity = QaSeverity.soft,
    this.llmJudgeIsSoleTruth = false,
  }) {
    requireId(id);
    for (final ref in evidenceRefs) {
      requireId(ref);
    }
    if (modelScore != null && (modelScore! < 0 || modelScore! > 1)) {
      throw const StudioException('PARAMETER_RANGE', 'modelScore');
    }
    if (modelConfidence != null &&
        (modelConfidence! < 0 || modelConfidence! > 1)) {
      throw const StudioException('PARAMETER_RANGE', 'modelConfidence');
    }
  }

  final String id;
  final QaDimension dimension;
  final QaStatus? humanLabel;
  final double? modelScore, modelConfidence;
  final String? calibrationHash, affectedScopeHash;
  final List<String> evidenceRefs, lockedFields;
  final bool alreadyPassed,
      unregisteredEffect,
      ocrOnlyPictureClaim,
      lipSyncConnected,
      hasVideoUnderstanding,
      llmJudgeIsSoleTruth;
  final QaSeverity severity;
}

/// Official s10i QAFinding subset used by the V-020 baseline compiler.
final class QaFinding {
  QaFinding({
    required this.id,
    required this.subjectId,
    required this.dimension,
    required this.mode,
    required this.status,
    required this.severity,
    this.score,
    this.confidence,
    this.calibrationHash,
    this.evidenceRefs = const [],
    this.reasonCode = 'qa-finding',
  });

  final String id, subjectId, reasonCode;
  final QaDimension dimension;
  final QaMode mode;
  final QaStatus status;
  final QaSeverity severity;
  final double? score, confidence;
  final String? calibrationHash;
  final List<String> evidenceRefs;

  String get schemaVersion => qaSchemaVersion;
}

/// Held-out label set + evaluator report. Precision/recall ≥0.8 is not
/// claimed. A single LLM judge is not the source of truth.
final class QaBaselineReport {
  QaBaselineReport({
    required this.findings,
    required this.humanLabels,
    required this.modelScores,
  });

  final List<QaFinding> findings;
  final Map<String, QaStatus> humanLabels;
  final Map<String, double> modelScores;

  int get documentWrites => 0;
  bool get submitted => false;
  bool get paidGenerationStarted => false;
  bool get unknownAutoPassed => false;
  bool get llmJudgeIsSoleTruth => false;
  bool get precisionRecallClaimed => false;
  bool get uncalibratedModelAutoReleased => false;
  bool get factOrSafetyRuleLowered => false;
}

final class RepairRequest {
  RepairRequest({
    required this.findings,
    this.lockedWriteSet = const [],
    this.remainingBudgetMicros = 0,
    this.approvedPaidQuote = false,
    this.repairRound = 1,
    this.alreadyPassedShotIds = const [],
  });

  final List<QaFinding> findings;
  final List<String> lockedWriteSet, alreadyPassedShotIds;
  final int remainingBudgetMicros, repairRound;
  final bool approvedPaidQuote;
}

/// s10f repair oracle. This is not a product QAService, not
/// DependencyIndex, and not a paid generation path.
final class RepairPlan {
  RepairPlan({
    required this.findingIds,
    required this.targetNodeIds,
    required this.preserveIds,
    this.needsReview = false,
    this.requiresApproval = false,
    this.lockedCaptionRewritten = false,
    this.lockedSegmentCoverage = 0,
    this.passedShotsRegenerated = 0,
  });

  final List<String> findingIds, targetNodeIds, preserveIds;
  final bool needsReview, requiresApproval, lockedCaptionRewritten;
  final int lockedSegmentCoverage, passedShotsRegenerated;

  int get documentWrites => 0;
  bool get submitted => false;
  bool get paidGenerationStarted => false;
}

/// Official V-020 leftover compiler for the QA baseline and repair
/// oracle. Precision/recall is not measured. Compile does not submit.
final class QaBaselineCompiler {
  int documentWrites = 0;

  QaBaselineReport evaluate(List<QaSubject> subjects) {
    if (subjects.any((s) => s.llmJudgeIsSoleTruth)) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'llmJudge');
    }
    final findings = <QaFinding>[];
    final humanLabels = <String, QaStatus>{};
    final modelScores = <String, double>{};
    var n = 0;
    for (final subject in subjects) {
      if (subject.humanLabel != null) {
        humanLabels[subject.id] = subject.humanLabel!;
      }
      if (subject.modelScore != null) {
        modelScores[subject.id] = subject.modelScore!;
      }
      if (subject.unregisteredEffect) {
        throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'effect');
      }
      n += 1;
      findings.add(_findingFor(subject, n));
    }
    documentWrites = 0;
    return QaBaselineReport(
      findings: findings,
      humanLabels: humanLabels,
      modelScores: modelScores,
    );
  }

  RepairPlan propose(RepairRequest request) {
    if (request.repairRound > 2) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'repairRound');
    }
    final paidNeeded = request.findings.any((f) => f.status == QaStatus.fail);
    if (paidNeeded &&
        request.remainingBudgetMicros > 0 &&
        !request.approvedPaidQuote) {
      throw const StudioException('APPROVAL_REQUIRED', 'paidRepair');
    }
    final failed = [
      for (final f in request.findings)
        if (f.status == QaStatus.fail) f,
    ];
    final locked = request.lockedWriteSet.toSet();
    final passed = request.alreadyPassedShotIds.toSet();
    final intersectsLock = failed.any(
      (f) =>
          locked.contains(f.subjectId) ||
          f.dimension == QaDimension.caption && locked.contains('caption'),
    );
    final targets = [
      for (final f in failed)
        if (!passed.contains(f.subjectId) && !locked.contains(f.subjectId))
          f.subjectId,
    ];
    documentWrites = 0;
    return RepairPlan(
      findingIds: [for (final f in request.findings) f.id],
      targetNodeIds: intersectsLock ? const [] : targets,
      preserveIds: [...passed, for (final id in locked) id],
      needsReview: intersectsLock,
      requiresApproval: paidNeeded && !request.approvedPaidQuote,
      lockedCaptionRewritten: false,
      lockedSegmentCoverage: 0,
      passedShotsRegenerated: 0,
    );
  }

  QaFinding _findingFor(QaSubject subject, int index) {
    QaMode mode;
    QaStatus status;
    double? score = subject.modelScore;
    String reason = 'qa-finding';
    if (subject.ocrOnlyPictureClaim ||
        (subject.dimension == QaDimension.motion &&
            !subject.hasVideoUnderstanding) ||
        (subject.dimension == QaDimension.av && !subject.lipSyncConnected)) {
      mode = QaMode.model;
      status = QaStatus.unknown;
      score = null;
      reason = subject.ocrOnlyPictureClaim
          ? 'ocr-only-not-picture-proof'
          : 'capability-unknown';
    } else if (subject.humanLabel != null) {
      mode = QaMode.human;
      status = subject.humanLabel!;
    } else if (subject.modelScore != null) {
      mode = QaMode.model;
      final uncalibrated = subject.calibrationHash == null;
      if (subject.severity == QaSeverity.hard && uncalibrated) {
        status = QaStatus.unknown;
        reason = 'uncalibrated-model-score';
      } else {
        status = subject.modelScore! >= 0.8 ? QaStatus.pass : QaStatus.fail;
      }
    } else {
      mode = QaMode.deterministic;
      status = QaStatus.unknown;
    }
    // unknown is never auto-promoted to pass, and its model score is
    // not kept as a release signal.
    return QaFinding(
      id: 'finding-$index',
      subjectId: subject.id,
      dimension: subject.dimension,
      mode: mode,
      status: status,
      severity: subject.severity,
      score: status == QaStatus.unknown ? null : score,
      confidence: subject.modelConfidence,
      calibrationHash: subject.calibrationHash,
      evidenceRefs: subject.evidenceRefs,
      reasonCode: reason,
    );
  }
}
