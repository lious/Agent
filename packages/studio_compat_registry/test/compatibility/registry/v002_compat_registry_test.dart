import 'package:studio_compat_registry/studio_compat_registry.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

/// Increment 2.75 official s6c DeviceProbeService /
/// CompatibilityRegistry slice. This file does not invent a real
/// device probe, does not re-qualify V-001 toolchain probes or
/// I-042 leases, does not re-qualify the Increment 2.74
/// CompatibilityFallbackPlanner slice, V-004 proxy downgrade,
/// I-024 no-encoder refusal, or the 2.73 V-005
/// provider-restriction slice, does not start I-059, I-061, or
/// I-055, and does not mark I-037, I-038, V-007, V-020, I-054,
/// I-051, I-046, I-041, I-040, I-053, I-056, I-057, I-052,
/// I-039, V-026, I-043, I-044, I-045, I-047, I-048, V-006,
/// I-058, V-004, I-024, V-005, or V-002 complete. InversePatch
/// kind stays restoreSnapshot. Project user_version stays 9.
/// V-002 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

CompatibilityLookup lookup({
  CompatibilityPhase phase = CompatibilityPhase.planned,
  String buildFingerprint = 'build-a',
  String modelPackHashes = 'pack-a',
  String runtimeFingerprint = 'ep-a',
  String osVersion = '6.12',
  String gpuDriver = 'driver-a',
  String? qualifiedFixtureHash,
  bool evidenceComplete = false,
  bool testChannel = false,
  bool displayAsSupported = false,
  bool schemaValid = false,
  bool claimOsSemanticsFromSchema = false,
  QualifiedProfile? inheritFrom,
}) {
  return CompatibilityLookup(
    appNamespace: 'studio.local.w',
    feature: 'preview.codec',
    profileId: 'profile.h264',
    revision: '1.0.0',
    buildFingerprint: buildFingerprint,
    modelPackHashes: modelPackHashes,
    runtimeFingerprint: runtimeFingerprint,
    workload: 'preview',
    phase: phase,
    osVersion: osVersion,
    gpuDriver: gpuDriver,
    qualifiedFixtureHash: qualifiedFixtureHash,
    evidenceComplete: evidenceComplete,
    testChannel: testChannel,
    displayAsSupported: displayAsSupported,
    schemaValid: schemaValid,
    claimOsSemanticsFromSchema: claimOsSemanticsFromSchema,
    inheritFrom: inheritFrom,
  );
}

