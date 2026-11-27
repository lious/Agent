import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_archive_countdown_probe/studio_archive_countdown_probe.dart';
import 'package:test/test.dart';

/// Increment 3.28 official I-013 / s5d leftover: an archive must
/// not start the project-deletion recycle-bin countdown.
///
/// This file does not re-qualify I-029 DeletionBarrier, Increment
/// 3.27 LibraryArchiveAdmission, Increment 3.06
/// ArtifactKindAdmission, or ADR 0016. A recycle-bin runtime is
/// not invented. The 30-day figure remains a design default and
/// is not claimed as a measured timer. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. I-013 stays
/// partial. Existing I-013 remainingAcceptance wording is not
/// silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test(
    'a library or portable archive must not start a recycle-bin countdown',
    () {
      final admission = ArchiveCountdownAdmission();
      for (final kind in const ['libraryArchive', 'portableArchive']) {
        final receipt = admission.admit(ArchiveCountdownRequest(kind: kind));
        expect(receipt.admitted, isTrue);
        expect(receipt.countdownStarted, isFalse);
      }

      expect(
        () => admission.admit(const ArchiveCountdownRequest(kind: 'unknown')),
        code('ARCHIVE_COUNTDOWN_KIND_UNKNOWN'),
      );
      expect(
        () => admission.admit(
          const ArchiveCountdownRequest(
            kind: 'libraryArchive',
            startsRecycleCountdown: true,
          ),
        ),
        code('ARCHIVE_COUNTDOWN_FORBIDDEN'),
      );
      expect(
        () => admission.admit(
          const ArchiveCountdownRequest(
            kind: 'portableArchive',
            startsRecycleCountdown: true,
          ),
        ),
        code('ARCHIVE_COUNTDOWN_FORBIDDEN'),
      );
    },
  );

  test('I-029 DeletionBarrier, Increment 3.27 LibraryArchiveAdmission, and a recycle-bin timer stay closed', () {
    final admission = ArchiveCountdownAdmission();
    expect(admission.deletionBarrierRequalified, isFalse);
    expect(admission.libraryArchiveRequalified, isFalse);
    expect(admission.artifactKindRequalified, isFalse);
    expect(admission.checkpointRetentionRequalified, isFalse);
    expect(admission.reachableBlobRetentionRequalified, isFalse);
    expect(admission.recycleBinInvented, isFalse);
    expect(admission.countdownTimerClaimed, isFalse);
    expect(admission.jobArchivalInvented, isFalse);
    expect(admission.restoreInvented, isFalse);
    expect(admission.archiveServiceInvented, isFalse);
  });
}
