import 'package:studio_contracts/studio_contracts.dart';

enum StorageProviderKind {
  localLinux,
  saf,
  icloud,
  genericCloud,
  windowsPort,
  appleFullfsync,
}

enum ProviderStatus { admitted, unvalidated, restricted }

final class StorageProviderReceipt {
  StorageProviderReceipt({
    required this.provider,
    required this.status,
    required this.renameApplied,
    required this.qualificationClaimed,
    required this.onlyGoodCopyRequalified,
  });

  final StorageProviderKind provider;
  final ProviderStatus status;
  final bool renameApplied, qualificationClaimed, onlyGoodCopyRequalified;
}

/// DEV-PURE V-005 StoragePort provider admission. This is not a
/// SAF/iCloud adapter, not a 10-crash-point measurement, and not
/// a re-qualification of AtomicFilePublisher, files_test, or
/// I-011 crash leftovers.
final class StorageProviderAdmission {
  StorageProviderAdmission({this.admitted = StorageProviderKind.localLinux});

  final StorageProviderKind admitted;

  bool v005ProviderQualificationClaimed = false;
  bool crashSuiteRequalified = false;
  bool onlyGoodCopyRequalified = false;
  bool i014CommitInvented = false;
  bool atomicFileRewritten = false;
  bool paidApiCalled = false;

  ProviderStatus statusOf(StorageProviderKind provider) {
    if (provider == admitted && provider == StorageProviderKind.localLinux) {
      return ProviderStatus.admitted;
    }
    return ProviderStatus.unvalidated;
  }

  StorageProviderReceipt inspect(StorageProviderKind provider) {
    final status = statusOf(provider);
    return StorageProviderReceipt(
      provider: provider,
      status: status,
      renameApplied: false,
      qualificationClaimed: false,
      onlyGoodCopyRequalified: false,
    );
  }

  void applyLocalRename(StorageProviderKind provider) {
    if (statusOf(provider) != ProviderStatus.admitted) {
      throw const StudioException('RENAME_NOT_PORTABLE', 'localRename');
    }
  }

  void silentRenameOnNonAtomic(StorageProviderKind provider) {
    if (statusOf(provider) != ProviderStatus.admitted) {
      throw const StudioException(
        'STAGING_CONFIRMATION_REQUIRED',
        'silentRename',
      );
    }
  }

  void claimProviderQualified(StorageProviderKind provider) {
    if (statusOf(provider) != ProviderStatus.admitted) {
      throw const StudioException('PROVIDER_UNVALIDATED', 'qualify');
    }
    if (provider != StorageProviderKind.localLinux) {
      throw const StudioException('PROVIDER_UNVALIDATED', 'qualify');
    }
    throw const StudioException('V005_GATE_UNMET', 'providerQualification');
  }
}
