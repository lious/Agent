import 'package:studio_contracts/studio_contracts.dart';

final class LocalCommitRequest {
  const LocalCommitRequest({this.startsCloudSideEffect = false});

  /// A workspace SQLite commit must not start a cloud side effect.
  final bool startsCloudSideEffect;
}

final class LocalCommitReceipt {
  const LocalCommitReceipt({
    required this.acknowledged,
    required this.cloudSideEffectStarted,
  });

  final bool acknowledged;
  final bool cloudSideEffectStarted;
}

/// DEV-PURE I-003 / s5b admission: a workspace SQLite commit
/// transaction must not start a cloud side effect.
///
/// This is not a re-qualification of Increment 3.07
/// CloseCheckpointAdmission, Increment 3.05
/// PackageAutoUpdateAdmission, Increment 3.06 ArtifactKindAdmission,
/// ADR 0098 I-012 leftovers, I-003 revision tests, I-033 quote/apply,
/// I-040 generated output, or I-011 crash leftovers. Quote/apply, paid
/// generation, and a WorkflowCoordinator are not started. No paid API
/// is called.
final class SqlCloudSideEffectAdmission {
  bool closeCheckpointRequalified = false;
  bool packageAutoUpdateRequalified = false;
  bool artifactKindRequalified = false;
  bool i003RevisionTestsRewritten = false;
  bool i033Requalified = false;
  bool i040Requalified = false;
  bool i011CrashRequalified = false;
  bool quoteApplyStarted = false;
  bool paidGenerationStarted = false;
  bool workflowCoordinatorInvented = false;
  bool paidApiCalled = false;

  LocalCommitReceipt admit(LocalCommitRequest request) {
    if (request.startsCloudSideEffect) {
      throw const StudioException('SQL_CLOUD_SIDE_EFFECT_FORBIDDEN', 'commit');
    }
    return const LocalCommitReceipt(
      acknowledged: true,
      cloudSideEffectStarted: false,
    );
  }
}
