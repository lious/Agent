import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_sql_cloud_side_effect_probe/studio_sql_cloud_side_effect_probe.dart';
import 'package:test/test.dart';

/// Increment 3.08 official I-003 / s5b leftover: a workspace SQLite
/// commit transaction must not start a cloud side effect.
///
/// This file does not re-qualify Increment 3.07
/// CloseCheckpointAdmission, Increment 3.05
/// PackageAutoUpdateAdmission, Increment 3.06 ArtifactKindAdmission,
/// ADR 0098 I-012 leftovers, I-003 revision tests, I-033 quote/apply,
/// I-040 generated output, or I-011 crash leftovers. Quote/apply, paid
/// generation, and a WorkflowCoordinator are not started. InversePatch
/// kind stays restoreSnapshot. Project user_version stays 9. I-003
/// stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a local SQLite commit is acknowledged only when it starts no cloud side effect', () {
    final admission = SqlCloudSideEffectAdmission();
    final receipt = admission.admit(const LocalCommitRequest());
    expect(receipt.acknowledged, isTrue);
    expect(receipt.cloudSideEffectStarted, isFalse);
  });

  test('starting a cloud side effect inside the SQL commit is refused', () {
    final admission = SqlCloudSideEffectAdmission();
    expect(
      () => admission.admit(
        const LocalCommitRequest(startsCloudSideEffect: true),
      ),
      code('SQL_CLOUD_SIDE_EFFECT_FORBIDDEN'),
    );
  });

  test('Increment 3.07 close-checkpoint work, I-003 revision tests, quote/apply, I-040, and I-011 crash leftovers stay closed', () {
    final admission = SqlCloudSideEffectAdmission();
    expect(admission.closeCheckpointRequalified, isFalse);
    expect(admission.packageAutoUpdateRequalified, isFalse);
    expect(admission.artifactKindRequalified, isFalse);
    expect(admission.i003RevisionTestsRewritten, isFalse);
    expect(admission.i033Requalified, isFalse);
    expect(admission.i040Requalified, isFalse);
    expect(admission.i011CrashRequalified, isFalse);
    expect(admission.quoteApplyStarted, isFalse);
    expect(admission.paidGenerationStarted, isFalse);
    expect(admission.workflowCoordinatorInvented, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
