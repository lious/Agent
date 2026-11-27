import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_archive_space_probe/studio_archive_space_probe.dart';
import 'package:test/test.dart';

/// Increment 3.20 official I-013 / s5d leftover: archive progress
/// must name a real phase, must not invent a percentage when total
/// bytes are unknown, must not double-count same-hash media in CAS
/// accounting, and must not assume a cross-volume rename.
///
/// This file does not re-qualify Increment 2.50 packMode,
/// Increment 3.06 ArtifactKindAdmission, Increment 3.18
/// PackageProjectionAdmission, I-013 “cancel with no half-published
/// package,” I-004 same-hash single blob, or I-042
/// `LEASE_DOUBLE_COUNT`. ENOSPC is not claimed. A ZipPlanner, a
/// muxer, and an I-014 RestoreService are not invented.
/// InversePatch kind stays restoreSnapshot. Project user_version
/// stays 9. I-013 stays partial. Existing I-013 remainingAcceptance
/// wording is not silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('archive progress must not invent a percent when total bytes are unknown, double-count same-hash CAS media, or assume a cross-volume rename', () {
    final admission = ArchiveSpaceAdmission();
    for (final phase in const [
      'scan',
      'collect',
      'write',
      'verify',
      'publish',
    ]) {
      final receipt = admission.admit(ArchiveSpaceRequest(phase: phase));
      expect(receipt.admitted, isTrue);
      expect(receipt.inventsPercent, isFalse);
      expect(receipt.sameHashCountedOnce, isTrue);
      expect(receipt.crossVolumeRenameAssumed, isFalse);
    }
    final knownPercent = admission.admit(
      const ArchiveSpaceRequest(
        phase: 'write',
        totalBytesKnown: true,
        reportsPercent: true,
      ),
    );
    expect(knownPercent.admitted, isTrue);
    expect(knownPercent.inventsPercent, isFalse);
    expect(
      () => admission.admit(const ArchiveSpaceRequest(phase: 'unknown')),
      code('ARCHIVE_PROGRESS_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const ArchiveSpaceRequest(
          phase: 'write',
          totalBytesKnown: false,
          reportsPercent: true,
        ),
      ),
      code('UNKNOWN_BYTES_PERCENT_FORBIDDEN'),
    );
    expect(
      () => admission.admit(
        const ArchiveSpaceRequest(
          phase: 'collect',
          doubleCountsSameHashCas: true,
        ),
      ),
      code('CAS_HASH_DOUBLE_COUNT_FORBIDDEN'),
    );
    expect(
      () => admission.admit(
        const ArchiveSpaceRequest(
          phase: 'publish',
          assumesCrossVolumeRename: true,
        ),
      ),
      code('CROSS_VOLUME_RENAME_NOT_ASSUMED'),
    );
  });

  test('Increment 2.50 packMode, cancel-no-half-package, I-004 same-hash, I-042 lease double-count, and ENOSPC stay closed', () {
    final admission = ArchiveSpaceAdmission();
    expect(admission.packModeRequalified, isFalse);
    expect(admission.artifactKindRequalified, isFalse);
    expect(admission.packageProjectionRequalified, isFalse);
    expect(admission.cancelHalfPackageRequalified, isFalse);
    expect(admission.uniqueCopyRequalified, isFalse);
    expect(admission.i004SameHashRequalified, isFalse);
    expect(admission.leaseDoubleCountRequalified, isFalse);
    expect(admission.enospcClaimed, isFalse);
    expect(admission.zipPlannerInvented, isFalse);
    expect(admission.muxerInvented, isFalse);
    expect(admission.jobArchivalInvented, isFalse);
    expect(admission.storagePortInvented, isFalse);
    expect(admission.restoreInvented, isFalse);
    expect(admission.saveAsRequalified, isFalse);
  });
}
