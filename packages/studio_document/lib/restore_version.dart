import 'package:studio_contracts/studio_contracts.dart';

/// Official I-014 leftover bound: a same-project restore does not roll
/// back event seq, replace SQLite, or restore old approvals. This is a
/// DEV-PURE planner, not a product RestoreService, not a submitted
/// lifecycle transaction, and not a workspace schema change.
const restoreEventSeqRegression = 'EVENT_SEQ_REGRESSION';

enum RestoreActor { user, ai }

/// Locked manual fields default-block. The user may explicitly confirm
/// overwrite or choose fork; AI cannot issue restoreVersion.
enum LockedFieldResolution { blocked, confirmOverwrite, fork }

final class RestoreFieldLock {
  RestoreFieldLock({required this.path}) {
    if (path.isEmpty) {
      throw const StudioException('INVALID_ID', 'lock.path');
    }
  }

  final String path;
}

final class RestoreDiffEntry {
  const RestoreDiffEntry({
    required this.path,
    required this.before,
    required this.after,
  });

  final String path, before, after;
}

/// DEV-PURE s5d restore-version request. Compile/plan does not submit,
/// write SQLite, or roll back event seq.
final class RestoreVersionRequest {
  RestoreVersionRequest({
    required this.projectId,
    required this.currentRevision,
    required this.expectedRevision,
    required this.currentSnapshotHash,
    required this.sourceCheckpointHash,
    required this.sourceRevision,
    this.currentEventSeq = 0,
    this.actor = RestoreActor.user,
    this.locks = const [],
    this.lockedFieldResolution = LockedFieldResolution.blocked,
    this.rollBackEventSeq = false,
    this.replaceSqlite = false,
    this.restoreApprovals = false,
    this.currentTitle = '',
    this.sourceTitle = '',
    this.privacyEpoch = 0,
    this.rightsEpoch = 0,
    this.consent = true,
  }) {
    requireId(projectId);
    _requireSnapshotHash(currentSnapshotHash);
    _requireSnapshotHash(sourceCheckpointHash);
    if (currentRevision < BigInt.zero ||
        expectedRevision < BigInt.zero ||
        sourceRevision < BigInt.zero ||
        currentEventSeq < 0) {
      throw const StudioException('INVALID_ID', 'revision');
    }
  }

  final String projectId, currentSnapshotHash, sourceCheckpointHash;
  final BigInt currentRevision, expectedRevision, sourceRevision;
  final int currentEventSeq, privacyEpoch, rightsEpoch;
  final RestoreActor actor;
  final List<RestoreFieldLock> locks;
  final LockedFieldResolution lockedFieldResolution;
  final bool rollBackEventSeq, replaceSqlite, restoreApprovals, consent;
  final String currentTitle, sourceTitle;
}

final class RestoreVersionPlan {
  RestoreVersionPlan({
    required this.projectId,
    required this.sourceCheckpointHash,
    required this.currentSnapshotHash,
    required this.expectedRevision,
    required this.proposedRevision,
    required this.plannedEventSeq,
    required this.diff,
    required this.protectedFields,
    this.forkChosen = false,
    this.lockedFieldsOverwritten = false,
    this.privacyEpoch = 0,
    this.rightsEpoch = 0,
  });

  final String projectId, sourceCheckpointHash, currentSnapshotHash;
  final BigInt expectedRevision, proposedRevision;
  final int plannedEventSeq, privacyEpoch, rightsEpoch;
  final List<RestoreDiffEntry> diff;
  final List<String> protectedFields;
  final bool forkChosen, lockedFieldsOverwritten;

  int get documentWrites => 0;
  bool get submitted => false;
  bool get eventSeqRolledBack => false;
  bool get sqliteReplaced => false;
  bool get approvalsRestored => false;
  bool get beforeSnapshotPinned => true;
  String get inversePatchKind => 'restoreSnapshot';
}

/// Official s5d leftover planner for 「恢复不倒退事件」.
final class RestoreVersionPlanner {
  int documentWrites = 0;

  RestoreVersionPlan plan(RestoreVersionRequest request) {
    if (request.actor == RestoreActor.ai) {
      throw const StudioException('TOOL_NOT_ALLOWED', 'restoreVersion');
    }
    if (!request.consent) {
      throw const StudioException('APPROVAL_REQUIRED', 'consent');
    }
    if (request.expectedRevision != request.currentRevision) {
      throw const StudioException('REVISION_CONFLICT', 'expectedRevision');
    }
    if (request.rollBackEventSeq) {
      throw const StudioException(restoreEventSeqRegression, 'eventSeq');
    }
    if (request.replaceSqlite) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'sqlite');
    }
    if (request.restoreApprovals) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'approvals');
    }
    final lockedPaths = [for (final lock in request.locks) lock.path];
    if (lockedPaths.isNotEmpty &&
        request.lockedFieldResolution == LockedFieldResolution.blocked) {
      throw const StudioException('FIELD_LOCKED', 'manualFields');
    }

    final diff = <RestoreDiffEntry>[
      if (request.sourceTitle != request.currentTitle)
        RestoreDiffEntry(
          path: 'title',
          before: request.currentTitle,
          after: request.sourceTitle,
        ),
      RestoreDiffEntry(
        path: 'snapshotHash',
        before: request.currentSnapshotHash,
        after: request.sourceCheckpointHash,
      ),
    ];

    documentWrites = 0;
    return RestoreVersionPlan(
      projectId: request.projectId,
      sourceCheckpointHash: request.sourceCheckpointHash,
      currentSnapshotHash: request.currentSnapshotHash,
      expectedRevision: request.expectedRevision,
      proposedRevision: request.currentRevision + BigInt.one,
      plannedEventSeq: request.currentEventSeq + 1,
      diff: diff,
      protectedFields: lockedPaths,
      forkChosen: request.lockedFieldResolution == LockedFieldResolution.fork,
      lockedFieldsOverwritten:
          lockedPaths.isNotEmpty &&
          request.lockedFieldResolution ==
              LockedFieldResolution.confirmOverwrite,
      privacyEpoch: request.privacyEpoch,
      rightsEpoch: request.rightsEpoch,
    );
  }
}

final _snapshotHash = RegExp(r'^(sha256:)?[a-f0-9]{64}$');

void _requireSnapshotHash(String value) {
  if (!_snapshotHash.hasMatch(value)) {
    throw const StudioException('INVALID_ID', 'snapshotHash');
  }
}
