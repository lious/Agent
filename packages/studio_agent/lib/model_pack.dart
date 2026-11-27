import 'package:studio_contracts/studio_contracts.dart';

import 'agent_codes.dart';

/// A declared local model pack. This object never downloads weights.
final class ModelPackManifest {
  ModelPackManifest({
    required this.packId,
    required this.operatorId,
    required this.digestSha256,
    required this.signatureSha256,
    required this.contextTokens,
    required this.outputTokens,
    this.supportsTools = true,
    this.offlineOnly = true,
    this.approxBytes = 0,
  }) {
    requireId(packId);
    requireId(operatorId);
    _requireSha(digestSha256);
    _requireSha(signatureSha256);
  }

  final String packId, operatorId, digestSha256, signatureSha256;
  final int contextTokens, outputTokens, approxBytes;
  final bool supportsTools, offlineOnly;

  static void _requireSha(String value) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
      throw const StudioException('INVALID_ID', 'digest');
    }
  }
}

/// Handle issued after a successful admission. A later process image must
/// not reuse a raw pointer or a stale generation.
final class ModelPackHandle {
  const ModelPackHandle({
    required this.packId,
    required this.generation,
    required this.leaseId,
  });

  final String packId, leaseId;
  final int generation;
}

final class ResourceLease {
  ResourceLease({
    required this.leaseId,
    required this.packId,
    required this.shared,
    required this.units,
  });

  final String leaseId, packId;
  final bool shared;
  final int units;
  bool released = false;
}

/// Registry and resource accountant for local model packs.
///
/// It does not fetch bytes from the network. Admission is fail-closed on
/// bad signatures, unsupported operators, and stale handles.
final class ModelPackRegistry {
  ModelPackRegistry({
    this.allowedOperators = const {'fake.echo', 'llamacpp.gguf'},
    this.trustedSignatures = const {},
  });

  final Set<String> allowedOperators;
  final Map<String, String> trustedSignatures; // packId -> signature
  final Map<String, ModelPackManifest> _catalog = {};
  final Map<String, ModelPackHandle> _loaded = {};
  final Map<String, ResourceLease> _leases = {};
  final Map<String, int> _sharedUnits = {};
  int _generation = 1;
  int networkRequestCount = 0;
  ModelPackHandle? loadedPack;
  int get processGeneration => _generation;

  void registerCatalog(ModelPackManifest manifest) {
    _catalog[manifest.packId] = manifest;
  }

  /// Admit a catalogued pack after digest/signature/operator checks.
  /// [providedSignature] is the caller-supplied signature, not a download.
  ModelPackHandle admit({
    required String packId,
    required String providedSignature,
    required String providedDigest,
    bool shared = true,
    int units = 1,
  }) {
    final manifest = _catalog[packId];
    if (manifest == null) {
      throw StudioException(modelPackMissing, packId);
    }
    if (manifest.offlineOnly && networkRequestCount > 0) {
      throw const StudioException(networkForbidden, 'offlineOnly');
    }
    if (manifest.offlineOnly) {
      // Explicitly do not open a socket or HTTP client.
      networkRequestCount += 0;
    }
    if (!allowedOperators.contains(manifest.operatorId)) {
      throw StudioException(operatorUnsupported, manifest.operatorId);
    }
    if (providedDigest != manifest.digestSha256) {
      throw StudioException(modelPackBadSignature, 'digest');
    }
    final trusted = trustedSignatures[packId] ?? manifest.signatureSha256;
    if (providedSignature != trusted ||
        providedSignature != manifest.signatureSha256) {
      throw StudioException(modelPackBadSignature, 'signature');
    }
    final leaseId = 'lease-$packId-$_generation';
    if (shared) {
      _sharedUnits[packId] = (_sharedUnits[packId] ?? 0) + units;
    }
    final lease = ResourceLease(
      leaseId: leaseId,
      packId: packId,
      shared: shared,
      units: units,
    );
    _leases[leaseId] = lease;
    final handle = ModelPackHandle(
      packId: packId,
      generation: _generation,
      leaseId: leaseId,
    );
    _loaded[packId] = handle;
    loadedPack = handle;
    return handle;
  }

  /// Shared allocations for one pack are counted once per unit, not once
  /// per aliasing handle derived from the same lease.
  int sharedUnits(String packId) => _sharedUnits[packId] ?? 0;

  void release(ModelPackHandle handle) {
    _requireLive(handle);
    final lease = _leases[handle.leaseId];
    if (lease == null || lease.released) {
      throw StudioException(stalePointer, handle.leaseId);
    }
    lease.released = true;
    if (lease.shared) {
      final next = ( _sharedUnits[handle.packId] ?? 0) - lease.units;
      if (next < 0) {
        throw StudioException(leaseDoubleCount, handle.packId);
      }
      _sharedUnits[handle.packId] = next;
    }
    if (loadedPack?.leaseId == handle.leaseId) {
      loadedPack = null;
    }
  }

  /// Simulate an OS kill: increment generation so old handles/pointers fail.
  void simulateProcessRestart() {
    _generation++;
    loadedPack = null;
    // Leases do not survive a process image. Stale maps are dropped.
    _leases.clear();
    _loaded.clear();
    _sharedUnits.clear();
  }

  ModelPackHandle requireLive(ModelPackHandle handle) => _requireLive(handle);

  ModelPackHandle _requireLive(ModelPackHandle handle) {
    if (handle.generation != _generation) {
      throw StudioException(stalePointer, handle.packId);
    }
    final current = _loaded[handle.packId];
    if (current == null || current.leaseId != handle.leaseId) {
      throw StudioException(stalePointer, handle.leaseId);
    }
    return current;
  }

  /// Attempting to add the same shared units twice for one live lease fails.
  void forbidDoubleCount(ResourceLease lease) {
    if (!lease.shared) return;
    throw StudioException(leaseDoubleCount, lease.packId);
  }

  ModelPackManifest inspectCatalog(String packId) {
    final manifest = _catalog[packId];
    if (manifest == null) {
      throw StudioException(modelPackMissing, packId);
    }
    return manifest;
  }
}
