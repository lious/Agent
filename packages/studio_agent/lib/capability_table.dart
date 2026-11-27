import 'package:studio_contracts/studio_contracts.dart';

/// Honest status for a planned or implemented capability.
///
/// [accepted] is reserved for clauses that have Linux/Web interface tests.
/// It is never used for on-device LLM inference, iOS packaging, or
/// store-release qualification in this increment.
enum CapabilityStatus {
  planned,
  reusableUnverified,
  pendingTest,
  accepted,
}

final class AgentCapability {
  AgentCapability({
    required this.id,
    required this.title,
    required this.status,
    required this.notes,
  }) {
    requireId(id);
  }

  final String id, title, notes;
  final CapabilityStatus status;
}

/// N0 portable inventory for the independent iOS local-LLM Agent scheme.
/// This table is not an iOS device qualification record.
final class AgentCapabilityTable {
  AgentCapabilityTable(List<AgentCapability> rows)
    : rows = List.unmodifiable(rows);

  final List<AgentCapability> rows;

  AgentCapability byId(String id) =>
      rows.firstWhere((r) => r.id == id, orElse: () {
        throw StudioException('INVALID_ID', id);
      });

  /// The default table shipped with Increment 2.14.
  static AgentCapabilityTable increment214() => AgentCapabilityTable([
    AgentCapability(
      id: 'N0-inventory',
      title: 'Capability and rights inventory',
      status: CapabilityStatus.accepted,
      notes:
          'Portable table and availability rules are unit-tested on Linux. '
          'Not a device rights ledger qualification.',
    ),
    AgentCapability(
      id: 'N1-interfaces',
      title: 'Portable runtime, plan, tool, journal, and budget interfaces',
      status: CapabilityStatus.accepted,
      notes:
          'Dart contracts and FakeLlmRuntime tests only. No XCFramework, '
          'no GGUF, no on-device inference.',
    ),
    AgentCapability(
      id: 'N2-llamacpp-binding',
      title: 'llama.cpp / XCFramework binding',
      status: CapabilityStatus.planned,
      notes:
          'Adapter is present and fail-closed without a registered pack and '
          'native runtime. No Xcode build and no iOS simulator on this host.',
    ),
    AgentCapability(
      id: 'N3-harness-tools',
      title: 'Harness loop, restricted tools, hooks, and durable journal',
      status: CapabilityStatus.accepted,
      notes:
          'Linux unit tests of the portable harness. Not an iOS app loop.',
    ),
    AgentCapability(
      id: 'N4-on-device-inference',
      title: 'On-device LLM inference with local weights',
      status: CapabilityStatus.planned,
      notes:
          'No model pack is downloaded or loaded in this increment. '
          'Real inference is not claimed.',
    ),
    AgentCapability(
      id: 'N5-ios-packaging',
      title: 'iOS app packaging and background budget',
      status: CapabilityStatus.planned,
      notes: 'No Xcode or iOS toolchain is used on this Linux host.',
    ),
    AgentCapability(
      id: 'N6-device-qualification',
      title: 'On-device qualification',
      status: CapabilityStatus.planned,
      notes: 'No user Mac or iOS device is used. Device qualification is open.',
    ),
  ]);
}
