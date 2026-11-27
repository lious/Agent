import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_package_projection_probe/studio_package_projection_probe.dart';
import 'package:test/test.dart';

/// Increment 3.18 official I-013 / s5c leftover: models/references,
/// index, and thumbnail are snapshot projections, not a second
/// source of truth. A mismatch with the real snapshot must fail
/// rebuild, and a projection must not overwrite the snapshot body.
///
/// This file does not re-qualify Increment 2.50 packMode,
/// Increment 3.06 ArtifactKindAdmission, or
/// `MANIFEST_SNAPSHOT_MISMATCH`. The PENDING_MEDIA /
/// RESOURCE_MISSING complete-archive sentence is not officialized
/// here. Job archival, a muxer, and an I-014 RestoreService are
/// not invented. InversePatch kind stays restoreSnapshot. Project
/// user_version stays 9. I-013 stays partial. Existing I-013
/// remainingAcceptance wording is not silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a matching projection is not a second source of truth and must not overwrite the snapshot body', () {
    final admission = PackageProjectionAdmission();
    for (final kind in const ['modelsReferences', 'index', 'thumbnail']) {
      final receipt = admission.admit(PackageProjectionRequest(kind: kind));
      expect(receipt.admitted, isTrue);
      expect(receipt.projectionIsNotTruth, isTrue);
      expect(receipt.snapshotBodyPreserved, isTrue);
    }
    expect(
      () => admission.admit(const PackageProjectionRequest(kind: 'unknown')),
      code('PACKAGE_PROJECTION_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const PackageProjectionRequest(kind: 'index', matchesSnapshot: false),
      ),
      code('PACKAGE_PROJECTION_MISMATCH'),
    );
    expect(
      () => admission.admit(
        const PackageProjectionRequest(
          kind: 'thumbnail',
          overwriteSnapshotBody: true,
        ),
      ),
      code('SNAPSHOT_BODY_OVERWRITE_FORBIDDEN'),
    );
  });

  test('Increment 2.50 packMode, ArtifactKindAdmission, MANIFEST_SNAPSHOT_MISMATCH, and job archival stay closed', () {
    final admission = PackageProjectionAdmission();
    expect(admission.packModeRequalified, isFalse);
    expect(admission.artifactKindRequalified, isFalse);
    expect(admission.manifestSnapshotMismatchRequalified, isFalse);
    expect(admission.modelsAutoDownloadRequalified, isFalse);
    expect(admission.pendingMediaCompleteArchiveRequalified, isFalse);
    expect(admission.webPublicationRequalified, isFalse);
    expect(admission.jobArchivalInvented, isFalse);
    expect(admission.muxerInvented, isFalse);
    expect(admission.restoreInvented, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
  });
}
