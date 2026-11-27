import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_quality/studio_quality.dart';
import 'package:test/test.dart';

/// Increment 2.52 official first V-020 slice: QA baseline fixtures and
/// a repair oracle. This file does not claim precision/recall ≥0.8, does
/// not start paid generation, does not invent DependencyIndex or a
/// product QAService, does not mark I-037, I-038, or V-007 complete,
/// and does not rewrite frozen I-014 or I-036 suites. InversePatch
/// kind stays restoreSnapshot.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('human labels and model scores are listed separately; unknown is not auto-pass; an uncalibrated model score cannot auto-release a hard item; precision/recall is not claimed', () {
    final compiler = QaBaselineCompiler();
    final report = compiler.evaluate([
      QaSubject(
        id: 'shot-good',
        dimension: QaDimension.story,
        humanLabel: QaStatus.pass,
        modelScore: 0.91,
        calibrationHash:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        evidenceRefs: const ['ev-story-1'],
      ),
      QaSubject(
        id: 'shot-unknown',
        dimension: QaDimension.emotion,
        severity: QaSeverity.hard,
        modelScore: 0.95,
      ),
    ]);
    expect(report.humanLabels['shot-good'], QaStatus.pass);
    expect(report.modelScores['shot-good'], 0.91);
    expect(report.humanLabels.containsKey('shot-unknown'), isFalse);
    final unknown = report.findings.singleWhere(
      (f) => f.subjectId == 'shot-unknown',
    );
    expect(unknown.status, QaStatus.unknown);
    expect(unknown.status, isNot(QaStatus.pass));
    expect(unknown.reasonCode, 'uncalibrated-model-score');
    expect(report.unknownAutoPassed, isFalse);
    expect(report.uncalibratedModelAutoReleased, isFalse);
    expect(report.llmJudgeIsSoleTruth, isFalse);
    expect(report.precisionRecallClaimed, isFalse);
    expect(report.submitted, isFalse);
    expect(report.documentWrites, 0);

    expect(
      () => compiler.evaluate([
        QaSubject(
          id: 'shot-llm',
          dimension: QaDimension.story,
          llmJudgeIsSoleTruth: true,
        ),
      ]),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
  });

  test('the repair oracle does not regenerate already-passed shots or cover locked segments, returns NeedsReview on a lock intersection, and does not submit or start paid generation', () {
    final compiler = QaBaselineCompiler();
    final findings = compiler.evaluate([
      QaSubject(
        id: 'shot-pass',
        dimension: QaDimension.identity,
        humanLabel: QaStatus.pass,
        alreadyPassed: true,
      ),
      QaSubject(
        id: 'shot-fail',
        dimension: QaDimension.caption,
        humanLabel: QaStatus.fail,
        lockedFields: const ['caption'],
        severity: QaSeverity.hard,
      ),
    ]).findings;
    final plan = compiler.propose(
      RepairRequest(
        findings: findings,
        lockedWriteSet: const ['caption', 'shot-fail'],
        alreadyPassedShotIds: const ['shot-pass'],
        remainingBudgetMicros: 0,
      ),
    );
    expect(plan.passedShotsRegenerated, 0);
    expect(plan.preserveIds, contains('shot-pass'));
    expect(plan.targetNodeIds, isNot(contains('shot-pass')));
    expect(plan.lockedSegmentCoverage, 0);
    expect(plan.lockedCaptionRewritten, isFalse);
    expect(plan.needsReview, isTrue);
    expect(plan.submitted, isFalse);
    expect(plan.paidGenerationStarted, isFalse);
    expect(plan.documentWrites, 0);
    expect(compiler.documentWrites, 0);
  });

  test('OCR-only picture claims, missing video understanding, and unconnected lip-sync stay unknown; unregistered effects and unapproved paid repair are refused; hard rules are not lowered', () {
    final compiler = QaBaselineCompiler();
    final report = compiler.evaluate([
      QaSubject(
        id: 'shot-ocr',
        dimension: QaDimension.sku,
        ocrOnlyPictureClaim: true,
        severity: QaSeverity.hard,
      ),
      QaSubject(
        id: 'shot-motion',
        dimension: QaDimension.motion,
        hasVideoUnderstanding: false,
        modelScore: 0.99,
        severity: QaSeverity.hard,
      ),
      QaSubject(
        id: 'shot-av',
        dimension: QaDimension.av,
        lipSyncConnected: false,
        modelScore: 0.99,
        severity: QaSeverity.hard,
      ),
    ]);
    expect(
      report.findings.every(
        (f) => f.status == QaStatus.unknown && f.score == null,
      ),
      isTrue,
    );
    expect(report.factOrSafetyRuleLowered, isFalse);
    expect(report.precisionRecallClaimed, isFalse);

    expect(
      () => compiler.evaluate([
        QaSubject(
          id: 'shot-fx',
          dimension: QaDimension.semantic,
          unregisteredEffect: true,
        ),
      ]),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => compiler.propose(
        RepairRequest(
          findings: [
            QaFinding(
              id: 'finding-fail',
              subjectId: 'shot-fail',
              dimension: QaDimension.story,
              mode: QaMode.human,
              status: QaStatus.fail,
              severity: QaSeverity.hard,
            ),
          ],
          remainingBudgetMicros: 1000,
          approvedPaidQuote: false,
        ),
      ),
      code('APPROVAL_REQUIRED'),
    );
    expect(
      () => compiler.propose(
        RepairRequest(findings: report.findings, repairRound: 3),
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(compiler.documentWrites, 0);
  });
}
