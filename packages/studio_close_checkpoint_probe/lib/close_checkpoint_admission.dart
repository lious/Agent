import 'package:studio_contracts/studio_contracts.dart';

const closeCheckpointTriggers = {
  'background',
  'projectSwitch',
  'close',
  'desktopExit',
  'mobileOsExpiry',
};

final class CloseCheckpointRequest {
  const CloseCheckpointRequest({
    required this.trigger,
    this.checkpointRequestedImmediately = false,
    this.waitsForLongGeneration = false,
    this.waitsForZip = false,
    this.externalPackageUnfinished = false,
    this.claimsExternalFileWritten = false,
    this.localRecoveryPointRetained = false,
    this.unboundedBackgroundTask = false,
  });

  /// `background`, `projectSwitch`, `close`, `desktopExit`, or `mobileOsExpiry`.
  final String trigger;
  final bool checkpointRequestedImmediately;
  final bool waitsForLongGeneration;
  final bool waitsForZip;
  final bool externalPackageUnfinished;
  final bool claimsExternalFileWritten;
  final bool localRecoveryPointRetained;
  final bool unboundedBackgroundTask;
}

final class CloseCheckpointReceipt {
  const CloseCheckpointReceipt({
    required this.checkpointRequested,
    required this.externalFileWritten,
    required this.localRecoveryPointRetained,
  });

  final bool checkpointRequested;
  final bool externalFileWritten;
  final bool localRecoveryPointRetained;
}

/// DEV-PURE I-012 / s5b admission: background, project-switch, or close
/// must request a checkpoint immediately and must not wait for a long
/// generation or a ZIP. An unfinished external package must not be
/// claimed as written; a desktop exit keeps the local recovery point.
/// A mobile OS expiry may promise only work that already has a local
/// ACK, not an unbounded background task.
///
/// This is not a re-qualification of Increment 3.05
/// PackageAutoUpdateAdmission, Increment 3.06 ArtifactKindAdmission,
/// ADR 0098 I-012 leftovers, or ADR 0028 gesture cancel. A SAF or
/// iCloud adapter, a Flutter widget tree, and I-013 job archival are
/// not invented. The 30s/120s s5b figures are not claimed as a
/// measured qualification.
final class CloseCheckpointAdmission {
  bool packageAutoUpdateRequalified = false;
  bool artifactKindRequalified = false;
  bool i012UserSavedRevisionRequalified = false;
  bool gestureCancelRequalified = false;
  bool safIcloudInvented = false;
  bool flutterWidgetTreeInvented = false;
  bool v005QualificationClaimed = false;
  bool jobArchivalInvented = false;
  bool muxerInvented = false;
  bool i014RestoreInvented = false;

  CloseCheckpointReceipt admit(CloseCheckpointRequest request) {
    if (!closeCheckpointTriggers.contains(request.trigger)) {
      throw const StudioException('CLOSE_TRIGGER_UNKNOWN', 'save');
    }
    if (request.waitsForLongGeneration || request.waitsForZip) {
      throw const StudioException('CLOSE_MUST_NOT_WAIT', 'save');
    }
    if (!request.checkpointRequestedImmediately) {
      throw const StudioException('CHECKPOINT_REQUIRED_IMMEDIATELY', 'save');
    }
    if (request.claimsExternalFileWritten &&
        request.externalPackageUnfinished) {
      throw const StudioException('EXTERNAL_FILE_NOT_WRITTEN', 'save');
    }
    if (request.trigger == 'desktopExit' &&
        request.externalPackageUnfinished &&
        !request.localRecoveryPointRetained) {
      throw const StudioException('LOCAL_RECOVERY_POINT_REQUIRED', 'save');
    }
    if (request.trigger == 'mobileOsExpiry' &&
        request.unboundedBackgroundTask) {
      throw const StudioException(
        'UNBOUNDED_BACKGROUND_TASK_FORBIDDEN',
        'save',
      );
    }
    return CloseCheckpointReceipt(
      checkpointRequested: true,
      externalFileWritten: false,
      localRecoveryPointRetained:
          request.localRecoveryPointRetained ||
          !request.externalPackageUnfinished,
    );
  }
}
