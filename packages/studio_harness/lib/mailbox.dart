import 'package:studio_contracts/studio_contracts.dart';

import 'budget.dart';
import 'roles.dart';

const mailExpired = 'MAIL_EXPIRED';
const delegationNotAdjacent = 'DELEGATION_NOT_ADJACENT';
const runNotFound = 'RUN_NOT_FOUND';
const mailKindInvalid = 'MAIL_KIND_INVALID';
const staleRightsEpoch = 'STALE_RIGHTS_EPOCH';
const critiqueEvidenceMissing = 'CRITIQUE_EVIDENCE_MISSING';
const noProgress = 'NO_PROGRESS';
const manualLocked = 'MANUAL_LOCKED';
const idempotencyConflict = 'IDEMPOTENCY_CONFLICT';

const _hash = r'^[a-f0-9]{64}$';
const _mailKinds = {'task', 'artifact', 'critique', 'decision', 'cancel'};

void requireHash(String value, [String path = 'hash']) {
  if (!RegExp(_hash).hasMatch(value)) {
    throw StudioException('INVALID_ID', path);
  }
}

String namespaceId(Namespace ns) =>
    '${ns.appId}.${ns.tenantId}.${ns.workspaceId}';

final class ArtifactRef {
  ArtifactRef({
    required this.ns,
    required this.id,
    required this.version,
    required this.hash,
  }) {
    requireId(ns);
    requireId(id);
    if (version < 0) throw const StudioException('INVALID_ID', 'version');
    requireHash(hash);
  }

  final String ns, id, hash;
  final int version;

  String get key => '$ns/$id@$version:$hash';
}

final class PlanPin {
  PlanPin({required this.id, required this.version, required this.hash}) {
    requireId(id);
    if (version < 0) throw const StudioException('INVALID_ID', 'version');
    requireHash(hash);
  }

  final String id, hash;
  final int version;
}

/// s10i AgentMail. This is a DEV-PURE protocol record, not a project-store row.
final class AgentMail {
  AgentMail({
    required this.ns,
    required this.id,
    required this.fromRunId,
    required this.toRunId,
    required this.correlationId,
    required this.planPin,
    required this.kind,
    required this.snapshotHash,
    required this.constraintsHash,
    required this.artifactRefs,
    required this.privacyEpoch,
    required this.rightsEpoch,
    required this.createdEventSeq,
    required this.expiresAtMs,
  }) {
    requireId(ns);
    requireId(id);
    requireId(fromRunId);
    requireId(toRunId);
    requireId(correlationId);
    if (!_mailKinds.contains(kind)) {
      throw StudioException(mailKindInvalid, kind);
    }
    requireHash(snapshotHash, 'snapshotHash');
    requireHash(constraintsHash, 'constraintsHash');
    if (artifactRefs.length > 16) {
      throw const StudioException('INVALID_ID', 'artifactRefs');
    }
    if ({for (final ref in artifactRefs) ref.key}.length !=
        artifactRefs.length) {
      throw const StudioException('INVALID_ID', 'artifactRefs');
    }
    if (privacyEpoch < 0 ||
        rightsEpoch < 0 ||
        createdEventSeq < 0 ||
        expiresAtMs < 0) {
      throw const StudioException('INVALID_ID', 'epoch');
    }
  }

  final String recordType = 'AgentMail';
  final String schemaVersion = '1.0.0';
  final String ns, id, fromRunId, toRunId, correlationId, kind;
  final PlanPin planPin;
  final String snapshotHash, constraintsHash;
  final List<ArtifactRef> artifactRefs;
  final int privacyEpoch, rightsEpoch, createdEventSeq, expiresAtMs;
}

enum MailDelivery { live, tombstone }

final class MailboxEnvelope {
  MailboxEnvelope({
    required this.seq,
    required this.mail,
    required this.delivery,
    required this.hash,
  });

  final int seq;
  final AgentMail mail;
  final MailDelivery delivery;
  final String hash;
}

final class _Run {
  _Run({
    required this.id,
    required this.role,
    required this.privacyEpoch,
    required this.rightsEpoch,
  });

  final String id;
  final AgentRole role;
  final int privacyEpoch, rightsEpoch;
  final adjacent = <String>{};
  bool ended = false;
}

/// In-memory s10e AgentMailbox. Protocol only: not workspace SQLite w5,
/// and not a project-document write path. user_version stays 9.
final class AgentMailbox {
  AgentMailbox({required this.namespace});

