import 'package:studio_contracts/studio_contracts.dart';

/// Known U64 quantity names on DeviceSnapshot. Unknown values stay
/// null and must not be recorded as the decimal string "0".
const quantityFields = {
  'physicalMemory',
  'availableProcessMemory',
  'deviceLocalBudget',
  'storageFreeBytes',
};

final class DeviceSnapshot {
  DeviceSnapshot({
    required this.platform,
    required this.osVersion,
    required this.osBuild,
    required this.arch,
    required this.deviceModel,
    required this.gpuId,
    required this.gpuDriver,
    required this.runtimeBuilds,
    required this.physicalMemory,
    required this.availableProcessMemory,
    required this.deviceLocalBudget,
    required this.storageFreeBytes,
    required this.thermalStatus,
    required this.foreground,
    required this.capturedAt,
    required this.probeEpoch,
  });

  final String platform,
      osVersion,
      osBuild,
      arch,
      deviceModel,
      gpuId,
      gpuDriver;
  final String? runtimeBuilds,
      physicalMemory,
      availableProcessMemory,
      deviceLocalBudget,
      storageFreeBytes,
      thermalStatus,
      capturedAt,
      probeEpoch;
  final bool? foreground;
}

/// DEV-PURE s6c DeviceProbeService. This is not a real OS, GPU, or
/// memory probe, and it is not a re-qualification of V-001
/// toolchain probes or I-042 leases.
final class DeviceProbeService {
  bool realProbeInvented = false;
  bool v001Requalified = false;
  bool i042LeaseRequalified = false;
  bool fallbackPlannerRequalified = false;
  bool paidApiCalled = false;

  DeviceSnapshot capture({
    required String platform,
    required String osVersion,
    required String osBuild,
    required String arch,
    required String deviceModel,
    required String gpuId,
    required String gpuDriver,
    String? runtimeBuilds,
    String? physicalMemory,
    String? availableProcessMemory,
    String? deviceLocalBudget,
    String? storageFreeBytes,
    String? thermalStatus,
    bool? foreground,
    String? capturedAt,
    String? probeEpoch,
    Set<String> unknownQuantities = const {},
  }) {
    final values = {
      'physicalMemory': physicalMemory,
      'availableProcessMemory': availableProcessMemory,
      'deviceLocalBudget': deviceLocalBudget,
      'storageFreeBytes': storageFreeBytes,
    };
    for (final name in unknownQuantities) {
      if (!quantityFields.contains(name)) {
        throw StudioException('UNKNOWN_NOT_ZERO', name);
      }
      if (values[name] != null) {
        throw StudioException('UNKNOWN_NOT_ZERO', name);
      }
    }
    for (final entry in values.entries) {
      final unknown =
          unknownQuantities.contains(entry.key) || entry.value == null;
      if (unknown && entry.value == '0') {
        throw StudioException('UNKNOWN_NOT_ZERO', entry.key);
      }
      if (unknown) {
        values[entry.key] = null;
        continue;
      }
      _requireU64(entry.key, entry.value!);
    }
    return DeviceSnapshot(
      platform: platform,
      osVersion: osVersion,
      osBuild: osBuild,
      arch: arch,
      deviceModel: deviceModel,
      gpuId: gpuId,
      gpuDriver: gpuDriver,
      runtimeBuilds: runtimeBuilds,
      physicalMemory: values['physicalMemory'],
      availableProcessMemory: values['availableProcessMemory'],
      deviceLocalBudget: values['deviceLocalBudget'],
      storageFreeBytes: values['storageFreeBytes'],
      thermalStatus: thermalStatus,
      foreground: foreground,
      capturedAt: capturedAt,
      probeEpoch: probeEpoch,
    );
  }

  void _requireU64(String name, String value) {
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      throw StudioException('UNKNOWN_NOT_ZERO', name);
    }
  }
}
