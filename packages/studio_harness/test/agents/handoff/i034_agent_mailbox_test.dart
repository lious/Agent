import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:test/test.dart';

/// Increment 2.36 official I-034 first DEV-PURE protocol slice.
/// Officializes leftover acceptance wording 「fake仅测协议」,
/// 「冲突不直接写DB」, and 「争论超界暂停」 on AgentMailbox,
/// RoleProfile, and ConflictResolution. This file does not claim
/// two real modelId / weight packs, does not call a paid API, does
/// not merge workspace SQLite w5, and does not invent a PatchGroup
/// cherry-pick or chat workbench UI.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

const hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const hashB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const hashC =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

final ns = Namespace('studio', 'local', 'i034-mailbox');

PlanPin pin() => PlanPin(id: 'plan-1', version: 1, hash: hashA);

ArtifactRef artifact({String id = 'art-1'}) => ArtifactRef(
  ns: 'studio-local-i034-mailbox',
  id: id,
  version: 1,
  hash: hashB,
);

AgentMail mail({
  required String id,
  String? nsId,
  String from = 'run-director',
  String to = 'run-editor',
  String kind = 'artifact',
  int privacy = 1,
  int rights = 1,
  int expires = 1000,
  List<ArtifactRef>? refs,
}) => AgentMail(
  ns: nsId ?? namespaceId(ns),
  id: id,
  fromRunId: from,
  toRunId: to,
  correlationId: 'corr-1',
  planPin: pin(),
  kind: kind,
  snapshotHash: hashA,
  constraintsHash: hashC,
  artifactRefs: refs ?? [artifact()],
  privacyEpoch: privacy,
  rightsEpoch: rights,
  createdEventSeq: 0,
  expiresAtMs: expires,
);

void seed(AgentMailbox box) {
  box.registerRun(
    runId: 'run-director',
    role: AgentRole.director,
    privacyEpoch: 1,
    rightsEpoch: 1,
    adjacentTo: ['run-editor'],
  );
  box.registerRun(
    runId: 'run-editor',
    role: AgentRole.editor,
    privacyEpoch: 1,
    rightsEpoch: 1,
  );
}

Critique critique({
  int round = 1,
  String input = hashA,
  String output = hashB,
  List<String> findings = const ['frame-12'],
}) => Critique(
  findingRefs: findings,
  subjectPin: 'clip-B',
  proposedRepairRef: 'repair-1',
  field: 'clip.source',
  inputHash: input,
  outputHash: output,
  round: round,
);

ExclusivePatchGroup group(AgentRole role, String id) => ExclusivePatchGroup(
  id: id,
  role: role,
  field: 'clip.source',
  proposalHash: role == AgentRole.director ? hashA : hashB,
);

