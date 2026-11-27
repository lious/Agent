import 'package:studio_contracts/studio_contracts.dart';

enum PoolKind { unified, discrete }

enum AllocationKind { hostExclusive, deviceExclusive, shared }

enum AdmissionDecision {
  allow,
  allowWithWarning,
  waitingResource,
  unsupported,
  needsApproval,
}

final class AllocationEntry {
  const AllocationEntry({
    required this.id,
    required this.kind,
    required this.bytes,
    this.alreadyResident = false,
    this.mmap = false,
  });

  final String id;
  final AllocationKind kind;
  final int bytes;
  final bool alreadyResident, mmap;
}

final class AdmissionRequest {
  const AdmissionRequest({
    required this.pool,
    required this.entries,
    required this.hostAvailable,
    this.deviceBudget = 0,
    this.headroom = 0,
    this.hostHeadroom = 0,
    this.deviceHeadroom = 0,
    this.offsetVramWithIdleRam = false,
    this.treatMmapAsZero = false,
    this.doubleChargeShared = false,
  });

  final PoolKind pool;
  final List<AllocationEntry> entries;
  final int hostAvailable, deviceBudget, headroom, hostHeadroom, deviceHeadroom;
  final bool offsetVramWithIdleRam, treatMmapAsZero, doubleChargeShared;
}

final class AdmissionReceipt {
  AdmissionReceipt({
    required this.decision,
    required this.chargedHostExclusive,
    required this.chargedDeviceExclusive,
    required this.chargedShared,
    required this.mmapResidency,
    required this.basicEditingRemainsAvailable,
  });

  final AdmissionDecision decision;
  final int chargedHostExclusive,
      chargedDeviceExclusive,
      chargedShared,
      mmapResidency;
  final bool basicEditingRemainsAvailable;
}

/// DEV-PURE s6c ResourceAdmissionController budget arithmetic.
/// This is not a ModelLease store, not a real memory or GPU
/// allocator, and not a re-qualification of I-042 pack leases.
final class ResourceAdmissionController {
  bool i042LeaseRequalified = false;
  bool codecProbeRequalified = false;
  bool registryRequalified = false;
  bool fallbackPlannerRequalified = false;
  bool modelLeaseInvented = false;
  bool compatibilityStoreInvented = false;
  bool realProbeInvented = false;
  bool paidApiCalled = false;

  AdmissionReceipt admit(AdmissionRequest request) {
    if (request.treatMmapAsZero) {
      throw const StudioException('MMAP_NOT_ZERO_RESIDENT', 'mmap');
    }
    if (request.offsetVramWithIdleRam) {
      throw const StudioException('VRAM_NOT_OFFSET_BY_RAM', 'deviceBudget');
    }
    if (request.doubleChargeShared) {
      throw const StudioException('INCREMENTAL_SHARED_DOUBLE_COUNT', 'shared');
    }

    final residentShared = {
      for (final entry in request.entries)
        if (entry.kind == AllocationKind.shared && entry.alreadyResident)
          entry.id,
    };
    final seenShared = <String>{};
    var hostExclusive = 0;
    var deviceExclusive = 0;
    var shared = 0;
    var mmapResidency = 0;

    for (final entry in request.entries) {
      requireId(entry.id);
      if (entry.bytes < 0) {
        throw StudioException('INCREMENTAL_SHARED_DOUBLE_COUNT', entry.id);
      }
      if (entry.mmap) {
        mmapResidency += entry.bytes;
      }
      if (entry.alreadyResident) {
        continue;
      }
      switch (entry.kind) {
        case AllocationKind.hostExclusive:
          hostExclusive += entry.bytes;
        case AllocationKind.deviceExclusive:
          deviceExclusive += entry.bytes;
        case AllocationKind.shared:
          if (residentShared.contains(entry.id)) {
            continue;
          }
          if (!seenShared.add(entry.id)) {
            throw StudioException('INCREMENTAL_SHARED_DOUBLE_COUNT', entry.id);
          }
          shared += entry.bytes;
      }
    }

    final waiting = switch (request.pool) {
      PoolKind.unified =>
        hostExclusive + deviceExclusive + shared + request.headroom >
            request.hostAvailable,
      PoolKind.discrete =>
        hostExclusive + shared + request.hostHeadroom > request.hostAvailable ||
            deviceExclusive + request.deviceHeadroom > request.deviceBudget,
    };

    return AdmissionReceipt(
      decision: waiting
          ? AdmissionDecision.waitingResource
          : AdmissionDecision.allow,
      chargedHostExclusive: hostExclusive,
      chargedDeviceExclusive: deviceExclusive,
      chargedShared: shared,
      mmapResidency: mmapResidency,
      basicEditingRemainsAvailable: true,
    );
  }
}
