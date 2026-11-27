import 'package:studio_contracts/studio_contracts.dart';

final class RecordingDriftRequest {
  const RecordingDriftRequest({
    required this.explicitResample,
    required this.mapRecorded,
    required this.originalRetained,
    this.overwriteOriginal = false,
  });

  final bool explicitResample, mapRecorded, originalRetained, overwriteOriginal;
}

final class ManualSyncRequest {
  const ManualSyncRequest({required this.offsetTicks, required this.confirmed});

  final int offsetTicks;
  final bool confirmed;
}

final class RecordingDriftReceipt {
  const RecordingDriftReceipt({
    required this.originalRetained,
    required this.mapRecorded,
  });

  final bool originalRetained, mapRecorded;
}

final class ManualSyncReceipt {
  const ManualSyncReceipt({required this.offsetTicks, required this.applied});

  final int offsetTicks;
  final bool applied;
}

/// DEV-PURE I-023 / s4 admission: recording drift is corrected only by an
/// explicit resample that records a mapping and does not overwrite the
/// original; a manual sync offset is applied only after confirmation.
/// This is not a waveform correlator, not a tracker, and not a
/// re-qualification of Increment 2.80 media retention
/// (`SOURCE_NOT_RETAINED` / `PTS_NOT_RETAINED`).
final class RecordingDriftAdmission {
  bool correlatorInvented = false;
  bool trackerInvented = false;
  bool mediaRetentionRequalified = false;
  bool vfrAudioRequalified = false;
  bool varispeedRequalified = false;
  bool timeStretchInvented = false;
  bool limiterInvented = false;
  bool pcmRemapInvented = false;
  bool oneFrameClaimed = false;
  bool twentyMsClaimed = false;
  bool paidApiCalled = false;

  RecordingDriftReceipt admitDrift(RecordingDriftRequest request) {
    if (!request.explicitResample) {
      throw const StudioException('DRIFT_MUST_BE_EXPLICIT', 'recording');
    }
    if (request.overwriteOriginal || !request.originalRetained) {
      throw const StudioException(
        'ORIGINAL_RECORDING_NOT_RETAINED',
        'recording',
      );
    }
    if (!request.mapRecorded) {
      throw const StudioException('DRIFT_MAP_REQUIRED', 'recording');
    }
    return const RecordingDriftReceipt(
      originalRetained: true,
      mapRecorded: true,
    );
  }

  ManualSyncReceipt admitSync(ManualSyncRequest request) {
    if (!request.confirmed) {
      throw const StudioException('SYNC_CONFIRMATION_REQUIRED', 'sync');
    }
    return ManualSyncReceipt(offsetTicks: request.offsetTicks, applied: true);
  }
}
