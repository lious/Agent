import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_history_availability_probe/studio_history_availability_probe.dart';
import 'package:test/test.dart';

/// Increment 3.26 official I-013 / s5a leftover: when history is
/// not selected, the package keeps only the current revision
/// snapshot, and old references are marked unavailable rather
/// than retargeted at the current content.
///
/// This file does not re-qualify ADR 0018 ImportMap, no
/// historical-revision / session / job-resume binding, or
/// fork-new-projectId. A history-selected packer is not invented.
/// Increment 3.25 PackageStagingAdmission and Increment 3.24
/// SessionExportAdmission stay closed. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. I-013 stays
/// partial. Existing I-013 remainingAcceptance wording is not
/// silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('when history is omitted, only the current snapshot is kept and old refs stay unavailable, not retargeted at current content', () {
    final admission = HistoryAvailabilityAdmission();
    final receipt = admission.admit(
      const HistoryAvailabilityRequest(kind: 'historyOmitted'),
    );
    expect(receipt.admitted, isTrue);
    expect(receipt.currentSnapshotOnly, isTrue);
    expect(receipt.oldRefsUnavailable, isTrue);
    expect(receipt.retargetedToCurrent, isFalse);

    expect(
      () => admission.admit(const HistoryAvailabilityRequest(kind: 'unknown')),
      code('HISTORY_AVAILABILITY_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const HistoryAvailabilityRequest(
          kind: 'historyOmitted',
          includesHistoricalSnapshots: true,
        ),
      ),
      code('HISTORICAL_SNAPSHOT_NOT_INCLUDED'),
    );
    expect(
      () => admission.admit(
        const HistoryAvailabilityRequest(
          kind: 'historyOmitted',
          retargetsOldRefsToCurrent: true,
        ),
      ),
      code('OLD_REF_NOT_CURRENT'),
    );
    expect(
      () => admission.admit(
        const HistoryAvailabilityRequest(
          kind: 'historyOmitted',
          oldRefsMarkedUnavailable: false,
        ),
      ),
      code('OLD_REF_NOT_UNAVAILABLE'),
    );
  });

  test('ADR 0018 ImportMap, historical-revision binding, fork-new-projectId, and Increment 3.25 stay closed', () {
    final admission = HistoryAvailabilityAdmission();
    expect(admission.importMapRequalified, isFalse);
    expect(admission.historicalRevisionBindingRequalified, isFalse);
    expect(admission.jobResumeRequalified, isFalse);
    expect(admission.forkNewProjectIdRequalified, isFalse);
    expect(admission.packageStagingRequalified, isFalse);
    expect(admission.sessionExportRequalified, isFalse);
    expect(admission.credentialsDeletedBodyRequalified, isFalse);
    expect(admission.auditJournalRequalified, isFalse);
    expect(admission.historyPackerInvented, isFalse);
    expect(admission.restoreInvented, isFalse);
    expect(admission.cherryPickInvented, isFalse);
    expect(admission.productionFtsClaimed, isFalse);
  });
}
