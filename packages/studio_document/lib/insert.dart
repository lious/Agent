part of 'edit_algebra.dart';

List<String>? _optionalRippleTrackList(Iterable<String>? rippleTrackIds) {
  if (rippleTrackIds == null) {
    return null;
  }
  final ids = List<String>.unmodifiable(
    rippleTrackIds.take(100001).toList()..sort(),
  );
  if (ids.length > 100000) {
    throw const StudioException('SELECTION_LIMIT');
  }
  if (ids.toSet().length != ids.length) {
    throw const StudioException('DUPLICATE_SELECTION');
  }
  for (final id in ids) {
    requireId(id);
  }
  return ids;
}

List<String>? _validatedRippleTrackIds(
  String mode,
  Iterable<String>? rippleTrackIds,
) {
  if (rippleTrackIds != null && mode != 'insert') {
    throw const StudioException('RIPPLE_TRACKS_REQUIRE_INSERT');
  }
  return _optionalRippleTrackList(rippleTrackIds);
}

void _requireGrid(Map track, Q t, FrameRate fps) {
  if (track['kind'] == 'video' && fps.quantize(t, Rounding.tiesToEven) != t) {
    throw const StudioException('NOT_ON_FRAME');
  }
  if (track['kind'] == 'audio' &&
      Q(sampleIndex(t, 48000, Rounding.tiesToEven), BigInt.from(48000)) != t) {
    throw const StudioException('NOT_ON_SAMPLE');
  }
}

bool _captionsWouldShift(Map d, Q at) {
  for (final c in d['captions'] as List) {
    final start = Q.fromJson(c['timelineRange']['start']);
    final end = start + Q.fromJson(c['timelineRange']['duration']);
    if (end > at) {
      return true;
    }
  }
  return false;
}

Set<String> _defaultSyncMediaTrackIds(List tracks) {
  return {
    for (final t in tracks)
      if (t['syncLock'] == true &&
          (t['kind'] == 'video' || t['kind'] == 'audio'))
        t['id'] as String,
  };
}

Set<String> _resolveRippleTrackIds({
  required List tracks,
  required Set<String> targets,
  required List<String>? explicit,
}) {
  final byId = {for (final t in tracks) t['id'] as String: t};
  if (explicit != null) {
    for (final id in explicit) {
      final t = byId[id];
      if (t == null) {
        throw const StudioException('TRACK_NOT_FOUND');
      }
      if (t['kind'] == 'caption') {
        throw const StudioException('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED');
      }
    }
  }
  final ripple = <String>{...targets, ...?explicit};
  if (explicit == null) {
    ripple.addAll(_defaultSyncMediaTrackIds(tracks));
  }
  for (final id in ripple) {
    final t = byId[id];
    if (t == null) {
      throw const StudioException('TRACK_NOT_FOUND');
    }
    if (t['kind'] == 'caption') {
      throw const StudioException('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED');
    }
  }
  if (ripple.isEmpty) {
    throw const StudioException('TRACK_NOT_FOUND');
  }
  return ripple;
}

void _requireRippleWritable({
  required Map d,
  required Set<String> ripple,
  required Set<String> targets,
  required Q at,
  required Set<String> protected,
}) {
  final s = d['sequences'][0];
  for (final t in s['tracks'] as List) {
    if (!ripple.contains(t['id'])) {
      continue;
    }
    final affected = <Map>[];
    for (final c in t['items'] as List) {
      if (c['source'] == null) {
        continue;
      }
      if (protected.contains(c['id'])) {
        continue;
      }
      final raw = c as Map;
      final start = _start(raw);
      final end = _end(raw);
      if (start >= at || (start < at && end > at)) {
        affected.add(raw);
      }
    }
    if (affected.isEmpty) {
      continue;
    }
    if (t['locked'] == true &&
        t['syncLock'] == true &&
        !targets.contains(t['id'])) {
      throw const StudioException('SYNC_LOCKED');
    }
    for (final c in affected) {
      final start = _start(c);
      final end = _end(c);
      _requireUnlocked(t as Map, c, 'timelineRange.start');
      if (start < at && end > at) {
        _requireUnlocked(t, c, 'sourceRange');
      }
    }
  }
}

