import 'package:studio_contracts/studio_contracts.dart';

enum FeatureStatus { unverified, verified, deferredOptional }

final class ReleaseFeature {
  const ReleaseFeature({
    required this.id,
    required this.status,
    this.displayedAsSupported = false,
  });

  final String id;
  final FeatureStatus status;
  final bool displayedAsSupported;
}

final class ReleaseEvidenceBundle {
  ReleaseEvidenceBundle({
    required this.features,
    required this.unverifiedDisplayedAsSupported,
    required this.storeReleaseAccepted,
    required this.fixturesAllPassedClaimed,
    required this.i055Started,
    required this.optionalForcedOnline,
    required this.licenseWarningHardBlocked,
  });

  final List<ReleaseFeature> features;
  final bool unverifiedDisplayedAsSupported,
      storeReleaseAccepted,
      fixturesAllPassedClaimed,
      i055Started,
      optionalForcedOnline,
      licenseWarningHardBlocked;
}

/// DEV-PURE I-058 release-qualification protocol. This is not a
/// store submission, not a V-022 public-release qualification,
/// and not I-055.
final class ReleaseQualifier {
  ReleaseQualifier({
    required this.features,
    this.v022Met = false,
    this.i053Complete = false,
    this.realFixturesAllPassed = false,
    this.commercialLicenseWarning = false,
  });

  final List<ReleaseFeature> features;
  final bool v022Met,
      i053Complete,
      realFixturesAllPassed,
      commercialLicenseWarning;

  bool storeReleaseInvented = false;
  bool storeRegistrationInvented = false;
  bool paymentVendorInvented = false;
  bool iapInvented = false;
  bool receiptVerifierDeployed = false;
  bool sbomClaimedComplete = false;
  bool i055Started = false;
  bool v022Claimed = false;
  bool fixturesAllPassedClaimed = false;
  bool paidApiCalled = false;

  List<ReleaseFeature> get unverified => [
    for (final feature in features)
      if (feature.status == FeatureStatus.unverified) feature,
  ];

  ReleaseEvidenceBundle preview() {
    for (final feature in features) {
      if (feature.status != FeatureStatus.verified &&
          feature.displayedAsSupported) {
        throw const StudioException(
          'FEATURE_UNVERIFIED',
          'displayedAsSupported',
        );
      }
    }
    return ReleaseEvidenceBundle(
      features: features,
      unverifiedDisplayedAsSupported: false,
      storeReleaseAccepted: false,
      fixturesAllPassedClaimed: false,
      i055Started: false,
      optionalForcedOnline: false,
      licenseWarningHardBlocked: false,
    );
  }

  void markUnverifiedAsSupported(String id) {
    final feature = features.firstWhere((f) => f.id == id);
    if (feature.status != FeatureStatus.verified) {
      throw StudioException('FEATURE_UNVERIFIED', id);
    }
  }

  void forceOptionalOnline(String id) {
    final feature = features.firstWhere((f) => f.id == id);
    if (feature.status == FeatureStatus.deferredOptional) {
      throw StudioException('OPTIONAL_NOT_FORCED', id);
    }
  }

  void submitPaidStoreRelease() {
    if (!v022Met) {
      throw const StudioException('V022_GATE_UNMET', 'storeRelease');
    }
    if (!i053Complete) {
      throw const StudioException('I053_REQUIRED', 'storeRelease');
    }
  }

  void claimRealFixturesAllPassed() {
    if (!realFixturesAllPassed) {
      throw const StudioException('FIXTURES_UNQUALIFIED', 'fixtures');
    }
  }

  void treatLicenseWarningAsHardBlock() {
    throw const StudioException('WARNING_IS_NOT_HARD_BLOCK', 'license');
  }

  void treatLicenseWarningAsV022Exemption() {
    throw const StudioException('WARNING_DOES_NOT_EXEMPT', 'v022');
  }

  void startI055() {
    throw const StudioException('FEATURE_NOT_IMPLEMENTED', 'i055');
  }
}
