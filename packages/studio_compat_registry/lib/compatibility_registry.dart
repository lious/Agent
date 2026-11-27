import 'package:studio_contracts/studio_contracts.dart';

enum CompatibilityPhase { planned, adapting, labValidated, released }

final class QualifiedProfile {
  QualifiedProfile({
    required this.appNamespace,
    required this.feature,
    required this.profileId,
    required this.revision,
    required this.buildFingerprint,
    required this.modelPackHashes,
    required this.runtimeFingerprint,
    required this.workload,
    required this.phase,
    required this.qualifiedFixtureHash,
    required this.osVersion,
    required this.gpuDriver,
    required this.displayTargetOnly,
    required this.displayedAsSupported,
    required this.schemaValid,
    required this.osSemanticsValidated,
  });

  final String appNamespace,
      feature,
      profileId,
      revision,
      buildFingerprint,
      modelPackHashes,
      runtimeFingerprint,
      workload,
      osVersion,
      gpuDriver;
  final CompatibilityPhase phase;
  final String? qualifiedFixtureHash;
  final bool displayTargetOnly,
      displayedAsSupported,
      schemaValid,
      osSemanticsValidated;
}

final class CompatibilityLookup {
  const CompatibilityLookup({
    required this.appNamespace,
    required this.feature,
    required this.profileId,
    required this.revision,
    required this.buildFingerprint,
    required this.modelPackHashes,
    required this.runtimeFingerprint,
    required this.workload,
    required this.phase,
    required this.osVersion,
    required this.gpuDriver,
    this.qualifiedFixtureHash,
    this.evidenceComplete = false,
    this.testChannel = false,
    this.displayAsSupported = false,
    this.schemaValid = false,
    this.claimOsSemanticsFromSchema = false,
    this.inheritFrom,
  });

  final String appNamespace,
      feature,
      profileId,
      revision,
      buildFingerprint,
      modelPackHashes,
      runtimeFingerprint,
      workload,
      osVersion,
      gpuDriver;
  final CompatibilityPhase phase;
  final String? qualifiedFixtureHash;
  final bool evidenceComplete,
      testChannel,
      displayAsSupported,
      schemaValid,
      claimOsSemanticsFromSchema;
  final QualifiedProfile? inheritFrom;
}

/// DEV-PURE s6c CompatibilityRegistry. This is not a real device
/// probe, not a ModelLease store, and not a re-qualification of
/// V-001 toolchain probes or I-042 leases.
final class CompatibilityRegistry {
  bool realProbeInvented = false;
  bool v001Requalified = false;
  bool i042LeaseRequalified = false;
  bool fallbackPlannerRequalified = false;
  bool paidApiCalled = false;

  QualifiedProfile resolve(CompatibilityLookup lookup) {
    requireId(lookup.appNamespace);
    requireId(lookup.feature);
    requireId(lookup.profileId);
    requireId(lookup.revision);

    if (lookup.inheritFrom != null && _expired(lookup, lookup.inheritFrom!)) {
      throw const StudioException('QUALIFICATION_EXPIRED', 'inherit');
    }

    if (lookup.claimOsSemanticsFromSchema) {
      throw const StudioException('SCHEMA_NOT_OS_QUALIFIED', 'schema');
    }

    switch (lookup.phase) {
      case CompatibilityPhase.planned:
      case CompatibilityPhase.adapting:
        if (lookup.displayAsSupported) {
          throw const StudioException('TARGET_NOT_RELEASED', 'phase');
        }
        return _profile(
          lookup,
          displayTargetOnly: true,
          displayedAsSupported: false,
        );
      case CompatibilityPhase.labValidated:
        if (!lookup.testChannel) {
          throw const StudioException('TEST_CHANNEL_ONLY', 'labValidated');
        }
        if (lookup.displayAsSupported) {
          throw const StudioException('TARGET_NOT_RELEASED', 'labValidated');
        }
        return _profile(
          lookup,
          displayTargetOnly: true,
          displayedAsSupported: false,
        );
      case CompatibilityPhase.released:
        final evidence =
            lookup.evidenceComplete &&
            (lookup.qualifiedFixtureHash?.isNotEmpty ?? false);
        if (!evidence) {
          throw const StudioException('PROFILE_NOT_QUALIFIED', 'released');
        }
        return _profile(
          lookup,
          displayTargetOnly: false,
          displayedAsSupported: true,
        );
    }
  }

  bool _expired(CompatibilityLookup lookup, QualifiedProfile prior) {
    return lookup.buildFingerprint != prior.buildFingerprint ||
        lookup.osVersion != prior.osVersion ||
        lookup.gpuDriver != prior.gpuDriver ||
        lookup.modelPackHashes != prior.modelPackHashes ||
        lookup.runtimeFingerprint != prior.runtimeFingerprint;
  }

  QualifiedProfile _profile(
    CompatibilityLookup lookup, {
    required bool displayTargetOnly,
    required bool displayedAsSupported,
  }) {
    return QualifiedProfile(
      appNamespace: lookup.appNamespace,
      feature: lookup.feature,
      profileId: lookup.profileId,
      revision: lookup.revision,
      buildFingerprint: lookup.buildFingerprint,
      modelPackHashes: lookup.modelPackHashes,
      runtimeFingerprint: lookup.runtimeFingerprint,
      workload: lookup.workload,
      phase: lookup.phase,
      qualifiedFixtureHash: lookup.qualifiedFixtureHash,
      osVersion: lookup.osVersion,
      gpuDriver: lookup.gpuDriver,
      displayTargetOnly: displayTargetOnly,
      displayedAsSupported: displayedAsSupported,
      schemaValid: lookup.schemaValid,
      osSemanticsValidated: false,
    );
  }
}