({Q start, Q duration}) _packageSpan(Iterable<Map> clips) {
  Q? begin;
  Q? finish;
  for (final c in clips) {
    final s = _start(c);
    final e = _end(c);
    begin = begin == null || s < begin ? s : begin;
    finish = finish == null || e > finish ? e : finish;
  }
  if (begin == null || finish == null || finish <= begin) {
    throw const StudioException('OVERWRITE_INTERVAL_INVALID');
  }
  return (start: begin, duration: finish - begin);
}

/// Split items that strictly span [at] on [ripple]. Protected IDs are skipped.
/// Returns originalId → rightFragmentId for split clips.
Map<String, String> _splitRippleAt(
  Map d,
  Set<String> ripple,
  Q at,
  Set<String> protected,
  VersionAllocator version,
  IdAllocator newId,
) {
  final s = d['sequences'][0];
  final originalEffects = {
    for (final e in d['effects']) e['id']: jsonDecode(jsonEncode(e)),
  };
  final splitMap = <String, String>{};
  for (final track in s['tracks'] as List) {
    if (!ripple.contains(track['id'])) {
      continue;
    }
    final next = <dynamic>[];
    for (final raw in track['items'] as List) {
      if (raw['source'] == null) {
        continue;
      }
      final id = raw['id'] as String;
      if (protected.contains(id)) {
        next.add(raw);
        continue;
      }
      final start = _start(raw as Map);
      final end = _end(raw);
      if (!(start < at && end > at)) {
        next.add(raw);
        continue;
      }
      final rightId = newId();
      final left = _keepClipInterval(raw, start, at, id: id);
      final right = _keepClipInterval(raw, at, end, id: rightId);
      right['linkGroupId'] = null;
      right['selectionGroupId'] = null;
      _bindFragmentEffects(
        d,
        originalEffects,
        raw,
        left,
        Q.of(0),
        at - start,
        newId,
        reuseIds: true,
      );
      _bindFragmentEffects(
        d,
        originalEffects,
        raw,
        right,
        at - start,
        end - at,
        newId,
        reuseIds: false,
      );
      left['version'] = version(id);
      right['version'] = version(rightId);
      next.add(left);
      next.add(right);
      splitMap[id] = rightId;
    }
    track['items'] = next;
  }
  return splitMap;
}

void _shiftRippleFrom(
  Map d,
  Set<String> ripple,
  Q at,
  Q delta,
  Set<String> protected,
  VersionAllocator version,
) {
  if (delta == Q.of(0)) {
    return;
  }
  for (final track in d['sequences'][0]['tracks'] as List) {
    if (!ripple.contains(track['id'])) {
      continue;
    }
    for (final c in track['items'] as List) {
      if (c['source'] == null) {
        continue;
      }
      if (protected.contains(c['id'])) {
        continue;
      }
      if (_start(c as Map) >= at) {
        c['timelineRange']['start'] = (_start(c) + delta).toJson();
        c['version'] = version(c['id'] as String);
      }
    }
  }
}

void _rebuildSplitLinkGroups(
  Map d,
  Map<String, String> splitMap,
  IdAllocator newId,
) {
  if (splitMap.isEmpty) {
    return;
  }
  final clips = {
    for (final t in d['sequences'][0]['tracks'])
      for (final c in t['items'])
        if (c['source'] != null) c['id'] as String: c as Map,
  };
  final added = <Map<String, dynamic>>[];
  for (final g in d['linkGroups'] as List) {
    final members = g['members'] as List;
    if (members.length != 2) {
      continue;
    }
    final leftIds = [for (final m in members) m['clipId'] as String];
    if (!leftIds.every(splitMap.containsKey)) {
      continue;
    }
    final nid = newId();
    final anchor = g['anchorClipId'] as String;
    final rightMembers = [
      for (final m in members)
        {'clipId': splitMap[m['clipId'] as String]!, 'offset': m['offset']},
    ];
    // Recompute offset from actual right starts relative to the remapped anchor.
    final rightAnchor =
        splitMap[anchor] ?? rightMembers.first['clipId'] as String;
    final anchorStart = _start(clips[rightAnchor] as Map);
    for (final m in rightMembers) {
      final c = clips[m['clipId']];
      if (c != null) {
        m['offset'] = (_start(c) - anchorStart).toJson();
        c['linkGroupId'] = nid;
      }
    }
    added.add({
      'id': nid,
      'anchorClipId': rightAnchor,
      'members': rightMembers,
      'syncPolicy': g['syncPolicy'],
    });
  }
  (d['linkGroups'] as List).addAll(added);
}

