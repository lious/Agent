import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_original_placeholder_probe/studio_original_placeholder_probe.dart';
import 'package:test/test.dart';

/// Increment 3.23 official I-011 / s5c leftover: a bad cache may
/// be rebuilt, but a bad original is reported as a missing
/// resource and must not be replaced with a fake image.
///
/// This file does not re-qualify I-011 crash leftovers, Increment
/// 3.14 CasDbGapAdmission, AtomicFilePublisher, files_test,
/// save_crash_test, I-004 MISSING_MEDIA, or Increment 2.86 proxy
/// delivery. A RestoreService is not invented. InversePatch kind
/// stays restoreSnapshot. Project user_version stays 9. I-011
/// stays partial. Existing I-011 remainingAcceptance wording is
/// not silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a bad cache may be rebuilt, but a bad original is reported missing and must not be replaced with a fake image', () {
    final admission = OriginalPlaceholderAdmission();
    final cache = admission.admit(
      const OriginalPlaceholderRequest(kind: 'cache'),
    );
    expect(cache.admitted, isTrue);
    expect(cache.cacheMayRebuild, isTrue);
    expect(cache.placeholderUsed, isFalse);
    expect(cache.reportedMissing, isFalse);

    final original = admission.admit(
      const OriginalPlaceholderRequest(kind: 'original'),
    );
    expect(original.admitted, isTrue);
    expect(original.reportedMissing, isTrue);
    expect(original.placeholderUsed, isFalse);

    expect(
      () => admission.admit(const OriginalPlaceholderRequest(kind: 'unknown')),
      code('ORIGINAL_RECOVERY_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const OriginalPlaceholderRequest(
          kind: 'original',
          replaceWithPlaceholder: true,
        ),
      ),
      code('PLACEHOLDER_ORIGINAL_FORBIDDEN'),
    );
  });

  test('I-011 crash leftovers, CasDbGapAdmission, I-004 MISSING_MEDIA, and a RestoreService stay closed', () {
    final admission = OriginalPlaceholderAdmission();
    expect(admission.lastGoodSnapshotRequalified, isFalse);
    expect(admission.uniqueCopyRequalified, isFalse);
    expect(admission.schemaRoundtripRequalified, isFalse);
    expect(admission.casDbGapRequalified, isFalse);
    expect(admission.i004MissingMediaRequalified, isFalse);
    expect(admission.proxyDeliveryRequalified, isFalse);
    expect(admission.migrationCopyRequalified, isFalse);
    expect(admission.writerFenceRequalified, isFalse);
    expect(admission.ackLostRetryOfficialized, isFalse);
    expect(admission.orphanClaimInvented, isFalse);
    expect(admission.restoreInvented, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
    expect(admission.walRecoveryDisabled, isFalse);
  });
}
