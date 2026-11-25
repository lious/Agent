part of 'edit_algebra.dart';

/// First-version ripple trim: shorten one clip (plus link closure) on an
/// in or out edge, then close the vacated tail on participating tracks.
/// Lengthening, ripple-close of a move source, roll/slip/slide and a
/// redefinition of [TrimClip] `ripple:true` are not opened in this slice.
final class RippleTrimClip extends EditOperation {
  RippleTrimClip(
    this.clipId,
    this.edge,
    this.delta, {
    Iterable<String>? rippleTrackIds,
  }) : rippleTrackIds = _optionalRippleTrackList(rippleTrackIds) {
    requireId(clipId);
  }
  final String clipId, edge;
  final Q delta;
  final List<String>? rippleTrackIds;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'rippleTrimClip',
    'clipId': clipId,
    'edge': edge,
    'delta': delta.toJson(),
    'includeLinks': true,
    if (rippleTrackIds != null) 'rippleTrackIds': rippleTrackIds,
  };
}

void _cropOwnedOpacity(
  Map d,
  Map originalEffects,
  Map original,
  Map clipped,
  Q localOffset,
  Q newDuration,
  IdAllocator newId,
  VersionAllocator version,
) {
  _bindFragmentEffects(
    d,
    originalEffects,
    original,
    clipped,
    localOffset,
    newDuration,
    newId,
    reuseIds: true,
  );
  for (final eid in clipped['effectIds'] as List) {
    for (final e in d['effects'] as List) {
      if (e['id'] == eid) {
        e['version'] = version(eid as String);
      }
    }
  }
}

ProjectDocument _rippleTrimClip(
  ProjectDocument before,
  RippleTrimClip operation,
  VersionAllocator version,
  IdAllocator newId,
) {
  if (operation.edge != 'in' && operation.edge != 'out') {
    throw const StudioException('INVALID_EDGE');
  }
  if ((operation.edge == 'out' && operation.delta > Q.of(0)) ||
      (operation.edge == 'in' && operation.delta < Q.of(0))) {
    throw const StudioException('RIPPLE_TRIM_LENGTHEN_NOT_IMPLEMENTED');
  }
  final memberIds = expandedEditClipIds(before, [operation.clipId]).toSet();
  if (operation.delta == Q.of(0)) {
    return before;
  }
  final shorten = operation.edge == 'out'
      ? Q.of(0) - operation.delta
      : operation.delta;
  if (shorten <= Q.of(0)) {
    throw const StudioException('RIPPLE_TRIM_LENGTHEN_NOT_IMPLEMENTED');
  }
  final d = before.toJson(), s = d['sequences'][0];
  final tracks = s['tracks'] as List;
  final clips = {
    for (final t in tracks)
      for (final c in t['items'])
        if (c['source'] != null) c['id']: c,
  };
  final selected = clips[operation.clipId] as Map;
  final oldEnd = _end(selected);
  final oldDuration = oldEnd - _start(selected);
  if (oldDuration <= shorten) {
    throw const StudioException('CLIP_TOO_SHORT');
  }
  final at = oldEnd - shorten;
  final end = oldEnd;
  if (_captionsWouldShift(d, at)) {
    throw const StudioException('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED');
  }
  final fps = FrameRate(s['frameRate']['n'], s['frameRate']['d']);
  final targets = {for (final id in memberIds) clips[id]['trackId'] as String};
  final ripple = _resolveRippleTrackIds(
    tracks: tracks,
    targets: targets,
    explicit: operation.rippleTrackIds,
  );
  final byId = {for (final t in tracks) t['id'] as String: t};
  for (final id in ripple) {
    _requireGrid(byId[id] as Map, at, fps);
    _requireGrid(byId[id] as Map, shorten, fps);
    _requireGrid(byId[id] as Map, end, fps);
  }
  for (final id in memberIds) {
    final c = clips[id] as Map;
    final dur = _end(c) - _start(c);
    if (dur <= shorten) {
      throw const StudioException('CLIP_TOO_SHORT');
    }
    _requireUnlocked(
      byId[c['trackId'] as String] as Map,
      c,
      'timelineRange.start',
    );
    _requireUnlocked(byId[c['trackId'] as String] as Map, c, 'sourceRange');
  }
  _requireRippleCloseWritable(
    d: d,
    ripple: ripple,
    targets: targets,
    start: at,
    end: end,
  );
  final originalEffects = {
    for (final e in d['effects']) e['id']: jsonDecode(jsonEncode(e)),
  };
  final originals = {
    for (final id in memberIds) id: jsonDecode(jsonEncode(clips[id])),
  };
  for (final id in memberIds) {
    final raw = clips[id] as Map;
    final start = _start(raw);
    final finish = _end(raw);
    final keepStart = operation.edge == 'in' ? start + shorten : start;
    final keepEnd = operation.edge == 'in' ? finish : finish - shorten;
    final trimmed = _keepClipInterval(raw, keepStart, keepEnd, id: id);
    if (operation.edge == 'in') {
      trimmed['timelineRange']['start'] = start.toJson();
    }
    trimmed['version'] = version(id);
    _cropOwnedOpacity(
      d,
      originalEffects,
      originals[id] as Map,
      trimmed,
      operation.edge == 'in' ? shorten : Q.of(0),
      keepEnd - keepStart,
      newId,
      version,
    );
    final track = byId[raw['trackId'] as String] as Map;
    final items = track['items'] as List;
    final index = items.indexWhere((c) => c['id'] == id);
    items[index] = trimmed;
    clips[id] = trimmed;
  }
  // Split the later bound first so existing coordinates stay stable.
  final splitEnd = _splitRippleAt(d, ripple, end, memberIds, version, newId);
  _rebuildSplitLinkGroups(d, splitEnd, newId);
  final splitStart = _splitRippleAt(d, ripple, at, memberIds, version, newId);
  _rebuildSplitLinkGroups(d, splitStart, newId);
  final removed = <String>{};
  for (final track in tracks) {
    if (!ripple.contains(track['id'])) {
      continue;
    }
    final next = <dynamic>[];
    for (final raw in track['items'] as List) {
      if (raw['source'] == null) {
        continue;
      }
      if (memberIds.contains(raw['id'])) {
        next.add(raw);
        continue;
      }
      final start = _start(raw as Map);
      final finish = _end(raw);
      if (start >= at && finish <= end) {
        removed.add(raw['id'] as String);
        continue;
      }
      next.add(raw);
    }
    track['items'] = next;
  }
  if (removed.isNotEmpty) {
    (d['effects'] as List).removeWhere(
      (e) => e['owner'] is Map && removed.contains(e['owner']['id']),
    );
    _repairGroupsAfterOverwrite(d, removed);
  }
  _shiftRippleFrom(d, ripple, end, Q.of(0) - shorten, memberIds, version);
  _repairRippleDeleteTransitions(d, at, shorten, splitStart, splitEnd, version);
  final old = Q.fromJson(s['duration']);
  var minimum = old - shorten;
  for (final t in tracks) {
    if (ripple.contains(t['id'])) {
      continue;
    }
    for (final c in t['items'] as List) {
      if (c['source'] != null && _end(c as Map) > minimum) {
        minimum = _end(c);
      }
    }
  }
  if (minimum < Q.of(0)) {
    minimum = Q.of(0);
  }
  _rewriteMediaTracks(s, tracks, ripple, version, newId, minimum);
  final result = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(result);
  return result;
}
