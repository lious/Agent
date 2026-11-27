import 'package:studio_contracts/studio_contracts.dart';

final class CasDbGapRequest {
  const CasDbGapRequest({
    this.casOnDisk = false,
    this.dbReferencesReady = false,
    this.claimsRenameAndSqliteOneAtomicTransaction = false,
  });

  /// Content-addressed bytes are already on disk.
  final bool casOnDisk;
  final bool dbReferencesReady;
  final bool claimsRenameAndSqliteOneAtomicTransaction;
}

final class CasDbGapReceipt {
  const CasDbGapReceipt({
    required this.admitted,
    required this.dbReferencedReady,
    required this.renameAndSqliteOneAtomicTransaction,
  });

  final bool admitted;
  final bool dbReferencedReady;
  final bool renameAndSqliteOneAtomicTransaction;
}

/// DEV-PURE I-011 / s5c admission: the DB must not reference a ready
/// asset before CAS is on disk, and file rename plus SQLite must not
/// be claimed as one atomic transaction.
///
/// This does not officialize crash-after-CAS / orphan claim or GC,
/// and does not officialize ACK-lost receipt retry (close to
/// “不能盲重试生成”). I-011 crash leftovers, AtomicFilePublisher,
/// files_test, and save_crash_test are not re-qualified.
final class CasDbGapAdmission {
  bool i011CrashRequalified = false;
  bool atomicFilePublisherRequalified = false;
  bool filesTestRequalified = false;
  bool saveCrashTestRequalified = false;
  bool ackLostReceiptRetryOfficialized = false;
  bool orphanGcInvented = false;
  bool sharedLibraryRequalified = false;
  bool quoteApplyStarted = false;
  bool i014RestoreInvented = false;

  CasDbGapReceipt admit(CasDbGapRequest request) {
    if (request.claimsRenameAndSqliteOneAtomicTransaction) {
      throw const StudioException('RENAME_SQLITE_NOT_ONE_ATOMIC', 'storage');
    }
    if (request.dbReferencesReady && !request.casOnDisk) {
      throw const StudioException('CAS_NOT_ON_DISK_DB_NOT_READY', 'storage');
    }
    return CasDbGapReceipt(
      admitted: true,
      dbReferencedReady: request.casOnDisk && request.dbReferencesReady,
      renameAndSqliteOneAtomicTransaction: false,
    );
  }
}
