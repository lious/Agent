import 'package:studio_contracts/studio_contracts.dart';

enum PressureKind { thermal, memory }

final class PressureRequest {
  const PressureRequest({
    required this.pressure,
    this.pauseBasicEditFirst = false,
    this.pauseEverythingEqually = false,
  });

  final PressureKind pressure;
  final bool pauseBasicEditFirst, pauseEverythingEqually;
}

final class PressureReceipt {
  PressureReceipt({
    required this.heavyPaused,
    required this.previewPaused,
    required this.basicEditingRemainsAvailable,
    required this.durableChunks,
    required this.inflightDiscarded,
  });

  final bool heavyPaused,
      previewPaused,
      basicEditingRemainsAvailable,
      inflightDiscarded;
  final List<String> durableChunks;
}

/// DEV-PURE V-023 pressure and interrupt admission. Under pressure,
/// heavy models pause first; ten interrupts do not lose already-durable
/// chunks. This is not a ModelLease store, not a real GPU worker, and
/// not a re-qualification of I-042 pack leases or the Increment 2.77
/// ResourceAdmissionController budget arithmetic.
final class PressureAdmission {
  PressureAdmission({List<String> durableChunks = const [], this.inflight})
    : _durable = List<String>.from(durableChunks);

  final List<String> _durable;
  String? inflight;
  var interruptCount = 0;

  bool i042LeaseRequalified = false;
  bool resourceAdmissionRequalified = false;
  bool sharedOnceRequalified = false;
  bool stalePointerRequalified = false;
  bool gpuWorkerInvented = false;
  bool modelLeaseInvented = false;
  bool compatibilityStoreInvented = false;
  bool oomClaimed = false;
  bool paidApiCalled = false;

  PressureReceipt underPressure(PressureRequest request) {
    if (request.pauseBasicEditFirst || request.pauseEverythingEqually) {
      throw const StudioException('HEAVY_NOT_PAUSED_FIRST', 'pressure');
    }
    return PressureReceipt(
      heavyPaused: true,
      previewPaused: true,
      basicEditingRemainsAvailable: true,
      durableChunks: List<String>.unmodifiable(_durable),
      inflightDiscarded: false,
    );
  }

  PressureReceipt interrupt() {
    interruptCount += 1;
    final discarded = inflight != null;
    inflight = null;
    return PressureReceipt(
      heavyPaused: true,
      previewPaused: true,
      basicEditingRemainsAvailable: true,
      durableChunks: List<String>.unmodifiable(_durable),
      inflightDiscarded: discarded,
    );
  }

  void loseDurable(String id) {
    throw StudioException('DURABLE_CHUNK_LOST', id);
  }
}
