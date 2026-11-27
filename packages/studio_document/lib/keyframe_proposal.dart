import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';

import 'studio_document.dart';

const officialInversePatchKind = 'restoreSnapshot';
const proposalClosed = 'PROPOSAL_CLOSED';
const proposalNotCommitted = 'PROPOSAL_NOT_COMMITTED';

/// One user gesture over registered transform2d@1.0.0 keys. Continuous drag
/// samples coalesce into a single commit. InversePatch kind stays
/// [officialInversePatchKind]; undo restores the before snapshot rather than
/// replaying the samples, and does not create one history node per sample.
final class TransformKeyframeProposal {
  TransformKeyframeProposal({
    required this.before,
    required this.newId,
    required this.nextVersion,
  });

  final ProjectDocument before;
  final IdAllocator newId;
  final VersionAllocator nextVersion;

  final _staged = <EditOperation>[];
  ProjectDocument? _committed;
  var _closed = false;

  String get snapshotHash =>
      contentHash(before.toJson()..remove('revision'));

  Map<String, Object?> get inversePatch => {
    'kind': officialInversePatchKind,
    'snapshotHash': snapshotHash,
  };

  int get historyNodes => _committed == null ? 0 : 1;

  /// Stage a drag sample for one key. [from] is the key's time at gesture
  /// start. Earlier samples for that key in this proposal are replaced so
  /// 30 pointer moves stay one command. Other keys on the same param stay.
  void stageDrag(SetTransformKeyframe op, {Q? from}) {
    _requireOpen();
    final origin = from ?? op.time;
    _staged.removeWhere((e) {
      if (e is SetTransformKeyframe &&
          e.clipId == op.clipId &&
          e.param == op.param) {
        return e.time == op.time || e.time == origin;
      }
      if (e is RemoveTransformKeyframe &&
          e.clipId == op.clipId &&
          e.param == op.param) {
        return e.time == origin;
      }
      return false;
    });
    if (origin != op.time) {
      _staged.add(RemoveTransformKeyframe(op.clipId, origin, op.param));
    }
    _staged.add(op);
  }

  void stage(EditOperation op) {
    _requireOpen();
    if (op is! SetTransformKeyframe && op is! RemoveTransformKeyframe) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
    }
    if (op is SetTransformKeyframe) {
      _staged.removeWhere(
        (e) =>
            e is SetTransformKeyframe &&
            e.clipId == op.clipId &&
            e.param == op.param &&
            e.time == op.time,
      );
    }
    _staged.add(op);
  }

  /// Applies every staged op against [before]. Any refusal leaves the
  /// document unwritten and does not publish a history node.
  ProjectDocument commit() {
    _requireOpen();
    _closed = true;
    var current = before;
    for (final op in _staged) {
      current = applyEdit(
        current,
        op,
        newId: newId,
        nextVersion: nextVersion,
      );
    }
    _committed = current;
    return current;
  }

  /// Cancel writes nothing and is not an undo.
  void cancel() {
    _closed = true;
    _committed = null;
  }

  /// Undo is a new revision whose content equals the before snapshot.
  ProjectDocument restoreSnapshot() {
    if (!_closed || _committed == null) {
      throw const StudioException(proposalNotCommitted);
    }
    final raw =
        jsonDecode(jsonEncode(before.toJson())) as Map<String, dynamic>;
    raw['revision'] = (_committed!.revision + BigInt.one).toString();
    return ProjectDocument.fromJson(raw);
  }

  void _requireOpen() {
    if (_closed) throw const StudioException(proposalClosed);
  }

}