void _repairInsertTransitions(
  Map d,
  Q at,
  Q shift,
  Map<String, String> splitMap,
  Set<String> moved,
  Q movedDelta,
  VersionAllocator version,
) {
  final clips = {
    for (final t in d['sequences'][0]['tracks'])
      for (final c in t['items'])
        if (c['source'] != null) c['id'] as String: c as Map,
  };
  final kept = <dynamic>[];
  for (final t in d['transitions'] as List) {
    var left = t['leftClipId'] as String;
    var right = t['rightClipId'] as String;
    var cut = Q.fromJson(t['cut']);
    final traveling = moved.contains(left) && moved.contains(right);
    if ((moved.contains(left) || moved.contains(right)) && !traveling) {
      continue;
    }
    if (!traveling) {
      if (splitMap.containsKey(left) && cut >= at) {
        left = splitMap[left]!;
        t['leftClipId'] = left;
      }
      if (splitMap.containsKey(right) && cut >= at) {
        right = splitMap[right]!;
        t['rightClipId'] = right;
      }
      if (cut == at) {
        continue;
      }
      if (cut >= at) {
        cut = cut + shift;
        t['cut'] = cut.toJson();
        t['version'] = version(t['id'] as String);
      }
    } else {
      cut = cut + movedDelta;
      t['cut'] = cut.toJson();
      t['version'] = version(t['id'] as String);
    }
    final a = clips[left], b = clips[right];
    if (a == null || b == null) {
      continue;
    }
    if (_end(a) != _start(b) || _end(a) != cut) {
      continue;
    }
    kept.add(t);
  }
  d['transitions'] = kept;
}

class _InsertOpening {
  const _InsertOpening({
    required this.rippleTrackIds,
    required this.minimumDuration,
    required this.splitMap,
  });
  final Set<String> rippleTrackIds;
  final Q minimumDuration;
  final Map<String, String> splitMap;
}

_InsertOpening _openInsertHole(
  Map d, {
  required Q at,
  required Q length,
  required Set<String> targets,
  required List<String>? explicitRipple,
  required Set<String> protected,
  required VersionAllocator version,
  required IdAllocator newId,
}) {
  if (at < Q.of(0)) {
    throw const StudioException('NEGATIVE_TIMELINE_START');
  }
  if (length <= Q.of(0)) {
    throw const StudioException('OVERWRITE_INTERVAL_INVALID');
  }
  if (_captionsWouldShift(d, at)) {
    throw const StudioException('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED');
  }
  final s = d['sequences'][0];
  final tracks = s['tracks'] as List;
  final fps = FrameRate(s['frameRate']['n'], s['frameRate']['d']);
  final ripple = _resolveRippleTrackIds(
    tracks: tracks,
    targets: targets,
    explicit: explicitRipple,
  );
  final byId = {for (final t in tracks) t['id'] as String: t};
  for (final id in ripple) {
    _requireGrid(byId[id] as Map, at, fps);
    _requireGrid(byId[id] as Map, length, fps);
  }
  _requireRippleWritable(
    d: d,
    ripple: ripple,
    targets: targets,
    at: at,
    protected: protected,
  );
  final splitMap = _splitRippleAt(d, ripple, at, protected, version, newId);
  _shiftRippleFrom(d, ripple, at, length, protected, version);
  _rebuildSplitLinkGroups(d, splitMap, newId);
  final old = Q.fromJson(s['duration']);
  return _InsertOpening(
    rippleTrackIds: ripple,
    minimumDuration: old + length,
    splitMap: splitMap,
  );
}

