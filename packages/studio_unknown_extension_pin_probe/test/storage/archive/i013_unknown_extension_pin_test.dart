import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_unknown_extension_pin_probe/studio_unknown_extension_pin_probe.dart';
import 'package:test/test.dart';

/// Increment 3.29 official I-013 / s5d leftover: when an unknown
/// extension's references cannot be enumerated, those bytes must
/// be pinned conservatively and the archive must not be claimed
/// complete.
///
/// This file does not re-qualify I-004 same-hash, ADR 0099, I-029
/// DeletionBarrier, Increment 2.50 packMode / sourceCompleteness,
/// or the unofficialized PENDING_MEDIA complete-archive sentence.
/// A BackupStore runtime is not invented. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. I-013 stays
/// partial. Existing I-013 remainingAcceptance wording is not
/// silently cleared. I-004 remainingAcceptance is not touched.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('an unknown extension whose refs cannot be enumerated must be pinned conservatively and must not claim a complete archive', () {
    final admission = UnknownExtensionPinAdmission();
    final pinned = admission.admit(
      const UnknownExtensionPinRequest(
        kind: 'archiveClosure',
        unknownExtensionPresent: true,
        referencesEnumerable: false,
        conservativelyPinned: true,
      ),
    );
    expect(pinned.admitted, isTrue);
    expect(pinned.conservativelyPinned, isTrue);
    expect(pinned.completeArchiveClaimed, isFalse);

    final enumerable = admission.admit(
      const UnknownExtensionPinRequest(kind: 'archiveClosure'),
    );
    expect(enumerable.admitted, isTrue);
    expect(enumerable.conservativelyPinned, isFalse);
    expect(enumerable.completeArchiveClaimed, isFalse);

    expect(
      () => admission.admit(const UnknownExtensionPinRequest(kind: 'unknown')),
      code('UNKNOWN_EXTENSION_PIN_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const UnknownExtensionPinRequest(
          kind: 'archiveClosure',
          unknownExtensionPresent: true,
          referencesEnumerable: false,
        ),
      ),
      code('CONSERVATIVE_PIN_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const UnknownExtensionPinRequest(
          kind: 'archiveClosure',
          unknownExtensionPresent: true,
          referencesEnumerable: false,
          conservativelyPinned: true,
          claimsCompleteArchive: true,
        ),
      ),
      code('UNKNOWN_EXTENSION_FALSE_COMPLETE'),
    );
  });

  test('I-004 same-hash, ADR 0099, I-029, Increment 2.50 packMode, and PENDING_MEDIA complete-archive stay closed', () {
    final admission = UnknownExtensionPinAdmission();
    expect(admission.sameHashRequalified, isFalse);
    expect(admission.credentialsDeletedBodyRequalified, isFalse);
    expect(admission.deletionBarrierRequalified, isFalse);
    expect(admission.packModeRequalified, isFalse);
    expect(admission.pendingMediaCompleteRequalified, isFalse);
    expect(admission.archiveCountdownRequalified, isFalse);
    expect(admission.libraryArchiveRequalified, isFalse);
    expect(admission.artifactKindRequalified, isFalse);
    expect(admission.backupStoreInvented, isFalse);
    expect(admission.jobArchivalInvented, isFalse);
    expect(admission.productionFtsClaimed, isFalse);
  });
}
