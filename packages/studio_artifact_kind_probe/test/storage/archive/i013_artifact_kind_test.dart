import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_artifact_kind_probe/studio_artifact_kind_probe.dart';
import 'package:test/test.dart';

/// Increment 3.06 official I-013 / s5b leftover: backup, logical
/// archive, portable archive, finished export, and sync are distinct
/// artifacts. A finished export must not stand in for an editable
/// project. A provider-written receipt is not a remote device sync
/// acknowledgment.
///
/// This file does not invent I-013 job archival, a muxer, or
/// packMode=proxyOnly, and does not re-qualify Increment 2.50
/// packMode, Increment 2.86 ProxyDeliveryAdmission, Increment 3.05
/// PackageAutoUpdateAdmission, official I-024 export suites, or an
/// I-014 RestoreService. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9. I-013 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('backup, logical archive, portable archive, finished export, and sync are admitted as distinct artifacts; only a sync with a remote ACK is device-synced', () {
    final admission = ArtifactKindAdmission();
    for (final kind in artifactKinds) {
      final receipt = admission.admit(
        ArtifactKindRequest(kind: kind, remoteDeviceAck: kind == 'sync'),
      );
      expect(receipt.kind, kind);
      expect(receipt.deviceSynced, kind == 'sync');
    }
  });

  test('a finished export must not stand in for an editable project; a provider-written receipt without a remote ACK is not a device sync', () {
    final admission = ArtifactKindAdmission();
    expect(
      () => admission.admit(
        const ArtifactKindRequest(
          kind: 'finishedExport',
          usedAsEditableProject: true,
        ),
      ),
      code('EXPORT_NOT_EDITABLE_PROJECT'),
    );
    expect(
      () => admission.admit(
        const ArtifactKindRequest(
          kind: 'sync',
          providerWritten: true,
          claimedDeviceSynced: true,
        ),
      ),
      code('PROVIDER_WRITTEN_NOT_SYNCED'),
    );
    expect(
      () => admission.admit(const ArtifactKindRequest(kind: 'snapshotZip')),
      code('ARTIFACT_KIND_UNKNOWN'),
    );
  });

  test('I-013 job archival, Increment 2.50 packMode, Increment 3.05 package auto-update, I-024 export suites, and an I-014 RestoreService stay closed', () {
    final admission = ArtifactKindAdmission();
    expect(admission.jobArchivalInvented, isFalse);
    expect(admission.packModeRewritten, isFalse);
    expect(admission.proxyDeliveryRequalified, isFalse);
    expect(admission.packageAutoUpdateRequalified, isFalse);
    expect(admission.i024ExportRequalified, isFalse);
    expect(admission.i014RestoreInvented, isFalse);
    expect(admission.muxerInvented, isFalse);
    expect(admission.proxyOnlyPackModeInvented, isFalse);
    expect(admission.safIcloudInvented, isFalse);
  });
}