void main() {
  test('unknown DeviceSnapshot quantities stay null, not 0; known quantities are U64 decimal strings', () {
    final probe = DeviceProbeService();
    final snapshot = probe.capture(
      platform: 'linux',
      osVersion: '6.12',
      osBuild: 'build',
      arch: 'x86_64',
      deviceModel: 'dev',
      gpuId: 'gpu',
      gpuDriver: 'driver',
      physicalMemory: '17179869184',
      unknownQuantities: {
        'availableProcessMemory',
        'deviceLocalBudget',
        'storageFreeBytes',
      },
    );
    expect(snapshot.physicalMemory, '17179869184');
    expect(snapshot.availableProcessMemory, isNull);
    expect(snapshot.deviceLocalBudget, isNull);
    expect(snapshot.storageFreeBytes, isNull);
    expect(snapshot.availableProcessMemory, isNot('0'));
    expect(
      () => probe.capture(
        platform: 'linux',
        osVersion: '6.12',
        osBuild: 'build',
        arch: 'x86_64',
        deviceModel: 'dev',
        gpuId: 'gpu',
        gpuDriver: 'driver',
        availableProcessMemory: '0',
        unknownQuantities: {'availableProcessMemory'},
      ),
      code('UNKNOWN_NOT_ZERO'),
    );
    expect(probe.realProbeInvented, isFalse);
  });

  test('planned or adapting only display the target; labValidated is test-channel only; released requires complete evidence', () {
    final registry = CompatibilityRegistry();
    final planned = registry.resolve(lookup());
    expect(planned.displayTargetOnly, isTrue);
    expect(planned.displayedAsSupported, isFalse);
    expect(
      () => registry.resolve(lookup(displayAsSupported: true)),
      code('TARGET_NOT_RELEASED'),
    );
    expect(
      () => registry.resolve(
        lookup(phase: CompatibilityPhase.adapting, displayAsSupported: true),
      ),
      code('TARGET_NOT_RELEASED'),
    );
    expect(
      () => registry.resolve(lookup(phase: CompatibilityPhase.labValidated)),
      code('TEST_CHANNEL_ONLY'),
    );
    final lab = registry.resolve(
      lookup(phase: CompatibilityPhase.labValidated, testChannel: true),
    );
    expect(lab.displayTargetOnly, isTrue);
    expect(lab.displayedAsSupported, isFalse);
    expect(
      () => registry.resolve(lookup(phase: CompatibilityPhase.released)),
      code('PROFILE_NOT_QUALIFIED'),
    );
    expect(
      () => registry.resolve(
        lookup(phase: CompatibilityPhase.released, evidenceComplete: true),
      ),
      code('PROFILE_NOT_QUALIFIED'),
    );
    final released = registry.resolve(
      lookup(
        phase: CompatibilityPhase.released,
        evidenceComplete: true,
        qualifiedFixtureHash: 'fixture-a',
      ),
    );
    expect(released.displayedAsSupported, isTrue);
    expect(released.qualifiedFixtureHash, 'fixture-a');
    expect(
      () => registry.resolve(
        lookup(schemaValid: true, claimOsSemanticsFromSchema: true),
      ),
      code('SCHEMA_NOT_OS_QUALIFIED'),
    );
  });

  test('version, driver, model, or EP changes expire old qualification and are not inherited; V-001 and I-042 leftovers stay closed', () {
    final registry = CompatibilityRegistry();
    final prior = registry.resolve(
      lookup(
        phase: CompatibilityPhase.released,
        evidenceComplete: true,
        qualifiedFixtureHash: 'fixture-a',
      ),
    );
    expect(
      () => registry.resolve(
        lookup(
          phase: CompatibilityPhase.released,
          evidenceComplete: true,
          qualifiedFixtureHash: 'fixture-a',
          gpuDriver: 'driver-b',
          inheritFrom: prior,
        ),
      ),
      code('QUALIFICATION_EXPIRED'),
    );
    expect(
      () => registry.resolve(
        lookup(
          phase: CompatibilityPhase.released,
          evidenceComplete: true,
          qualifiedFixtureHash: 'fixture-a',
          osVersion: '6.13',
          inheritFrom: prior,
        ),
      ),
      code('QUALIFICATION_EXPIRED'),
    );
    expect(
      () => registry.resolve(
        lookup(
          phase: CompatibilityPhase.released,
          evidenceComplete: true,
          qualifiedFixtureHash: 'fixture-a',
          modelPackHashes: 'pack-b',
          inheritFrom: prior,
        ),
      ),
      code('QUALIFICATION_EXPIRED'),
    );
    expect(
      () => registry.resolve(
        lookup(
          phase: CompatibilityPhase.released,
          evidenceComplete: true,
          qualifiedFixtureHash: 'fixture-a',
          runtimeFingerprint: 'ep-b',
          inheritFrom: prior,
        ),
      ),
      code('QUALIFICATION_EXPIRED'),
    );
    final inherited = registry.resolve(
      lookup(
        phase: CompatibilityPhase.released,
        evidenceComplete: true,
        qualifiedFixtureHash: 'fixture-a',
        inheritFrom: prior,
      ),
    );
    expect(inherited.phase, CompatibilityPhase.released);
    expect(registry.realProbeInvented, isFalse);
    expect(registry.v001Requalified, isFalse);
    expect(registry.i042LeaseRequalified, isFalse);
    expect(registry.fallbackPlannerRequalified, isFalse);
    expect(registry.paidApiCalled, isFalse);
  });
}
