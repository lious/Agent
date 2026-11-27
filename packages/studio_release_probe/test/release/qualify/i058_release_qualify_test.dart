import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_release_probe/studio_release_probe.dart';
import 'package:test/test.dart';

/// Increment 2.70 official first I-058 slice: unverified
/// capabilities are not shown as supported, paid store release
/// requires I-053 and V-022, optional capabilities are not
/// forced online, and real fixtures / store-release are not
/// claimed. This file does not invent a payment vendor, IAP,
/// store registration, or a deployed receipt verifier, does not
/// claim V-022 or store-release as passed, does not start I-055
/// or I-059 or I-061, does not invent a limiter, does not
/// re-qualify I-049, I-050, I-028, I-042, V-006, I-053, I-054,
/// I-056, V-007, I-001, I-011, or I-012 leftovers, and does not
/// mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041,
/// I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043,
/// I-044, I-045, I-047, I-048, or V-006 complete. InversePatch
/// kind stays restoreSnapshot. Project user_version stays 9.
/// V-022 stays blocked. I-059 stays planned.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

ReleaseQualifier qualifier() => ReleaseQualifier(
  features: const [
    ReleaseFeature(id: 'sdrTimeline', status: FeatureStatus.verified),
    ReleaseFeature(id: 'hdrDelivery', status: FeatureStatus.unverified),
    ReleaseFeature(
      id: 'optionalSpatialAudio',
      status: FeatureStatus.deferredOptional,
    ),
  ],
  commercialLicenseWarning: true,
);

void main() {
  test('unverified capabilities are not displayed as supported', () {
    final release = qualifier();
    final preview = release.preview();
    expect(preview.unverifiedDisplayedAsSupported, isFalse);
    expect(preview.storeReleaseAccepted, isFalse);
    expect(release.unverified.map((f) => f.id), ['hdrDelivery']);
    expect(
      () => release.markUnverifiedAsSupported('hdrDelivery'),
      code('FEATURE_UNVERIFIED'),
    );
    expect(
      () => ReleaseQualifier(
        features: const [
          ReleaseFeature(
            id: 'hdrDelivery',
            status: FeatureStatus.unverified,
            displayedAsSupported: true,
          ),
        ],
      ).preview(),
      code('FEATURE_UNVERIFIED'),
    );
  });

  test('paid store release requires I-053 and V-022; optional capabilities are not forced online', () {
    final release = qualifier();
    expect(release.v022Met, isFalse);
    expect(release.i053Complete, isFalse);
    expect(() => release.submitPaidStoreRelease(), code('V022_GATE_UNMET'));
    expect(
      () => release.forceOptionalOnline('optionalSpatialAudio'),
      code('OPTIONAL_NOT_FORCED'),
    );
    expect(release.preview().optionalForcedOnline, isFalse);
    expect(
      () => release.treatLicenseWarningAsHardBlock(),
      code('WARNING_IS_NOT_HARD_BLOCK'),
    );
    expect(
      () => release.treatLicenseWarningAsV022Exemption(),
      code('WARNING_DOES_NOT_EXEMPT'),
    );
  });

  test(
    'real fixtures and store-release are not claimed; I-055 is not started',
    () {
      final release = qualifier();
      expect(release.realFixturesAllPassed, isFalse);
      expect(
        () => release.claimRealFixturesAllPassed(),
        code('FIXTURES_UNQUALIFIED'),
      );
      expect(() => release.startI055(), code('FEATURE_NOT_IMPLEMENTED'));
      final preview = release.preview();
      expect(preview.fixturesAllPassedClaimed, isFalse);
      expect(preview.storeReleaseAccepted, isFalse);
      expect(preview.i055Started, isFalse);
      expect(release.storeReleaseInvented, isFalse);
      expect(release.storeRegistrationInvented, isFalse);
      expect(release.paymentVendorInvented, isFalse);
      expect(release.iapInvented, isFalse);
      expect(release.receiptVerifierDeployed, isFalse);
      expect(release.sbomClaimedComplete, isFalse);
      expect(release.v022Claimed, isFalse);
      expect(release.i055Started, isFalse);
      expect(release.paidApiCalled, isFalse);
    },
  );
}