void main() {
  test('RoleProfile accepts specified roles; editor only proposes, critic is read-only', () {
    final director = RoleProfile(
      role: AgentRole.director,
      pin: 'role-director',
      allowedToolPins: ['tool-plan'],
      scopePolicy: ScopePolicy.intentPlanning,
      maxChildRuns: 3,
      budgetShare: 40,
      modelProfilePin: 'model-text',
    );
    final editor = RoleProfile(
      role: AgentRole.editor,
      pin: 'role-editor',
      allowedToolPins: ['tool-edit-propose'],
      scopePolicy: ScopePolicy.editCommandProposal,
      maxChildRuns: 0,
      budgetShare: 20,
      modelProfilePin: 'model-local',
    );
    final critic = RoleProfile(
      role: AgentRole.critic,
      pin: 'role-critic',
      allowedToolPins: ['tool-qa'],
      scopePolicy: ScopePolicy.readOnlyQa,
      maxChildRuns: 0,
      budgetShare: 10,
      modelProfilePin: 'model-qa',
    );
    expect(editor.proposesEditsOnly, isTrue);
    expect(editor.isReadOnly, isFalse);
    expect(critic.isReadOnly, isTrue);
    expect(director.isReadOnly, isFalse);
    expect(
      () => RoleProfile(
        role: AgentRole.editor,
        pin: 'role-editor-bad',
        allowedToolPins: const [],
        scopePolicy: ScopePolicy.intentPlanning,
        maxChildRuns: 0,
        budgetShare: 1,
        modelProfilePin: 'model-local',
      ),
      code('ROLE_SCOPE_MISMATCH'),
    );
    expect(
      () => RoleProfile(
        role: AgentRole.critic,
        pin: 'role-critic-bad',
        allowedToolPins: const [],
        scopePolicy: ScopePolicy.editCommandProposal,
        maxChildRuns: 0,
        budgetShare: 1,
        modelProfilePin: 'model-qa',
      ),
      code('ROLE_SCOPE_MISMATCH'),
    );
  });

  test('send/publish/ack/replay stay in-namespace and adjacent; expired mail and deleted artifacts do not restore a body', () {
    final box = AgentMailbox(namespace: ns);
    seed(box);
    expect(
      () => AgentMail(
        ns: namespaceId(ns),
        id: 'mail-kind',
        fromRunId: 'run-director',
        toRunId: 'run-editor',
        correlationId: 'corr-1',
        planPin: pin(),
        kind: 'system',
        snapshotHash: hashA,
        constraintsHash: hashC,
        artifactRefs: const [],
        privacyEpoch: 1,
        rightsEpoch: 1,
        createdEventSeq: 0,
        expiresAtMs: 1000,
      ),
      code(mailKindInvalid),
    );

    final first = mail(id: 'mail-1');
    box.send(first);
    box.send(mail(id: 'mail-1')); // identical fingerprint is idempotent
    expect(
      () => box.send(mail(id: 'mail-1', kind: 'task')),
      code(idempotencyConflict),
    );
    expect(
      () => box.send(mail(id: 'mail-ns', nsId: 'other-app')),
      code('NAMESPACE_MISMATCH'),
    );
    box.registerRun(
      runId: 'run-sound',
      role: AgentRole.sound,
      privacyEpoch: 1,
      rightsEpoch: 1,
    );
    expect(
      () => box.send(mail(id: 'mail-far', to: 'run-sound')),
      code(delegationNotAdjacent),
    );
    expect(
      () => box.send(mail(id: 'mail-epoch', privacy: 2)),
      code('STALE_PRIVACY_EPOCH'),
    );
    expect(
      () => box.send(mail(id: 'mail-rights', rights: 2)),
      code(staleRightsEpoch),
    );

    final seq = box.publish('mail-1', nowMs: 10);
    expect(seq, 1);
    expect(box.publish('mail-1', nowMs: 11), 1);
    box.ack(
      consumerId: 'editor',
      messageId: 'mail-1',
      hash: box.replay(consumerId: 'editor', afterSeq: 0).single.hash,
    );
    box.ack(
      consumerId: 'editor',
      messageId: 'mail-1',
      hash: box.replay(consumerId: 'editor', afterSeq: 0).single.hash,
    );

    box.send(mail(id: 'mail-late', expires: 50));
    expect(() => box.publish('mail-late', nowMs: 50), code(mailExpired));
    expect(box.replay(consumerId: 'editor', afterSeq: 0).length, 1);

    box.send(
      mail(
        id: 'mail-2',
        refs: [artifact(id: 'art-gone')],
      ),
    );
    box.publish('mail-2', nowMs: 20);
    box.deleteArtifact(artifact(id: 'art-gone'));
    final replayed = box.replay(consumerId: 'editor', afterSeq: 0);
    expect(replayed.map((row) => row.mail.id).toList(), ['mail-1', 'mail-2']);
    expect(replayed.first.delivery, MailDelivery.live);
    expect(replayed.last.delivery, MailDelivery.tombstone);
    expect(replayed.last.mail.artifactRefs.single.id, 'art-gone');
  });

  test('director and editor conflict on the same field yields exclusive PatchGroups and does not write a project database', () {
    final arbiter = ConflictResolution();
    final decision = arbiter.arbitrate(
      critique: critique(),
      directorGroup: group(AgentRole.director, 'pg-d'),
      editorGroup: group(AgentRole.editor, 'pg-e'),
    );
    expect(decision.applied, isFalse);
    expect(decision.needsHuman, isTrue);
    expect(decision.documentWrites, 0);
    expect(arbiter.documentWrites, 0);
    expect(decision.exclusiveGroups.map((g) => g.id).toList(), [
      'pg-d',
      'pg-e',
    ]);
    expect(
      () => arbiter.arbitrate(
        critique: Critique(
          findingRefs: const ['cue-B'],
          subjectPin: 'cue-B',
          proposedRepairRef: 'repair-cap',
          field: 'caption.text',
          inputHash: hashA,
          outputHash: hashB,
          round: 1,
        ),
        directorGroup: ExclusivePatchGroup(
          id: 'pg-cap',
          role: AgentRole.director,
          field: 'caption.text',
          proposalHash: hashC,
        ),
        lockedFields: {'caption.text'},
      ),
      code(manualLocked),
    );
    expect(arbiter.documentWrites, 0);
    expect(
      () => Critique(
        findingRefs: const [],
        subjectPin: 'clip-B',
        proposedRepairRef: 'repair-1',
        field: 'clip.source',
        inputHash: hashA,
        outputHash: hashB,
        round: 1,
      ),
      code(critiqueEvidenceMissing),
    );
  });

  test('a third critique, a repeated hash with no new evidence, or an exhausted parent budget pauses the debate', () {
    final first = ConflictResolution();
    first.arbitrate(
      critique: critique(round: 1),
      directorGroup: group(AgentRole.director, 'pg-d1'),
      editorGroup: group(AgentRole.editor, 'pg-e1'),
    );
    first.arbitrate(
      critique: critique(
        round: 2,
        findings: const ['frame-12', 'frame-40'],
        output: hashC,
      ),
      directorGroup: group(AgentRole.director, 'pg-d2'),
      editorGroup: group(AgentRole.editor, 'pg-e2'),
    );
    expect(
      () => first.arbitrate(
        critique: critique(
          round: 3,
          findings: const ['frame-99'],
          output: hashA,
        ),
        directorGroup: group(AgentRole.director, 'pg-d3'),
        editorGroup: group(AgentRole.editor, 'pg-e3'),
      ),
      code(noProgress),
    );
    expect(first.debatePaused, isTrue);
    expect(first.documentWrites, 0);

    final repeated = ConflictResolution();
    repeated.arbitrate(
      critique: critique(round: 1),
      directorGroup: group(AgentRole.director, 'pg-d'),
      editorGroup: group(AgentRole.editor, 'pg-e'),
    );
    expect(
      () => repeated.arbitrate(
        critique: critique(round: 2),
        directorGroup: group(AgentRole.director, 'pg-d'),
        editorGroup: group(AgentRole.editor, 'pg-e'),
      ),
      code(noProgress),
    );
    expect(repeated.debatePaused, isTrue);

    final ledger = BudgetLedger(capacity: 1);
    ledger.reserve(amount: 1, resourceId: 'parent-run', revision: 1);
    final exhausted = ConflictResolution(parentBudget: ledger);
    expect(
      () => exhausted.arbitrate(
        critique: critique(),
        directorGroup: group(AgentRole.director, 'pg-d'),
        editorGroup: group(AgentRole.editor, 'pg-e'),
      ),
      code(budgetExhausted),
    );
    expect(exhausted.debatePaused, isTrue);
    expect(exhausted.documentWrites, 0);
  });
}
