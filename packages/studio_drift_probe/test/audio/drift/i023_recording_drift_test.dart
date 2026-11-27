import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_drift_probe/studio_drift_probe.dart';
import 'package:test/test.dart';

/// Increment 2.85 official s4 leftover: recording drift is corrected
/// only by an explicit resample that records a mapping and does not
/// overwrite the original; a manual sync offset is applied only after
/// confirmation. This file does not invent a waveform correlator or
/// tracker, does not re-qualify Increment 2.80 media retention,
/// Increment 2.84 VFR audio-duration admission, Increment 2.83
/// varispeed-and-pitch admission, or I-021 seek/VFR/PTS suites, and
/// does not claim a 1-frame or 20ms A/V measurement. InversePatch
/// kind stays restoreSnapshot. Project user_version stays 9. I-023
/// stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('explicit resample records a map and retains the original; silent overwrite or resample is refused', () {
    final admission = RecordingDriftAdmission();
    final receipt = admission.admitDrift(
      const RecordingDriftRequest(
        explicitResample: true,
        mapRecorded: true,
        originalRetained: true,
      ),
    );
    expect(receipt.originalRetained, isTrue);
    expect(receipt.mapRecorded, isTrue);
    expect(
      () => admission.admitDrift(
        const RecordingDriftRequest(
          explicitResample: false,
          mapRecorded: false,
          originalRetained: false,
          overwriteOriginal: true,
        ),
      ),
      code('DRIFT_MUST_BE_EXPLICIT'),
    );
    expect(
      () => admission.admitDrift(
        const RecordingDriftRequest(
          explicitResample: true,
          mapRecorded: true,
          originalRetained: false,
        ),
      ),
      code('ORIGINAL_RECORDING_NOT_RETAINED'),
    );
  });

  test('an explicit resample without a recorded map is refused; a manual sync offset applies only after confirmation', () {
    final admission = RecordingDriftAdmission();
    expect(
      () => admission.admitDrift(
        const RecordingDriftRequest(
          explicitResample: true,
          mapRecorded: false,
          originalRetained: true,
        ),
      ),
      code('DRIFT_MAP_REQUIRED'),
    );
    expect(
      () => admission.admitSync(
        const ManualSyncRequest(offsetTicks: 480, confirmed: false),
      ),
      code('SYNC_CONFIRMATION_REQUIRED'),
    );
    final sync = admission.admitSync(
      const ManualSyncRequest(offsetTicks: 480, confirmed: true),
    );
    expect(sync.applied, isTrue);
    expect(sync.offsetTicks, 480);
  });

  test('a waveform correlator, Increment 2.80 media retention, and related leftovers stay closed', () {
    final admission = RecordingDriftAdmission();
    expect(admission.correlatorInvented, isFalse);
    expect(admission.trackerInvented, isFalse);
    expect(admission.mediaRetentionRequalified, isFalse);
    expect(admission.vfrAudioRequalified, isFalse);
    expect(admission.varispeedRequalified, isFalse);
    expect(admission.timeStretchInvented, isFalse);
    expect(admission.limiterInvented, isFalse);
    expect(admission.pcmRemapInvented, isFalse);
    expect(admission.oneFrameClaimed, isFalse);
    expect(admission.twentyMsClaimed, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
