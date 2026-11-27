import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_resource_admission/studio_resource_admission.dart';
import 'package:test/test.dart';

/// Increment 2.77 official s6c ResourceAdmissionController slice.
/// This file does not re-qualify I-042 pack leases, does not start
/// CompatibilityStore / ModelLease, does not invent a real memory
/// or GPU allocator, does not re-qualify the Increment 2.76
/// CodecProbePort slice, the 2.75 DeviceProbeService /
/// CompatibilityRegistry slice, the 2.74 CompatibilityFallbackPlanner,
/// V-001 toolchain probes, or V-002 format-reason / I-015 leftovers,
/// does not start I-059, I-061, or I-055, and does not mark I-037,
/// I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053,
/// I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047,
/// I-048, V-006, I-058, V-004, I-024, V-005, I-042, or V-002
/// complete. InversePatch kind stays restoreSnapshot. Project
/// user_version stays 9. V-002 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('unified-pool incremental charges shared once; already-resident shared is deducted first', () {
    final controller = ResourceAdmissionController();
    final receipt = controller.admit(
      const AdmissionRequest(
        pool: PoolKind.unified,
        hostAvailable: 1000,
        headroom: 100,
        entries: [
          AllocationEntry(
            id: 'pack.shared.a',
            kind: AllocationKind.shared,
            bytes: 200,
            alreadyResident: true,
          ),
          AllocationEntry(
            id: 'pack.shared.a',
            kind: AllocationKind.shared,
            bytes: 200,
          ),
          AllocationEntry(
            id: 'pack.shared.b',
            kind: AllocationKind.shared,
            bytes: 120,
          ),
          AllocationEntry(
            id: 'host.job',
            kind: AllocationKind.hostExclusive,
            bytes: 300,
          ),
          AllocationEntry(
            id: 'device.job',
            kind: AllocationKind.deviceExclusive,
            bytes: 150,
          ),
        ],
      ),
    );
    expect(receipt.chargedShared, 120);
    expect(receipt.chargedHostExclusive, 300);
    expect(receipt.chargedDeviceExclusive, 150);
    expect(receipt.decision, AdmissionDecision.allow);
    expect(
      () => controller.admit(
        const AdmissionRequest(
          pool: PoolKind.unified,
          hostAvailable: 1000,
          entries: [
            AllocationEntry(
              id: 'pack.shared.a',
              kind: AllocationKind.shared,
              bytes: 200,
            ),
            AllocationEntry(
              id: 'pack.shared.a',
              kind: AllocationKind.shared,
              bytes: 200,
            ),
          ],
        ),
      ),
      code('INCREMENTAL_SHARED_DOUBLE_COUNT'),
    );
    expect(
      () => controller.admit(
        const AdmissionRequest(
          pool: PoolKind.unified,
          hostAvailable: 1000,
          doubleChargeShared: true,
          entries: [],
        ),
      ),
      code('INCREMENTAL_SHARED_DOUBLE_COUNT'),
    );
  });

  test('idle RAM does not offset VRAM; a discrete shortfall is waitingResource and basic editing stays available', () {
    final controller = ResourceAdmissionController();
    expect(
      () => controller.admit(
        const AdmissionRequest(
          pool: PoolKind.discrete,
          hostAvailable: 8000,
          deviceBudget: 100,
          offsetVramWithIdleRam: true,
          entries: [
            AllocationEntry(
              id: 'device.job',
              kind: AllocationKind.deviceExclusive,
              bytes: 400,
            ),
          ],
        ),
      ),
      code('VRAM_NOT_OFFSET_BY_RAM'),
    );
    final receipt = controller.admit(
      const AdmissionRequest(
        pool: PoolKind.discrete,
        hostAvailable: 8000,
        hostHeadroom: 100,
        deviceBudget: 100,
        deviceHeadroom: 10,
        entries: [
          AllocationEntry(
            id: 'host.job',
            kind: AllocationKind.hostExclusive,
            bytes: 200,
          ),
          AllocationEntry(
            id: 'device.job',
            kind: AllocationKind.deviceExclusive,
            bytes: 400,
          ),
        ],
      ),
    );
    expect(receipt.decision, AdmissionDecision.waitingResource);
    expect(receipt.basicEditingRemainsAvailable, isTrue);
    expect(receipt.chargedDeviceExclusive, 400);
  });

  test('mmap is not zero residency; I-042 leases and earlier s6c slices stay closed', () {
    final controller = ResourceAdmissionController();
    expect(
      () => controller.admit(
        const AdmissionRequest(
          pool: PoolKind.unified,
          hostAvailable: 1000,
          treatMmapAsZero: true,
          entries: [
            AllocationEntry(
              id: 'pack.mmap.a',
              kind: AllocationKind.shared,
              bytes: 250,
              mmap: true,
            ),
          ],
        ),
      ),
      code('MMAP_NOT_ZERO_RESIDENT'),
    );
    final receipt = controller.admit(
      const AdmissionRequest(
        pool: PoolKind.unified,
        hostAvailable: 1000,
        headroom: 100,
        entries: [
          AllocationEntry(
            id: 'pack.mmap.a',
            kind: AllocationKind.shared,
            bytes: 250,
            mmap: true,
          ),
        ],
      ),
    );
    expect(receipt.mmapResidency, 250);
    expect(receipt.chargedShared, 250);
    expect(receipt.decision, AdmissionDecision.allow);
    expect(controller.i042LeaseRequalified, isFalse);
    expect(controller.codecProbeRequalified, isFalse);
    expect(controller.registryRequalified, isFalse);
    expect(controller.fallbackPlannerRequalified, isFalse);
    expect(controller.modelLeaseInvented, isFalse);
    expect(controller.compatibilityStoreInvented, isFalse);
    expect(controller.realProbeInvented, isFalse);
    expect(controller.paidApiCalled, isFalse);
  });
}
