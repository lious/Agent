part of 'edit_algebra.dart';

/// Toggle one existing track's `locked` flag. This is the lock half of s3
/// SetTrackState; muted/solo/syncLock are not opened here. The track's own
/// lock does not block this meta-op, so a locked track can still be unlocked.
/// Clip, effect, and caption edits on a locked track keep refusing
/// FIELD_LOCKED. Video mute/solo still fail local admission
/// (FEATURE_NOT_IMPLEMENTED). Audio muted/solo stay SetAudioTrackState.
final class SetTrackState extends EditOperation {
  const SetTrackState(this.trackId, {required this.locked});
  final String trackId;
  final bool locked;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'setTrackState',
    'trackId': trackId,
    'locked': locked,
  };
}

ProjectDocument _setTrackState(
  ProjectDocument before,
  SetTrackState operation,
  VersionAllocator version,
) {
  final d = before.toJson(), s = d['sequences'][0];
  final matches = (s['tracks'] as List)
      .where((t) => t['id'] == operation.trackId)
      .toList();
  if (matches.length != 1) {
    throw const StudioException('TRACK_NOT_FOUND');
  }
  final t = matches.single;
  if (t['locked'] == operation.locked) {
    return before;
  }
  t['locked'] = operation.locked;
  s['version'] = version(s['id'] as String);
  final after = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(after);
  return after;
}
