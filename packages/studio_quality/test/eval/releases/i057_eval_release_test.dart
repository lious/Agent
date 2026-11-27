import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_quality/studio_quality.dart';
import 'package:test/test.dart';

/// Increment 2.60 official first I-057 slice: EvalRunner privilege,
/// AB-consent, unknown-score, rollback, and no-training-improvement
/// refusals. This file does not rewrite I-037 CraftSkillCompiler or
/// I-038 Prompt compilers, does not invent skill training, does not
/// claim a model improvement, does not start signed-pack import, does
/// not start I-035 or claim a V-020 precision/recall or eval-baseline
/// achievement, does not re-qualify I-056, I-054, I-029, I-053, or
/// I-033 leftovers, and does not mark I-037, I-038, V-007, V-020,
/// I-054, I-051, I-046, I-041, I-040, I-053, or I-056 complete.
/// InversePatch kind stays restoreSnapshot. Project user_version
/// stays 9.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

RegistryPin pin(String hash) =>
    RegistryPin(id: 'craft.demo', semver: '1.0.0', contentHash: hash);

EvalRunner runner() => EvalRunner(
  activePin: pin('hash-active'),
  projectSkillPin: pin('hash-active'),
  inFlightPin: pin('hash-active'),
  artifactPin: pin('hash-active'),
  installedAllowlist: const ['trim'],
);

void main() {
  test('a production pack cannot self-escalate privilege, a model proposal stays a candidate, and self-heal install is refused', () {
    final eval = runner();
    final proposed = eval.acceptCandidate(
      ReleaseCandidate(pin: pin('hash-cand'), producedByModel: true),
    );
    expect(proposed.pin.contentHash, 'hash-cand');
    expect(eval.activePin.contentHash, 'hash-active');
    expect(eval.documentWrites, 0);

    expect(
      () => eval.promote(ReleaseCandidate(pin: pin('hash-cand'))),
      code('TOOL_NOT_ALLOWED'),
    );
    expect(
      () => eval.acceptCandidate(
        ReleaseCandidate(
          pin: pin('hash-cand'),
          requestsPrivilegeEscalation: true,
        ),
      ),
      code('TOOL_NOT_ALLOWED'),
    );
    expect(
      () => eval.acceptCandidate(
        ReleaseCandidate(pin: pin('hash-cand'), requestsUploadBypass: true),
      ),
      code('TOOL_NOT_ALLOWED'),
    );
    expect(
      () => eval.acceptCandidate(
        ReleaseCandidate(pin: pin('hash-cand'), requestsPaymentBypass: true),
      ),
      code('TOOL_NOT_ALLOWED'),
    );
    expect(
      () => eval.acceptCandidate(
        ReleaseCandidate(pin: pin('hash-cand'), requestsExtraMedia: true),
      ),
      code('TOOL_NOT_ALLOWED'),
    );
    expect(
      () => eval.acceptCandidate(
        ReleaseCandidate(
          pin: pin('hash-cand'),
          requestsSelfDeployTraining: true,
        ),
      ),
      code('TOOL_NOT_ALLOWED'),
    );
    expect(
      () => eval.acceptCandidate(
        ReleaseCandidate(pin: pin('hash-cand'), requestsProjectWrite: true),
      ),
      code('TOOL_NOT_ALLOWED'),
    );
    expect(
      () => eval.acceptCandidate(
        ReleaseCandidate(pin: pin('hash-cand'), requestsSelfHealInstall: true),
      ),
      code('TOOL_NOT_ALLOWED'),
    );
    expect(
      () => eval.acceptCandidate(
        ReleaseCandidate(
          pin: pin('hash-cand'),
          requestedTools: const ['secret.tool'],
        ),
      ),
      code('TOOL_NOT_ALLOWED'),
    );
    expect(eval.paidApiCalled, isFalse);
    expect(eval.submitted, isFalse);
  });

  test('user content is not enrolled in AB or training without research, upload, and fee consent; purchase consent does not substitute', () {
    final eval = runner();
    expect(
      () => eval.enrollAb(
        const AbEnrollment(
          isUserContent: true,
          unitId: 'session-1',
          purchaseConsent: true,
        ),
      ),
      code('RESEARCH_CONSENT_REQUIRED'),
    );
    expect(
      () => eval.enrollAb(
        const AbEnrollment(
          isUserContent: true,
          unitId: 'session-1',
          researchConsent: true,
        ),
      ),
      code('UPLOAD_CONSENT_REQUIRED'),
    );
    expect(
      () => eval.enrollAb(
        const AbEnrollment(
          isUserContent: true,
          unitId: 'session-1',
          researchConsent: true,
          uploadConsent: true,
        ),
      ),
      code('APPROVAL_REQUIRED'),
    );
    expect(eval.enrolledUserUnits, 0);
    expect(
      eval.enrollAb(
        const AbEnrollment(isUserContent: false, unitId: 'fixture-1'),
      ),
      1,
    );
    final exported = eval.exportAssignment(unitId: 'session-1');
    expect(exported.containsKey('userId'), isFalse);
    expect(exported['unitId'], 'session-1');
    expect(eval.trainingExecuted, isFalse);
    expect(eval.sftStarted, isFalse);
    expect(eval.dpoStarted, isFalse);
    expect(eval.rlhfStarted, isFalse);
  });

  test('unknown or insufficient scores do not win; rollback keeps the project skill pin; improvement is not claimed without training', () {
    final eval = runner();
    expect(
      eval
          .decideWinner(
            const EvalScore(result: EvalResult.unknown, sampleSize: 20),
          )
          .result,
      EvalResult.inconclusive,
    );
    expect(
      eval
          .decideWinner(
            const EvalScore(
              result: EvalResult.pass,
              sampleSize: 2,
              minSampleSize: 10,
            ),
          )
          .modelQualityWin,
      isFalse,
    );
    expect(
      eval
          .decideWinner(
            const EvalScore(
              result: EvalResult.pass,
              sampleSize: 10,
              offlineOraclePassed: true,
            ),
          )
          .modelQualityWin,
      isFalse,
    );
    expect(
      () => eval.decideWinner(
        const EvalScore(
          result: EvalResult.pass,
          sampleSize: 10,
          postHocMetric: true,
        ),
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );

    final rolled = eval.rollback(pin('hash-previous'));
    expect(rolled.newRunDefaultPin.contentHash, 'hash-previous');
    expect(rolled.projectSkillPin.contentHash, 'hash-active');
    expect(rolled.inFlightPin.contentHash, 'hash-active');
    expect(rolled.artifactPin.contentHash, 'hash-active');
    expect(eval.projectSkillPin.contentHash, 'hash-active');
    expect(() => eval.hotSwapInFlightPrompt(), code('FIELD_LOCKED'));
    expect(
      () => eval.claimImprovement(trainingRan: false),
      code('TRAINING_NOT_EXECUTED'),
    );
    expect(eval.modelImprovementClaimed, isFalse);
    expect(eval.trainingExecuted, isFalse);
    expect(eval.v020EvalBaselineClaimed, isFalse);
    expect(eval.documentWrites, 0);
  });
}
