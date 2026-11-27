import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_harness/studio_harness.dart';

import 'play_session.dart';

final class PlayInput {
  PlayInput({
    required this.id,
    required this.scope,
    required this.label,
    this.payload = '',
  }) {
    requireId(id);
  }
  final String id, label, payload;
  final TrustScope scope;
}

/// Device-layer compute intent. Completing it must not advance a story
/// or reveal a solution, and receiving a candidate is not a writer accept.
final class PlayComputeIntent {
  PlayComputeIntent({
    required this.id,
    required List<PlayInput> inputs,
    this.capability = 'compute.digest',
  }) : inputs = List.unmodifiable(inputs) {
    requireId(id);
  }
  final String id, capability;
  final List<PlayInput> inputs;
}

final class PlayComputeCandidate {
  PlayComputeCandidate({
    required this.intentId,
    required this.deviceId,
    required this.resultHash,
    required this.body,
    required this.lease,
  });
  final String intentId, deviceId, resultHash, body;
  final TaskLease lease;
  bool acceptedIntoProject = false;
}

/// Human creative tasks and device leases are two layers. This dispatcher
/// reuses [TaskLease] in-process and never opens a writable peer RPC.
final class PlayComputeDispatcher {
  PlayComputeDispatcher(this.session);
  final PlaySession session;
  final Map<String, TaskLease> leases = {};
  final Map<String, PlayComputeCandidate> candidates = {};

  /// Eligible devices must be allowed to compute and must already be in the
  /// trust scope of every input. Secrets are never prefetched onto others.
  List<PlayDevice> eligibleDevices(PlayComputeIntent intent) {
    return session.devices.values
        .where(
          (d) =>
              d.kind == DeviceKind.compute &&
              d.canCompute &&
              d.online &&
              intent.inputs.every((input) => d.allows(input.scope)),
        )
        .toList();
  }

  /// If no compute device can hold the inputs, run on the authorized host
  /// when the host may see them; otherwise wait (null).
  PlayDevice? chooseDevice(PlayComputeIntent intent) {
    final eligible = eligibleDevices(intent);
    if (eligible.isNotEmpty) {
      eligible.sort((a, b) => a.id.compareTo(b.id));
      return eligible.first;
    }
    final host = session.device(session.hostDeviceId);
    if (host.online &&
        intent.inputs.every((input) => host.allows(input.scope))) {
      return host;
    }
    return null;
  }

  TaskLease claimLease(
    PlayComputeIntent intent, {
    required String deviceId,
    required int nowMs,
    String coordinatorBoot = 'boot',
    BigInt? fence,
  }) {
    final device = session.device(deviceId);
    if (!device.online) {
      throw const StudioException('PLAY_DEVICE_TRUST', 'offline');
    }
    if (!device.canCompute && device.kind != DeviceKind.host) {
      throw const StudioException('PLAY_DEVICE_TRUST', 'not-compute');
    }
    for (final input in intent.inputs) {
      if (!device.allows(input.scope)) {
        throw StudioException('PLAY_PRIVATE_INPUT', input.id);
      }
    }
    final lease = TaskLease(
      sessionId: session.id,
      nodeId: intent.id,
      deviceId: deviceId,
      planHash: 'a' * 64,
      inputHash: _intentHash(intent),
      coordinatorBoot: coordinatorBoot,
      fence: fence ?? BigInt.one,
      cancelEpoch: BigInt.zero,
      untilMs: nowMs + 5000,
    );
    leases[intent.id] = lease;
    return lease;
  }

  /// A compute receipt stays in the play outbox. It cannot transition an act,
  /// publish a clue, or be treated as writer-accepted project state.
  PlayComputeCandidate submitCandidate({
    required PlayComputeIntent intent,
    required TaskLease lease,
    required String body,
  }) {
    final stored = leases[intent.id];
    if (stored == null || stored.deviceId != lease.deviceId) {
      throw const StudioException('PLAY_DEVICE_TRUST', 'lease');
    }
    final candidate = PlayComputeCandidate(
      intentId: intent.id,
      deviceId: lease.deviceId,
      resultHash: 'b' * 64,
      body: body,
      lease: lease,
    );
    candidates[intent.id] = candidate;
    session.computeOutputs.add(
      ViewDocument(
        id: 'compute-${intent.id}',
        title: 'compute',
        body: body,
        scope: intent.inputs.every((i) => i.scope == TrustScope.public)
            ? 'public'
            : intent.inputs.first.scope.id,
      ),
    );
    return candidate;
  }

  void applyComputeResult(
    PlayComputeIntent intent, {
    bool advanceStory = false,
    bool revealTruth = false,
  }) {
    if (advanceStory || revealTruth) {
      throw const StudioException('PLAY_COMPUTE_CANNOT_ADVANCE');
    }
    if (!candidates.containsKey(intent.id)) {
      throw const StudioException('PLAY_TASK_STATE', 'no-candidate');
    }
  }

  static String _intentHash(PlayComputeIntent intent) {
    final seed = intent.inputs.map((i) => '${i.id}:${i.scope.id}').join(',');
    var n = 0;
    final out = StringBuffer();
    for (final unit in seed.codeUnits) {
      n = (n * 33 + unit) & 0xffffffff;
      out.write((n & 0xff).toRadixString(16).padLeft(2, '0'));
    }
    return out.toString().padRight(64, '0').substring(0, 64);
  }
}
