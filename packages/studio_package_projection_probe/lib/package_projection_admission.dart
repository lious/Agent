import 'package:studio_contracts/studio_contracts.dart';

const packageProjectionKinds = {'modelsReferences', 'index', 'thumbnail'};

final class PackageProjectionRequest {
  const PackageProjectionRequest({
    required this.kind,
    this.matchesSnapshot = true,
    this.overwriteSnapshotBody = false,
  });

  /// `modelsReferences`, `index`, or `thumbnail`.
  final String kind;
  final bool matchesSnapshot;
  final bool overwriteSnapshotBody;
}

final class PackageProjectionReceipt {
  const PackageProjectionReceipt({
    required this.admitted,
    required this.projectionIsNotTruth,
    required this.snapshotBodyPreserved,
  });

  final bool admitted;
  final bool projectionIsNotTruth;
  final bool snapshotBodyPreserved;
}

/// DEV-PURE I-013 / s5c admission: models/references, index, and
/// thumbnail are snapshot projections, not a second source of truth.
/// A mismatch with the real snapshot must fail rebuild, and a
/// projection must not overwrite the snapshot body.
///
/// This does not re-qualify Increment 2.50 packMode /
/// sourceCompleteness, Increment 3.06 ArtifactKindAdmission,
/// `MANIFEST_SNAPSHOT_MISMATCH`, or “missing models must not
/// auto-download.” The PENDING_MEDIA / RESOURCE_MISSING “do not
/// mislabel a complete archive or final render” half of the same
/// s5c row is not officialized here. Job archival, a muxer, and an
/// I-014 RestoreService are not invented.
final class PackageProjectionAdmission {
  bool packModeRequalified = false;
  bool artifactKindRequalified = false;
  bool manifestSnapshotMismatchRequalified = false;
  bool modelsAutoDownloadRequalified = false;
  bool pendingMediaCompleteArchiveRequalified = false;
  bool webPublicationRequalified = false;
  bool jobArchivalInvented = false;
  bool muxerInvented = false;
  bool restoreInvented = false;
  bool flutterWidgetTreeInvented = false;

  PackageProjectionReceipt admit(PackageProjectionRequest request) {
    if (!packageProjectionKinds.contains(request.kind)) {
      throw const StudioException(
        'PACKAGE_PROJECTION_KIND_UNKNOWN',
        'publication',
      );
    }
    if (!request.matchesSnapshot) {
      throw const StudioException('PACKAGE_PROJECTION_MISMATCH', 'publication');
    }
    if (request.overwriteSnapshotBody) {
      throw const StudioException(
        'SNAPSHOT_BODY_OVERWRITE_FORBIDDEN',
        'publication',
      );
    }
    return const PackageProjectionReceipt(
      admitted: true,
      projectionIsNotTruth: true,
      snapshotBodyPreserved: true,
    );
  }
}
