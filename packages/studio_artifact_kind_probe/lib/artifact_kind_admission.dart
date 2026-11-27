import 'package:studio_contracts/studio_contracts.dart';

const artifactKinds = {
  'backup',
  'logicalArchive',
  'portableArchive',
  'finishedExport',
  'sync',
};

final class ArtifactKindRequest {
  const ArtifactKindRequest({
    required this.kind,
    this.usedAsEditableProject = false,
    this.providerWritten = false,
    this.remoteDeviceAck = false,
    this.claimedDeviceSynced = false,
  });

  /// `backup`, `logicalArchive`, `portableArchive`, `finishedExport`, or `sync`.
  final String kind;
  final bool usedAsEditableProject;
  final bool providerWritten;
  final bool remoteDeviceAck;
  final bool claimedDeviceSynced;
}

final class ArtifactKindReceipt {
  const ArtifactKindReceipt({required this.kind, required this.deviceSynced});

  final String kind;
  final bool deviceSynced;
}

/// DEV-PURE I-013 / s5b admission: backup, logical archive, portable
/// archive, finished export, and sync are distinct artifacts. A
/// finished export is a render result and must not stand in for an
/// editable project. A provider-written receipt is not a remote
/// device sync acknowledgment.
///
/// This is not I-013 job archival, not a rewrite of Increment 2.50
/// packMode, Increment 2.86 ProxyDeliveryAdmission, Increment 3.05
/// PackageAutoUpdateAdmission, or official I-024 export suites, and
/// not an I-014 RestoreService. A muxer and `packMode=proxyOnly` are
/// not invented.
final class ArtifactKindAdmission {
  bool jobArchivalInvented = false;
  bool packModeRewritten = false;
  bool proxyDeliveryRequalified = false;
  bool packageAutoUpdateRequalified = false;
  bool i024ExportRequalified = false;
  bool i014RestoreInvented = false;
  bool muxerInvented = false;
  bool proxyOnlyPackModeInvented = false;
  bool safIcloudInvented = false;

  ArtifactKindReceipt admit(ArtifactKindRequest request) {
    if (!artifactKinds.contains(request.kind)) {
      throw const StudioException('ARTIFACT_KIND_UNKNOWN', 'artifact');
    }
    if (request.kind == 'finishedExport' && request.usedAsEditableProject) {
      throw const StudioException('EXPORT_NOT_EDITABLE_PROJECT', 'artifact');
    }
    if (request.claimedDeviceSynced &&
        (request.kind != 'sync' || !request.remoteDeviceAck)) {
      throw const StudioException('PROVIDER_WRITTEN_NOT_SYNCED', 'artifact');
    }
    return ArtifactKindReceipt(
      kind: request.kind,
      deviceSynced: request.kind == 'sync' && request.remoteDeviceAck,
    );
  }
}
