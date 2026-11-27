part of 'edit_algebra.dart';

/// Toggle an existing track's `locked` and/or `syncLock` flags. This is the
/// lock and syncLock half of s3 SetTrackState; muted/solo are not opened
/// here. The track's own lock does not block this meta-op, so a locked
/// track can still be unlocked or have syncLock cleared. Clip, effect, and
/// caption edits on a locked track keep refusing FIELD_LOCKED. Video
/// mute/solo still fail local admission (FEATURE_NOT_IMPLEMENTED). Audio
/// muted/solo stay SetAudioTrackState.
final class SetTrackState extends EditOperation {
  const SetTrackState(this.trackId, {this.locked, this.syncLock});
  final String trackId;
  final bool? locked;
  final bool? syncLock;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'setTrackState',
    'trackId': trackId,
    if (locked != null) 'locked': locked,
    if (syncLock != null) 'syncLock': syncLock,
  };
}

ProjectDocument _setTrackState(
  ProjectDocument before,
  SetTrackState operation,
  VersionAllocator version,
) {
  if (operation.locked == null && operation.syncLock == null) {
    throw const StudioException('INVALID_TRACK_STATE');
  }
  final d = before.toJson(), s = d['sequences'][0];
  final matches = (s['tracks'] as List)
      .where((t) => t['id'] == operation.trackId)
      .toList();
  if (matches.length != 1) {
    throw const StudioException('TRACK_NOT_FOUND');
  }
  final t = matches.single;
  var changed = false;
  if (operation.locked != null && t['locked'] != operation.locked) {
    t['locked'] = operation.locked;
    changed = true;
  }
  if (operation.syncLock != null && t['syncLock'] != operation.syncLock) {
    t['syncLock'] = operation.syncLock;
    changed = true;
  }
  if (!changed) {
    return before;
  }
  s['version'] = version(s['id'] as String);
  final after = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(after);
  return after;
}
