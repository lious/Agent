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

/// Add an empty video track to the root sequence. Extra audio or caption
/// tracks, and video muted/solo, stay unopened. [track.items] must be empty.
final class AddTrack extends EditOperation {
  AddTrack(Map<String, dynamic> track)
    : track = Map<String, dynamic>.unmodifiable(
        jsonDecode(jsonEncode(track)) as Map<String, dynamic>,
      );

  final Map<String, dynamic> track;

  @override
  Map<String, Object?> toJson() => {'kind': 'addTrack', 'track': track};
}

/// Remove a non-primary video track. [contentPolicy] is the s5/s5a policy:
/// `rejectIfNotEmpty` or `removeContents`.
final class RemoveTrack extends EditOperation {
  const RemoveTrack(this.trackId, {this.contentPolicy = 'rejectIfNotEmpty'});

  final String trackId;
  final String contentPolicy;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'removeTrack',
    'trackId': trackId,
    'contentPolicy': contentPolicy,
  };
}

ProjectDocument _addTrack(
  ProjectDocument before,
  AddTrack operation,
  VersionAllocator version,
) {
  final t = Map<String, dynamic>.from(operation.track);
  final id = t['id'];
  if (id is! String) {
    throw const StudioException('INVALID_TRACK_STATE');
  }
  requireId(id);
  if (t['kind'] != 'video') {
    throw const StudioException('FEATURE_NOT_IMPLEMENTED');
  }
  if (t['muted'] != false || t['solo'] != false || t['busId'] != null) {
    throw const StudioException('FEATURE_NOT_IMPLEMENTED');
  }
  final items = t['items'];
  if (items is! List || items.isNotEmpty) {
    throw const StudioException('INVALID_TRACK_STATE');
  }
  final d = before.toJson();
  final s = d['sequences'][0] as Map;
  if (t['sequenceId'] != s['id']) {
    throw const StudioException('PARENT_MISMATCH');
  }
  final tracks = s['tracks'] as List;
  if (tracks.any((existing) => existing['id'] == id)) {
    throw const StudioException('DUPLICATE_ID');
  }
  if (tracks.any((existing) => existing['order'] == t['order'])) {
    throw const StudioException('DUPLICATE_ORDER');
  }
  tracks.add(t);
  s['version'] = version(s['id'] as String);
  final after = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(after);
  return after;
}

ProjectDocument _removeTrack(
  ProjectDocument before,
  RemoveTrack operation,
  VersionAllocator version,
) {
  requireId(operation.trackId);
  if (operation.contentPolicy != 'rejectIfNotEmpty' &&
      operation.contentPolicy != 'removeContents') {
    throw const StudioException('UNSUPPORTED_EDIT_MODE');
  }
  final d = before.toJson();
  final s = d['sequences'][0] as Map;
  final tracks = s['tracks'] as List;
  final matches = [
    for (final t in tracks)
      if (t['id'] == operation.trackId) t,
  ];
  if (matches.length != 1) {
    throw const StudioException('TRACK_NOT_FOUND');
  }
  final track = matches.single as Map;
  if (track['kind'] != 'video') {
    throw const StudioException('FEATURE_NOT_IMPLEMENTED');
  }
  final videoCount = tracks.where((t) => t['kind'] == 'video').length;
  // Keep the admitted primary video track (list index 0) in place.
  if (videoCount < 2 || track['id'] == tracks[0]['id']) {
    throw const StudioException('FEATURE_NOT_IMPLEMENTED');
  }
  if (track['locked'] == true) {
    throw const StudioException('FIELD_LOCKED');
  }
  final items = List<Map>.from((track['items'] as List).map((e) => e as Map));
  final clipIds = {
    for (final c in items)
      if (c['source'] != null) c['id'] as String,
  };
  if (operation.contentPolicy == 'rejectIfNotEmpty' && items.isNotEmpty) {
    throw const StudioException('INVALID_TRACK_STATE');
  }
  if (operation.contentPolicy == 'removeContents' && clipIds.isNotEmpty) {
    for (final group in d['linkGroups'] as List) {
      final members = [for (final m in group['members']) m['clipId'] as String];
      final onTrack = [
        for (final id in members)
          if (clipIds.contains(id)) id,
      ];
      if (onTrack.isNotEmpty && onTrack.length != members.length) {
        throw const StudioException('LINK_MEMBERSHIP_MISMATCH');
      }
    }
    d['linkGroups'] = [
      for (final group in d['linkGroups'] as List)
        if (![for (final m in group['members']) m['clipId'] as String]
            .any(clipIds.contains))
          group,
    ];
    d['selectionGroups'] = [
      for (final group in d['selectionGroups'] as List)
        if (![for (final m in group['members'] as List) m as String]
            .any(clipIds.contains))
          group,
    ];
    d['transitions'] = [
      for (final tr in d['transitions'] as List)
        if (tr['trackId'] != track['id'] &&
            !clipIds.contains(tr['leftClipId']) &&
            !clipIds.contains(tr['rightClipId']))
          tr,
    ];
    d['captions'] = [
      for (final c in d['captions'] as List)
        if (c['trackId'] != track['id'] &&
            !clipIds.contains(c['anchor']?['clipId']))
          c,
    ];
    final keptMarkers = <Map>[];
    final droppedMarkerIds = <String>{};
    for (final m in d['markers'] as List) {
      final anchor = m['anchor'] as Map?;
      if (anchor != null && clipIds.contains(anchor['clipId'])) {
        droppedMarkerIds.add(m['id'] as String);
      } else {
        keptMarkers.add(m as Map);
      }
    }
    d['markers'] = keptMarkers;
    s['markerIds'] = [
      for (final id in s['markerIds'] as List)
        if (!droppedMarkerIds.contains(id)) id,
    ];
  }
  tracks.removeWhere((t) => t['id'] == operation.trackId);
  var cover = Q.of(0);
  for (final remaining in tracks) {
    for (final item in remaining['items'] as List) {
      final start = Q.fromJson(item['timelineRange']['start']);
      final duration = Q.fromJson(item['timelineRange']['duration']);
      final end = start + duration;
      if (end > cover) cover = end;
    }
  }
  for (final c in d['captions'] as List) {
    final range = c['range'] ?? c['anchor']?['range'];
    if (range is Map) {
      final start = Q.fromJson(range['start']);
      final duration = Q.fromJson(range['duration']);
      final end = start + duration;
      if (end > cover) cover = end;
    }
  }
  s['duration'] = cover.toJson();
  s['version'] = version(s['id'] as String);
  final after = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(after);
  return after;
}
