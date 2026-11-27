import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_pressure_probe/studio_pressure_probe.dart';
import 'package:test/test.dart';

/// Increment 2.81 official first V-023 slice: pressure pauses heavy
/// models first, and ten interrupts do not lose durable chunks.
/// This file does not re-qualify I-042 pack leases, the Increment
/// 2.77 ResourceAdmissionController slice, Increments 2.74–2.80
/// s6c default-delivery bounds, V-006, I-024, I-007, or V-004
/// leftovers, does not start CompatibilityStore / ModelLease, does
/// not invent a real GPU worker, does not claim a 20-minute no-OOM
/// measurement, does not start I-059, I-061, or I-055, and does not
/// mark I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041,
/// I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044,
/// I-045, I-047, I-048, V-006, I-058, V-004, I-024, V-005, V-002,
/// I-007, or I-042 complete. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9. V-023 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('under thermal or memory pressure, heavy models pause first and basic editing stays available', () {
    final session = PressureAdmission();
    for (final pressure in [PressureKind.thermal, PressureKind.memory]) {
      final receipt = session.underPressure(
        PressureRequest(pressure: pressure),
      );
      expect(receipt.heavyPaused, isTrue);
      expect(receipt.basicEditingRemainsAvailable, isTrue);
    }
    expect(
      () => session.underPressure(
        const PressureRequest(
          pressure: PressureKind.thermal,
          pauseBasicEditFirst: true,
        ),
      ),
      code('HEAVY_NOT_PAUSED_FIRST'),
    );
    expect(
      () => session.underPressure(
        const PressureRequest(
          pressure: PressureKind.memory,
          pauseEverythingEqually: true,
        ),
      ),
      code('HEAVY_NOT_PAUSED_FIRST'),
    );
  });

  test('ten interrupts do not lose already-durable chunks; in-flight non-durable work is discarded', () {
    final session = PressureAdmission(
      durableChunks: ['chunk.a', 'chunk.b'],
      inflight: 'chunk.inflight',
    );
    PressureReceipt? last;
    for (var i = 0; i < 10; i++) {
      last = session.interrupt();
      expect(last.durableChunks, ['chunk.a', 'chunk.b']);
      expect(last.basicEditingRemainsAvailable, isTrue);
      if (i == 0) {
        expect(last.inflightDiscarded, isTrue);
      } else {
        expect(last.inflightDiscarded, isFalse);
      }
    }
    expect(session.interruptCount, 10);
    expect(last!.durableChunks, ['chunk.a', 'chunk.b']);
    expect(() => session.loseDurable('chunk.a'), code('DURABLE_CHUNK_LOST'));
  });

  test('I-042 leases, ResourceAdmissionController, shared-once, ABI stale-pointer, and 20-minute OOM leftovers stay closed', () {
    final session = PressureAdmission(durableChunks: const ['chunk.a']);
    expect(session.i042LeaseRequalified, isFalse);
    expect(session.resourceAdmissionRequalified, isFalse);
    expect(session.sharedOnceRequalified, isFalse);
    expect(session.stalePointerRequalified, isFalse);
    expect(session.gpuWorkerInvented, isFalse);
    expect(session.modelLeaseInvented, isFalse);
    expect(session.compatibilityStoreInvented, isFalse);
    expect(session.oomClaimed, isFalse);
    expect(session.paidApiCalled, isFalse);
  });
}
