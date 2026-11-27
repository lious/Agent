import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

/// Increment 2.51 official I-014 leftover 「恢复不倒退事件」.
/// RestoreVersionPlanner plans a same-project restore as head+1 and
/// does not roll back event seq, replace SQLite, restore old approvals,
/// or submit. This is not a product RestoreService, not a durable
/// mailbox, not schema v10, and does not rewrite files_test.dart,
/// i014_auto_external_link_refusal_test.dart, or the frozen I-036
/// fts5Enabled==false assertions. InversePatch kind stays
/// restoreSnapshot. Job archival is not invented.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

const currentHash =
    'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const sourceHash =
    'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

RestoreVersionRequest request({
  BigInt? currentRevision,
  BigInt? expectedRevision,
  BigInt? sourceRevision,
  int currentEventSeq = 7,
  RestoreActor actor = RestoreActor.user,
  List<RestoreFieldLock> locks = const [],
  LockedFieldResolution lockedFieldResolution = LockedFieldResolution.blocked,
  bool rollBackEventSeq = false,
  bool replaceSqlite = false,
  bool restoreApprovals = false,
  bool consent = true,
  String currentTitle = 'R5 title',
  String sourceTitle = 'R2 title',
}) => RestoreVersionRequest(
  projectId: 'p-restore-1',
  currentRevision: currentRevision ?? BigInt.from(5),
  expectedRevision: expectedRevision ?? BigInt.from(5),
  currentSnapshotHash: currentHash,
  sourceCheckpointHash: sourceHash,
  sourceRevision: sourceRevision ?? BigInt.two,
  currentEventSeq: currentEventSeq,
  actor: actor,
  locks: locks,
  lockedFieldResolution: lockedFieldResolution,
  rollBackEventSeq: rollBackEventSeq,
  replaceSqlite: replaceSqlite,
  restoreApprovals: restoreApprovals,
  currentTitle: currentTitle,
  sourceTitle: sourceTitle,
  privacyEpoch: 3,
  rightsEpoch: 4,
  consent: consent,
);

void main() {
  test('a user restore plan advances head+1, pins the before snapshot, keeps InversePatch as restoreSnapshot, and does not roll back event seq or submit', () {
    final planner = RestoreVersionPlanner();
    final plan = planner.plan(request());
    expect(plan.proposedRevision, BigInt.from(6));
    expect(plan.proposedRevision, isNot(BigInt.two));
    expect(plan.plannedEventSeq, 8);
    expect(plan.plannedEventSeq, greaterThan(7));
    expect(plan.eventSeqRolledBack, isFalse);
    expect(plan.sqliteReplaced, isFalse);
    expect(plan.approvalsRestored, isFalse);
    expect(plan.beforeSnapshotPinned, isTrue);
    expect(plan.inversePatchKind, 'restoreSnapshot');
    expect(plan.currentSnapshotHash, currentHash);
    expect(plan.sourceCheckpointHash, sourceHash);
    expect(plan.expectedRevision, BigInt.from(5));
    expect(plan.privacyEpoch, 3);
    expect(plan.rightsEpoch, 4);
    expect(plan.diff, isNotEmpty);
    expect(
      plan.diff.any((d) => d.path == 'title' && d.after == 'R2 title'),
      isTrue,
    );
    expect(plan.submitted, isFalse);
    expect(plan.documentWrites, 0);
    expect(planner.documentWrites, 0);
  });

  test('locked manual fields default-block; explicit overwrite or fork is required; AI cannot issue restoreVersion', () {
    final planner = RestoreVersionPlanner();
    final locks = [RestoreFieldLock(path: 'title')];
    expect(() => planner.plan(request(locks: locks)), code('FIELD_LOCKED'));

    final overwritten = planner.plan(
      request(
        locks: locks,
        lockedFieldResolution: LockedFieldResolution.confirmOverwrite,
      ),
    );
    expect(overwritten.lockedFieldsOverwritten, isTrue);
    expect(overwritten.forkChosen, isFalse);
    expect(overwritten.protectedFields, ['title']);
    expect(overwritten.submitted, isFalse);

    final forked = planner.plan(
      request(locks: locks, lockedFieldResolution: LockedFieldResolution.fork),
    );
    expect(forked.forkChosen, isTrue);
    expect(forked.lockedFieldsOverwritten, isFalse);
    expect(forked.submitted, isFalse);
    expect(forked.eventSeqRolledBack, isFalse);

    expect(
      () => planner.plan(request(actor: RestoreActor.ai)),
      code('TOOL_NOT_ALLOWED'),
    );
    expect(planner.documentWrites, 0);
  });

  test('rolling back event seq, replacing SQLite, restoring approvals, a CAS mismatch, and missing consent are refused and do not submit', () {
    final planner = RestoreVersionPlanner();
    expect(
      () => planner.plan(request(rollBackEventSeq: true)),
      code(restoreEventSeqRegression),
    );
    expect(
      () => planner.plan(request(replaceSqlite: true)),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => planner.plan(request(restoreApprovals: true)),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => planner.plan(request(expectedRevision: BigInt.from(4))),
      code('REVISION_CONFLICT'),
    );
    expect(
      () => planner.plan(request(consent: false)),
      code('APPROVAL_REQUIRED'),
    );
    expect(planner.documentWrites, 0);
  });
}
