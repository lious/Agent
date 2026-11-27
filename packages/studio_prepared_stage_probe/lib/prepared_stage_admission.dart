import 'package:studio_contracts/studio_contracts.dart';

final class PreparedStageRequest {
  const PreparedStageRequest({
    this.preparedStage = false,
    this.holdsLongSqliteWriteTransaction = false,
  });

  /// The save path is in its prepared stage.
  final bool preparedStage;
  final bool holdsLongSqliteWriteTransaction;
}

final class PreparedStageReceipt {
  const PreparedStageReceipt({
    required this.admitted,
    required this.sqliteWriteHeldLong,
  });

  final bool admitted;
  final bool sqliteWriteHeldLong;
}

/// DEV-PURE I-003 / s5b admission: the save prepared stage must not
/// hold a long SQLite write transaction.
///
/// This is a leftover fencing clause after Increment 3.09, not a
/// re-qualification of WriterFenceAdmission, Increment 3.08
/// SqlCloudSideEffectAdmission, or I-003 revision tests. An OS lock
/// runtime, crash takeover, pending-publication reconciliation, and a
/// publish-path serial coordinator are not invented. The leftover
/// “different apps do not share a private workspace” / App Group
/// clause is not officialized here. I-003 namespace-isolation labels
/// are not cleared.
final class PreparedStageAdmission {
  bool writerFenceRequalified = false;
  bool sqlCloudSideEffectRequalified = false;
  bool checkpointIdentityRequalified = false;
  bool i003RevisionTestsRewritten = false;
  bool i011CrashRequalified = false;
  bool osLockRuntimeInvented = false;
  bool crashTakeoverOfficialized = false;
  bool coordinatorInvented = false;
  bool appGroupShareOfficialized = false;
  bool i032PlanGraphFenceRequalified = false;

  PreparedStageReceipt admit(PreparedStageRequest request) {
    if (!request.preparedStage) {
      throw const StudioException('PREPARED_STAGE_REQUIRED', 'save');
    }
    if (request.holdsLongSqliteWriteTransaction) {
      throw const StudioException(
        'PREPARED_STAGE_LONG_WRITE_FORBIDDEN',
        'save',
      );
    }
    return const PreparedStageReceipt(
      admitted: true,
      sqliteWriteHeldLong: false,
    );
  }
}
