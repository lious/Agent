part of 'edit_algebra.dart';

/// Ripple trim: change one clip (plus link closure) on an in or out edge,
/// then close a vacated tail or open space after the old end on participating
/// tracks. [TrimClip] `ripple:true` is not redefined. Auto-close of a move
/// source, roll/slip/slide and new-track creation are not opened in this slice.
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
  final memberIds = expandedEditClipIds(before, [operation.clipId]).toSet();
  if (operation.delta == Q.of(0)) {
    return before;
  }
  // Duration change Δ: out moves the tail; in pins timeline start, so a
  // positive in delta shortens the head and a negative in delta lengthens.
  final durationDelta = operation.edge == 'out'
      ? operation.delta
      : Q.of(0) - operation.delta;
  final d = before.toJson(), s = d['sequences'][0];
  final markerLocals = snapshotClipLocalMarkerLocals(d);
  final sourceAbs = snapshotSourceCaptionAbsolutes(d);
  final tracks = s['tracks'] as List;
  final clips = {
    for (final t in tracks)
      for (final c in t['items'])
        if (c['source'] != null) c['id']: c,
  };
  final selected = clips[operation.clipId] as Map;
  final oldEnd = _end(selected);
  final closeStart = durationDelta < Q.of(0) ? oldEnd + durationDelta : oldEnd;
  final closeEnd = durationDelta < Q.of(0) ? oldEnd : oldEnd + durationDelta;
  final span = closeEnd - closeStart;
  final fps = FrameRate(s['frameRate']['n'], s['frameRate']['d']);
  final targets = {for (final id in memberIds) clips[id]['trackId'] as String};
  final ripple = _resolveRippleTrackIds(
    tracks: tracks,
    targets: targets,
    explicit: operation.rippleTrackIds,
  );
  final byId = {for (final t in tracks) t['id'] as String: t};
  for (final id in ripple) {
    _requireGrid(byId[id] as Map, closeStart, fps);
    _requireGrid(byId[id] as Map, span, fps);
    _requireGrid(byId[id] as Map, closeEnd, fps);
  }
  for (final id in memberIds) {
    final c = clips[id] as Map;
    final dur = _end(c) - _start(c);
    final next = dur + durationDelta;
    if (next <= Q.of(0)) {
      throw const StudioException('CLIP_TOO_SHORT');
    }
    _requireRippleTrimSource(d, c, operation.edge, operation.delta);
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
    start: closeStart,
    end: closeEnd,
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
    final oldDuration = finish - start;
    final newDuration = oldDuration + durationDelta;
    final rate = Q.fromJson(raw['timeMap']['rate']);
    final trimmed = jsonDecode(jsonEncode(raw)) as Map;
    trimmed['timelineRange']['duration'] = newDuration.toJson();
    if (operation.edge == 'in') {
      trimmed['sourceRange']['start'] =
          (Q.fromJson(trimmed['sourceRange']['start']) + rate * operation.delta)
              .toJson();
    }
    trimmed['sourceRange']['duration'] = (rate * newDuration).toJson();
    trimmed['version'] = version(id);
    _cropOwnedOpacity(
      d,
      originalEffects,
      originals[id] as Map,
      trimmed,
      operation.edge == 'in' ? operation.delta : Q.of(0),
      newDuration,
      newId,
      version,
    );
    final track = byId[raw['trackId'] as String] as Map;
    final items = track['items'] as List;
    final index = items.indexWhere((c) => c['id'] == id);
    items[index] = trimmed;
    clips[id] = trimmed;
  }
  if (durationDelta < Q.of(0)) {
    // Split the later bound first so existing coordinates stay stable.
    final splitEnd = _splitRippleAt(
      d,
      ripple,
      oldEnd,
      memberIds,
      version,
      newId,
    );
    _rebuildSplitLinkGroups(d, splitEnd, newId);
    final splitStart = _splitRippleAt(
      d,
      ripple,
      closeStart,
      memberIds,
      version,
      newId,
    );
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
        if (start >= closeStart && finish <= oldEnd) {
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
    _shiftRippleFrom(d, ripple, oldEnd, durationDelta, memberIds, version);
    _repairRippleDeleteTransitions(
      d,
      closeStart,
      span,
      splitStart,
      splitEnd,
      version,
    );
  } else {
    final splitAt = _splitRippleAt(
      d,
      ripple,
      oldEnd,
      memberIds,
      version,
      newId,
    );
    _rebuildSplitLinkGroups(d, splitAt, newId);
    _shiftRippleFrom(d, ripple, oldEnd, durationDelta, memberIds, version);
    _repairRippleOpenTransitions(d, oldEnd, durationDelta, splitAt, version);
  }
  final old = Q.fromJson(s['duration']);
  var minimum = old + durationDelta;
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
  applySourceCaptionAbsolutes(d, sourceAbs, nextVersion: version);
  applyCaptionIntervalEdit(
    d,
    at: closeStart,
    length: span,
    opening: durationDelta > Q.of(0),
    newId: newId,
    nextVersion: version,
  );
  applyClipLocalMarkerLocals(d, markerLocals, refuseUncovered: false);
  applyMarkerIntervalEdit(
    d,
    at: closeStart,
    length: span,
    opening: durationDelta > Q.of(0),
    newId: newId,
  );
  final result = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(result);
  return result;
}

void _requireRippleTrimSource(Map d, Map clip, String edge, Q delta) {
  final start = _start(clip);
  final duration = _end(clip) - start;
  final durationDelta = edge == 'out' ? delta : Q.of(0) - delta;
  final newDuration = duration + durationDelta;
  final rate = Q.fromJson(clip['timeMap']['rate']);
  var sourceStart = Q.fromJson(clip['sourceRange']['start']);
  if (edge == 'in') {
    sourceStart = sourceStart + rate * delta;
  }
  final sourceDuration = rate * newDuration;
  if (sourceStart < Q.of(0) || sourceDuration <= Q.of(0)) {
    throw const StudioException('SOURCE_OUT_OF_RANGE');
  }
  final source = clip['source'] as Map;
  final assets = [
    for (final a in d['assets'] as List)
      if (a['id'] == source['id']) a as Map,
  ];
  if (assets.length != 1) {
    throw const StudioException('SOURCE_VERSION_MISSING');
  }
  final streams = (assets.single['streams'] as List)
      .where((x) => x['id'] == source['streamId'])
      .toList();
  if (streams.length != 1) {
    throw const StudioException('SOURCE_STREAM_MISMATCH');
  }
  if (sourceStart + sourceDuration > Q.fromJson(streams.single['duration'])) {
    throw const StudioException('SOURCE_OUT_OF_RANGE');
  }
}

void _repairRippleOpenTransitions(
  Map d,
  Q at,
  Q delta,
  Map<String, String> splitAt,
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
    if (cut >= at) {
      if (splitAt.containsKey(left)) {
        left = splitAt[left]!;
        t['leftClipId'] = left;
      }
      if (splitAt.containsKey(right)) {
        right = splitAt[right]!;
        t['rightClipId'] = right;
      }
      cut = cut + delta;
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
