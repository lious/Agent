import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_storage_probe/studio_storage_probe.dart';
import 'package:test/test.dart';

/// Increment 2.73 official V-005 leftover: untested StoragePort
/// providers stay restricted, and local rename is not applied to
/// SAF, iCloud, or generic cloud disks. This file does not invent
/// a SAF/iCloud adapter, does not re-qualify AtomicFilePublisher,
/// files_test, save_crash_test, or I-011 crash leftovers, does
/// not invent an I-014 RestoreService commit path, does not
/// re-qualify I-024 smart-render or export suites, does not
/// re-qualify V-004 Pulse or drop-disclosure work, does not
/// start I-059, I-061, or I-055, and does not mark I-037, I-038,
/// V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053,
/// I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045,
/// I-047, I-048, V-006, I-058, V-004, or I-024 complete.
/// InversePatch kind stays restoreSnapshot. Project user_version
/// stays 9. V-005 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('SAF, iCloud, and generic cloud stay unvalidated and restricted', () {
    final port = StorageProviderAdmission();
    expect(
      port.inspect(StorageProviderKind.localLinux).status,
      ProviderStatus.admitted,
    );
    for (final provider in [
      StorageProviderKind.saf,
      StorageProviderKind.icloud,
      StorageProviderKind.genericCloud,
      StorageProviderKind.windowsPort,
      StorageProviderKind.appleFullfsync,
    ]) {
      final receipt = port.inspect(provider);
      expect(receipt.status, ProviderStatus.unvalidated);
      expect(receipt.qualificationClaimed, isFalse);
      expect(receipt.renameApplied, isFalse);
    }
  });

  test('local rename is not applied to untested providers; non-atomic providers need staging and confirmation', () {
    final port = StorageProviderAdmission();
    expect(
      () => port.applyLocalRename(StorageProviderKind.saf),
      code('RENAME_NOT_PORTABLE'),
    );
    expect(
      () => port.applyLocalRename(StorageProviderKind.icloud),
      code('RENAME_NOT_PORTABLE'),
    );
    expect(
      () => port.applyLocalRename(StorageProviderKind.genericCloud),
      code('RENAME_NOT_PORTABLE'),
    );
    expect(
      () => port.silentRenameOnNonAtomic(StorageProviderKind.genericCloud),
      code('STAGING_CONFIRMATION_REQUIRED'),
    );
    expect(
      () => port.silentRenameOnNonAtomic(StorageProviderKind.saf),
      code('STAGING_CONFIRMATION_REQUIRED'),
    );
  });

  test('provider qualification is not claimed; I-011 and I-014 leftovers stay closed', () {
    final port = StorageProviderAdmission();
    expect(
      () => port.claimProviderQualified(StorageProviderKind.saf),
      code('PROVIDER_UNVALIDATED'),
    );
    expect(
      () => port.claimProviderQualified(StorageProviderKind.icloud),
      code('PROVIDER_UNVALIDATED'),
    );
    expect(
      () => port.claimProviderQualified(StorageProviderKind.localLinux),
      code('V005_GATE_UNMET'),
    );
    expect(port.v005ProviderQualificationClaimed, isFalse);
    expect(port.crashSuiteRequalified, isFalse);
    expect(port.onlyGoodCopyRequalified, isFalse);
    expect(port.i014CommitInvented, isFalse);
    expect(port.atomicFileRewritten, isFalse);
    expect(port.paidApiCalled, isFalse);
  });
}