  final Namespace namespace;
  final Map<String, _Run> _runs = {};
  final Map<String, AgentMail> _outbox = {};
  final Map<String, MailboxEnvelope> _published = {};
  final Set<String> _deletedArtifacts = {};
  final Map<String, Map<String, String>> _acks = {};
  int _seq = 0;

  String get ns => namespaceId(namespace);

  void registerRun({
    required String runId,
    required AgentRole role,
    required int privacyEpoch,
    required int rightsEpoch,
    Iterable<String> adjacentTo = const [],
  }) {
    requireId(runId);
    if (privacyEpoch < 0 || rightsEpoch < 0) {
      throw const StudioException('INVALID_ID', 'epoch');
    }
    final run = _Run(
      id: runId,
      role: role,
      privacyEpoch: privacyEpoch,
      rightsEpoch: rightsEpoch,
    );
    for (final other in adjacentTo) {
      requireId(other);
      run.adjacent.add(other);
    }
    _runs[runId] = run;
  }

  void addDelegation(String fromRunId, String toRunId) {
    _requireRun(fromRunId).adjacent.add(toRunId);
    _requireRun(toRunId);
  }

  void endRun(String runId) => _requireRun(runId).ended = true;

  void deleteArtifact(ArtifactRef ref) => _deletedArtifacts.add(ref.key);

  void send(AgentMail mail) {
    if (mail.ns != ns) {
      throw StudioException('NAMESPACE_MISMATCH', mail.ns);
    }
    final from = _requireRun(mail.fromRunId);
    final to = _requireRun(mail.toRunId);
    if (!from.adjacent.contains(mail.toRunId)) {
      throw StudioException(delegationNotAdjacent, mail.toRunId);
    }
    if (mail.privacyEpoch != from.privacyEpoch ||
        mail.privacyEpoch != to.privacyEpoch) {
      throw StudioException('STALE_PRIVACY_EPOCH', '${mail.privacyEpoch}');
    }
    if (mail.rightsEpoch != from.rightsEpoch ||
        mail.rightsEpoch != to.rightsEpoch) {
      throw StudioException(staleRightsEpoch, '${mail.rightsEpoch}');
    }
    final existing = _outbox[mail.id] ?? _published[mail.id]?.mail;
    if (existing != null) {
      if (_fingerprint(existing) != _fingerprint(mail)) {
        throw StudioException(idempotencyConflict, mail.id);
      }
      return;
    }
    _outbox[mail.id] = mail;
  }

  int publish(String mailId, {required int nowMs}) {
    final mail = _outbox[mailId];
    if (mail == null) {
      final already = _published[mailId];
      if (already != null) return already.seq;
      throw StudioException(runNotFound, mailId);
    }
    if (nowMs >= mail.expiresAtMs) {
      throw StudioException(mailExpired, mailId);
    }
    _outbox.remove(mailId);
    _seq += 1;
    final envelope = MailboxEnvelope(
      seq: _seq,
      mail: mail,
      delivery: _delivery(mail),
      hash: _fingerprint(mail),
    );
    _published[mailId] = envelope;
    return envelope.seq;
  }

  void ack({
    required String consumerId,
    required String messageId,
    required String hash,
  }) {
    requireId(consumerId);
    final envelope = _published[messageId];
    if (envelope == null) throw StudioException(runNotFound, messageId);
    final seen = _acks.putIfAbsent(consumerId, () => {});
    final previous = seen[messageId];
    if (previous != null) {
      if (previous != hash) {
        throw StudioException(idempotencyConflict, messageId);
      }
      return;
    }
    if (hash != envelope.hash) {
      throw StudioException(idempotencyConflict, messageId);
    }
    seen[messageId] = hash;
  }

  List<MailboxEnvelope> replay({
    required String consumerId,
    required int afterSeq,
  }) {
    requireId(consumerId);
    if (afterSeq < 0) throw const StudioException('INVALID_ID', 'afterSeq');
    final rows = _published.values.where((row) => row.seq > afterSeq).toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    return [
      for (final row in rows)
        MailboxEnvelope(
          seq: row.seq,
          mail: row.mail,
          delivery: _delivery(row.mail),
          hash: row.hash,
        ),
    ];
  }

  MailDelivery _delivery(AgentMail mail) {
    for (final ref in mail.artifactRefs) {
      if (_deletedArtifacts.contains(ref.key)) return MailDelivery.tombstone;
    }
    return MailDelivery.live;
  }

  _Run _requireRun(String runId) {
    final run = _runs[runId];
    if (run == null) throw StudioException(runNotFound, runId);
    return run;
  }

