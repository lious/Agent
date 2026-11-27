import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_cas_db_gap_probe/studio_cas_db_gap_probe.dart';
import 'package:test/test.dart';

/// Increment 3.14 official I-011 / s5c leftover: the DB must not
/// reference a ready asset before CAS is on disk, and file rename
/// plus SQLite must not be claimed as one atomic transaction.
///
/// This file does not officialize crash-after-CAS / orphan claim or
/// GC, and does not officialize ACK-lost receipt retry. I-011 crash
/// leftovers, AtomicFilePublisher, files_test, and save_crash_test
/// are not re-qualified. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9. I-011 stays partial. Existing I-011
/// remainingAcceptance labels (last good snapshot+tail, do not
/// overwrite the only good copy, schema roundtrip) are not silently
/// cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('the DB may reference ready only after CAS is on disk, and rename plus SQLite are not one atomic transaction', () {
    final admission = CasDbGapAdmission();
    final pending = admission.admit(const CasDbGapRequest());
    expect(pending.admitted, isTrue);
    expect(pending.dbReferencedReady, isFalse);
    expect(pending.renameAndSqliteOneAtomicTransaction, isFalse);
    final ready = admission.admit(
      const CasDbGapRequest(casOnDisk: true, dbReferencesReady: true),
    );
    expect(ready.admitted, isTrue);
    expect(ready.dbReferencedReady, isTrue);
    expect(ready.renameAndSqliteOneAtomicTransaction, isFalse);
    expect(
      () => admission.admit(const CasDbGapRequest(dbReferencesReady: true)),
      code('CAS_NOT_ON_DISK_DB_NOT_READY'),
    );
    expect(
      () => admission.admit(
        const CasDbGapRequest(
          casOnDisk: true,
          dbReferencesReady: true,
          claimsRenameAndSqliteOneAtomicTransaction: true,
        ),
      ),
      code('RENAME_SQLITE_NOT_ONE_ATOMIC'),
    );
  });

  test('I-011 crash leftovers, AtomicFilePublisher, files_test, save_crash_test, ACK-lost receipt retry, and orphan GC stay closed', () {
    final admission = CasDbGapAdmission();
    expect(admission.i011CrashRequalified, isFalse);
    expect(admission.atomicFilePublisherRequalified, isFalse);
    expect(admission.filesTestRequalified, isFalse);
    expect(admission.saveCrashTestRequalified, isFalse);
    expect(admission.ackLostReceiptRetryOfficialized, isFalse);
    expect(admission.orphanGcInvented, isFalse);
    expect(admission.sharedLibraryRequalified, isFalse);
    expect(admission.quoteApplyStarted, isFalse);
    expect(admission.i014RestoreInvented, isFalse);
  });
}
