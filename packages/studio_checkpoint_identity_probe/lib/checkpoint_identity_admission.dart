import 'package:studio_contracts/studio_contracts.dart';

final class CheckpointIdentityRequest {
  const CheckpointIdentityRequest({
    this.claimsSqliteWalCheckpoint = false,
    this.recopiesMedia = false,
    this.checkpointRevisionLagsHead = false,
    this.claimsEditsUnsavedBecauseCheckpointLags = false,
  });

  /// The product recovery checkpoint is being treated as
  /// `PRAGMA wal_checkpoint` / a SQLite WAL checkpoint.
  final bool claimsSqliteWalCheckpoint;
  final bool recopiesMedia;
  final bool checkpointRevisionLagsHead;
  final bool claimsEditsUnsavedBecauseCheckpointLags;
}

final class CheckpointIdentityReceipt {
  const CheckpointIdentityReceipt({
    required this.admitted,
    required this.isSqliteWalCheckpoint,
    required this.mediaRecopied,
    required this.lagMeansUnsaved,
  });

  final bool admitted;
  final bool isSqliteWalCheckpoint;
  final bool mediaRecopied;
  final bool lagMeansUnsaved;
}

/// DEV-PURE I-012 / s5b admission: a product recovery checkpoint is not
/// a SQLite WAL checkpoint and must not recopy media. A lagging
/// `checkpointRevision` does not mean those edits are unsaved.
///
/// This is not a re-qualification of ADR 0003 managed checkpoints,
/// Increment 3.07 CloseCheckpointAdmission, Increment 3.10
/// ExplicitSaveAdmission, ADR 0097 durableRevision, or ADR 0098. SQLite
/// WAL recovery remains as already recorded in ADR 0003 and is not
/// disabled here. A WAL-checkpoint runtime, an I-014 RestoreService,
/// and a Flutter widget tree are not invented.
final class CheckpointIdentityAdmission {
  bool adr0003Requalified = false;
  bool closeCheckpointRequalified = false;
  bool explicitSaveRequalified = false;
  bool packageAutoUpdateRequalified = false;
  bool i011DurableRevisionRequalified = false;
  bool i011CrashRequalified = false;
  bool walCheckpointRuntimeInvented = false;
  bool i014RestoreInvented = false;
  bool flutterWidgetTreeInvented = false;

  CheckpointIdentityReceipt admit(CheckpointIdentityRequest request) {
    if (request.claimsSqliteWalCheckpoint) {
      throw const StudioException('CHECKPOINT_IS_NOT_WAL', 'checkpoint');
    }
    if (request.recopiesMedia) {
      throw const StudioException(
        'CHECKPOINT_MEDIA_RECOPY_FORBIDDEN',
        'checkpoint',
      );
    }
    if (request.claimsEditsUnsavedBecauseCheckpointLags) {
      throw const StudioException('CHECKPOINT_LAG_NOT_UNSAVED', 'checkpoint');
    }
    return const CheckpointIdentityReceipt(
      admitted: true,
      isSqliteWalCheckpoint: false,
      mediaRecopied: false,
      lagMeansUnsaved: false,
    );
  }
}