  String _fingerprint(AgentMail mail) => [
    mail.ns,
    mail.id,
    mail.fromRunId,
    mail.toRunId,
    mail.correlationId,
    mail.kind,
    mail.snapshotHash,
    mail.constraintsHash,
    mail.planPin.hash,
    for (final ref in mail.artifactRefs) ref.key,
    '${mail.privacyEpoch}',
    '${mail.rightsEpoch}',
    '${mail.createdEventSeq}',
    '${mail.expiresAtMs}',
  ].join('|');
}

/// Critique must name a concrete field and evidence. Director vs Editor
/// contention yields mutually exclusive PatchGroups as values only; this
/// object never writes a project database.
final class Critique {
  Critique({
    required this.findingRefs,
    required this.subjectPin,
    required this.proposedRepairRef,
    required this.field,
    required this.inputHash,
    required this.outputHash,
    required this.round,
  }) {
    requireId(subjectPin);
    requireId(field);
    if (findingRefs.isEmpty || proposedRepairRef.isEmpty) {
      throw const StudioException(critiqueEvidenceMissing);
    }
    for (final ref in findingRefs) {
      requireId(ref);
    }
    requireId(proposedRepairRef);
    requireHash(inputHash, 'inputHash');
    requireHash(outputHash, 'outputHash');
    if (round < 1) throw const StudioException('INVALID_ID', 'round');
  }

  final List<String> findingRefs;
  final String subjectPin, proposedRepairRef, field;
  final String inputHash, outputHash;
  final int round;
}

final class ExclusivePatchGroup {
  ExclusivePatchGroup({
    required this.id,
    required this.role,
    required this.field,
    required this.proposalHash,
  }) {
    requireId(id);
    requireId(field);
    requireHash(proposalHash, 'proposalHash');
  }

  final String id, field, proposalHash;
  final AgentRole role;
}

final class ConflictDecision {
  ConflictDecision({
    required this.applied,
    required this.paused,
    required this.needsHuman,
    required this.exclusiveGroups,
    this.code,
  });

  final bool applied, paused, needsHuman;
  final List<ExclusivePatchGroup> exclusiveGroups;
  final String? code;

  /// Protocol proof: the arbiter has no project-document write side effect.
  int get documentWrites => 0;
}

final class _SubjectState {
  int rounds = 0;
  String? inputHash;
  String? outputHash;
  List<String> evidence = const [];
}

/// s10e conflict/arbiter protocol. PatchGroups are never applied here.
final class ConflictResolution {
  ConflictResolution({this.parentBudget});

  final BudgetLedger? parentBudget;
  bool debatePaused = false;
  int documentWrites = 0;
  final Map<String, _SubjectState> _subjects = {};

  ConflictDecision arbitrate({
    required Critique critique,
    ExclusivePatchGroup? directorGroup,
    ExclusivePatchGroup? editorGroup,
    Set<String> lockedFields = const {},
  }) {
    if (debatePaused ||
        parentBudget?.paused == true ||
        (parentBudget?.available ?? 1) <= 0) {
      debatePaused = true;
      throw const StudioException(budgetExhausted);
    }
    if (lockedFields.contains(critique.field)) {
      throw StudioException(manualLocked, critique.field);
    }
    final state = _subjects.putIfAbsent(critique.subjectPin, _SubjectState.new);
    final sameHash =
        state.inputHash == critique.inputHash &&
        state.outputHash == critique.outputHash;
    final noNewEvidence =
        state.evidence.isNotEmpty &&
        _sameSet(state.evidence, critique.findingRefs);
    if (state.rounds >= 2 || (state.rounds >= 1 && sameHash && noNewEvidence)) {
      debatePaused = true;
      throw const StudioException(noProgress);
    }
    if (critique.round > 2 || state.rounds + 1 > 2) {
      debatePaused = true;
      throw const StudioException(noProgress);
    }
    state.rounds += 1;
    state.inputHash = critique.inputHash;
    state.outputHash = critique.outputHash;
    state.evidence = List.of(critique.findingRefs);

    final groups = [?directorGroup, ?editorGroup];
    if (directorGroup != null &&
        editorGroup != null &&
        directorGroup.field == editorGroup.field) {
      // Mutually exclusive proposals; never auto-applied, never a DB write.
      return ConflictDecision(
        applied: false,
        paused: false,
        needsHuman: true,
        exclusiveGroups: groups,
      );
    }
    return ConflictDecision(
      applied: false,
      paused: false,
      needsHuman: groups.length != 1,
      exclusiveGroups: groups,
    );
  }

  bool _sameSet(List<String> a, List<String> b) =>
      a.length == b.length && {...a}.containsAll(b);
}