_InsertOpening _pasteInsertOpen(
  Map d,
  List<Map<String, dynamic>> incoming,
  List<String>? explicitRipple,
  VersionAllocator version,
  IdAllocator newId,
) {
  final span = _packageSpan(incoming);
  final targets = {for (final c in incoming) c['trackId'] as String};
  final opened = _openInsertHole(
    d,
    at: span.start,
    length: span.duration,
    targets: targets,
    explicitRipple: explicitRipple,
    protected: const {},
    version: version,
    newId: newId,
  );
  _repairInsertTransitions(
    d,
    span.start,
    span.duration,
    opened.splitMap,
    const {},
    Q.of(0),
    version,
  );
  return opened;
}

ProjectDocument _insertMoveClips(
  ProjectDocument before,
  MoveClips operation,
  VersionAllocator version,
  IdAllocator newId,
) {
  final moved = expandedMoveClipIds(before, operation).toSet();
  final d = before.toJson(), s = d['sequences'][0];
  final tracks = s['tracks'] as List;
  final clips = {
    for (final t in tracks)
      for (final c in t['items'])
        if (c['source'] != null) c['id']: c,
  };
  final trackById = {for (final t in tracks) t['id'] as String: t};
  final fps = FrameRate(s['frameRate']['n'], s['frameRate']['d']);
  final targets = <String>{};
  for (final id in moved) {
    final c = clips[id] as Map, t = trackById[c['trackId']];
    _requireUnlocked(t as Map, c, 'timelineRange.start');
    final next = _start(c) + operation.delta;
    if (next < Q.of(0)) {
      throw const StudioException('NEGATIVE_TIMELINE_START');
    }
    _requireGrid(t, next, fps);
    targets.add(c['trackId'] as String);
  }
  for (final t in d['transitions']) {
    final left = moved.contains(t['leftClipId']),
        right = moved.contains(t['rightClipId']);
    if (left != right) {
      throw const StudioException('TRANSITION_MOVE_REQUIRES_BOTH');
    }
    if (left) {
      _requireUnlocked(
        trackById[clips[t['leftClipId']]['trackId']] as Map,
        clips[t['leftClipId']] as Map,
        'transitions',
      );
      _requireUnlocked(
        trackById[clips[t['rightClipId']]['trackId']] as Map,
        clips[t['rightClipId']] as Map,
        'transitions',
      );
    }
  }
  if (operation.delta == Q.of(0)) {
    return before;
  }
  final movedClips = [for (final id in moved) clips[id] as Map];
  final span = _packageSpan(movedClips);
  final at = span.start + operation.delta;
  for (final t in tracks) {
    (t['items'] as List).removeWhere(
      (c) => c['source'] != null && moved.contains(c['id']),
    );
  }
  final opened = _openInsertHole(
    d,
    at: at,
    length: span.duration,
    targets: targets,
    explicitRipple: operation.rippleTrackIds,
    protected: moved,
    version: version,
    newId: newId,
  );
  for (final id in moved) {
    final c = clips[id] as Map;
    c['timelineRange']['start'] = (_start(c) + operation.delta).toJson();
    c['version'] = version(id);
    (trackById[c['trackId']]['items'] as List).add(c);
  }
  _repairInsertTransitions(
    d,
    at,
    span.duration,
    opened.splitMap,
    moved,
    operation.delta,
    version,
  );
  _rewriteMediaTracks(
    s,
    tracks,
    {...opened.rippleTrackIds, ...targets},
    version,
    newId,
    opened.minimumDuration,
  );
  followClipLocalCaptions(d, nextVersion: version);
  _markMovedLinksOutOfSync(d, moved);
  final result = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(result);
  return result;
}
