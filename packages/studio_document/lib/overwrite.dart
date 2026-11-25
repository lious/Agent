part of 'edit_algebra.dart';

String _requireCollisionMode(String mode) {
  if (mode == 'reject' || mode == 'overwrite' || mode == 'insert') {
    return mode;
  }
  throw const StudioException('UNSUPPORTED_EDIT_MODE');
}

List<(Q, Q)> _mergeRanges(Iterable<(Q, Q)> raw) {
  final xs = raw.where((r) => r.$2 > r.$1).toList()
    ..sort((a, b) => a.$1.compareTo(b.$1));
  if (xs.isEmpty) {
    return const [];
  }
  final out = <(Q, Q)>[xs.first];
  for (final r in xs.skip(1)) {
    final last = out.last;
    if (r.$1 <= last.$2) {
      final end = r.$2 > last.$2 ? r.$2 : last.$2;
      out[out.length - 1] = (last.$1, end);
    } else {
      out.add(r);
    }
  }
  return out;
}

List<(Q, Q)> _subtractRanges(Q start, Q end, List<(Q, Q)> holes) {
  var cursor = start;
  final keep = <(Q, Q)>[];
  for (final h in holes) {
    if (h.$2 <= start || h.$1 >= end) {
      continue;
    }
    final a = h.$1 < start ? start : h.$1;
    final b = h.$2 > end ? end : h.$2;
    if (cursor < a) {
      keep.add((cursor, a));
    }
    if (b > cursor) {
      cursor = b;
    }
  }
  if (cursor < end) {
    keep.add((cursor, end));
  }
  return keep;
}

Map<String, dynamic> _keepClipInterval(
  Map raw,
  Q keepStart,
  Q keepEnd, {
  required String id,
}) {
  final c = Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)) as Map);
  final start = _start(c);
  final duration = Q.fromJson(c['timelineRange']['duration']);
  final end = start + duration;
  if (keepStart < start || keepEnd > end || keepEnd <= keepStart) {
    throw const StudioException('OVERWRITE_INTERVAL_INVALID');
  }
  final inDelta = keepStart - start;
  final kept = keepEnd - keepStart;
  final rate = Q.fromJson(c['timeMap']['rate']);
  c['id'] = id;
  c['version'] = '1';
  c['timelineRange'] = {'start': keepStart.toJson(), 'duration': kept.toJson()};
  c['sourceRange'] = {
    'start': (Q.fromJson(c['sourceRange']['start']) + rate * inDelta).toJson(),
    'duration': (rate * kept).toJson(),
  };
  c['selectionGroupId'] = id == raw['id'] ? raw['selectionGroupId'] : null;
  return c;
}

void _bindFragmentEffects(
  Map d,
  Map originalEffectsById,
  Map original,
  Map fragment,
  Q localOffset,
  Q newDuration,
  IdAllocator newId, {
  required bool reuseIds,
}) {
  final effects = d['effects'] as List;
  final bound = <String>[];
  for (final eid in original['effectIds'] as List) {
    final raw = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(originalEffectsById[eid])) as Map,
    );
    final nid = reuseIds ? eid as String : newId();
    raw['id'] = nid;
    raw['version'] = reuseIds ? raw['version'] : '1';
    raw['owner'] = {'kind': 'clip', 'id': fragment['id']};
    if ((raw['keyframes'] as List).isNotEmpty) {
      if (raw['type'] != 'opacity') {
        throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
      }
      raw['keyframes'] = cropOpacityPoints(
        raw,
        localOffset,
        newDuration,
        newId,
      );
    }
    if (reuseIds) {
      final index = effects.indexWhere((e) => e['id'] == eid);
      if (index >= 0) {
        effects[index] = raw;
      } else {
        effects.add(raw);
      }
    } else {
      effects.add(raw);
    }
    bound.add(nid);
  }
  fragment['effectIds'] = bound;
}

/// Cut existing media on [rangesByTrack] without moving later content.
/// [protected] IDs (moved or incoming clips) are left in place.
/// Returns clip IDs that were removed or shortened/split.
Set<String> _carveOverwriteRanges(
  Map d,
  Map<String, List<(Q, Q)>> rangesByTrack,
  Set<String> protected,
  VersionAllocator version,
  IdAllocator newId,
) {
  final s = d['sequences'][0];
  final tracks = {for (final t in s['tracks']) t['id']: t};
  final originalEffects = {
    for (final e in d['effects']) e['id']: jsonDecode(jsonEncode(e)),
  };
  final touched = <String>{};
  final removed = <String>{};
  for (final entry in rangesByTrack.entries) {
    final track = tracks[entry.key];
    if (track == null) {
      throw const StudioException('TRACK_NOT_FOUND');
    }
    final holes = _mergeRanges(entry.value);
    if (holes.isEmpty) {
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
      final keep = _subtractRanges(start, end, holes);
      if (keep.length == 1 && keep.first.$1 == start && keep.first.$2 == end) {
        next.add(raw);
        continue;
      }
      _requireUnlocked(track as Map, raw, 'timelineRange.start');
      _requireUnlocked(track, raw, 'sourceRange');
      if ((raw['lockedFields'] as List).any(
        (v) =>
            v == '*' ||
            v == 'effects' ||
            v == 'effectIds' ||
            (v as String).startsWith('effects.') ||
            v.startsWith('effectIds.'),
      )) {
        if (keep.isEmpty ||
            keep.length != 1 ||
            keep.first.$1 != start ||
            keep.first.$2 != end) {
          throw const StudioException('FIELD_LOCKED');
        }
      }
      touched.add(id);
      if (keep.isEmpty) {
        removed.add(id);
        continue;
      }
      for (var i = 0; i < keep.length; i++) {
        final a = keep[i].$1, b = keep[i].$2;
        final reuse = i == 0;
        final fragment = _keepClipInterval(raw, a, b, id: reuse ? id : newId());
        if (!reuse) {
          fragment['linkGroupId'] = null;
        }
        _bindFragmentEffects(
          d,
          originalEffects,
          raw,
          fragment,
          a - start,
          b - a,
          newId,
          reuseIds: reuse,
        );
        fragment['version'] = version(fragment['id'] as String);
        next.add(fragment);
      }
    }
    track['items'] = next;
  }
  if (removed.isNotEmpty) {
    (d['effects'] as List).removeWhere(
      (e) => e['owner'] is Map && removed.contains(e['owner']['id']),
    );
    for (final t in s['tracks']) {
      for (final c in t['items']) {
        if (c['source'] != null && removed.contains(c['id'])) {
          // already dropped from carved tracks; other tracks shouldn't hold them
        }
        if (c['source'] != null && removed.contains(c['linkGroupId'])) {
          c['linkGroupId'] = null;
        }
      }
    }
  }
  _repairGroupsAfterOverwrite(d, removed);
  return touched;
}

void _repairGroupsAfterOverwrite(Map d, Set<String> removed) {
  final clips = {
    for (final t in d['sequences'][0]['tracks'])
      for (final c in t['items'])
        if (c['source'] != null) c['id']: c,
  };
  (d['linkGroups'] as List).removeWhere((g) {
    final members = [
      for (final m in g['members'] as List)
        if (!removed.contains(m['clipId']) && clips.containsKey(m['clipId'])) m,
    ];
    if (members.length == 2 &&
        members.length == (g['members'] as List).length) {
      return false;
    }
    for (final m in members) {
      final c = clips[m['clipId']];
      if (c != null) {
        c['linkGroupId'] = null;
      }
    }
    return true;
  });
  for (final g in d['selectionGroups'] as List) {
    (g['memberClipIds'] as List).removeWhere(removed.contains);
  }
  (d['selectionGroups'] as List).removeWhere(
    (g) => (g['memberClipIds'] as List).isEmpty,
  );
  final groups = {for (final g in d['selectionGroups']) g['id']: g};
  for (final c in clips.values) {
    final gid = c['selectionGroupId'];
    if (gid != null && !groups.containsKey(gid)) {
      c['selectionGroupId'] = null;
    }
  }
}

void _deleteAffectedTransitions(
  Map d,
  Set<String> touched,
  Set<String> moved,
  Map<String, List<(Q, Q)>> rangesByTrack,
) {
  bool overlaps(Map t) {
    final cut = Q.fromJson(t['cut']);
    final begin = cut - Q.fromJson(t['before']);
    final end = cut + Q.fromJson(t['after']);
    final holes = rangesByTrack[t['trackId']];
    if (holes == null) {
      return false;
    }
    for (final h in holes) {
      if (begin < h.$2 && end > h.$1) {
        return true;
      }
    }
    return false;
  }

  (d['transitions'] as List).removeWhere((t) {
    final left = t['leftClipId'] as String, right = t['rightClipId'] as String;
    // A pair that travels together keeps its dissolve; dest intervals may
    // overlap the old handle window. The cut is shifted after the carve.
    if (moved.contains(left) && moved.contains(right)) {
      return false;
    }
    return touched.contains(left) ||
        touched.contains(right) ||
        moved.contains(left) ||
        moved.contains(right) ||
        overlaps(t);
  });
}

ProjectDocument _overwriteMoveClips(
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
  final trackById = {for (final t in tracks) t['id']: t};
  final fps = FrameRate(s['frameRate']['n'], s['frameRate']['d']);
  final rangesByTrack = <String, List<(Q, Q)>>{};
  final affected = <String>{};
  for (final id in moved) {
    final c = clips[id] as Map, t = trackById[c['trackId']];
    _requireUnlocked(t as Map, c, 'timelineRange.start');
    final next = _start(c) + operation.delta;
    if (next < Q.of(0)) {
      throw const StudioException('NEGATIVE_TIMELINE_START');
    }
    if (t['kind'] == 'video' &&
        fps.quantize(next, Rounding.tiesToEven) != next) {
      throw const StudioException('NOT_ON_FRAME');
    }
    if (t['kind'] == 'audio' &&
        Q(sampleIndex(next, 48000, Rounding.tiesToEven), BigInt.from(48000)) !=
            next) {
      throw const StudioException('NOT_ON_SAMPLE');
    }
    final dest = (c['trackId'] as String);
    affected.add(dest);
    affected.add(dest); // source track is the same in this admitted slice
    rangesByTrack.putIfAbsent(dest, () => []).add((
      next,
      next + Q.fromJson(c['timelineRange']['duration']),
    ));
  }
  final keptTransitions = <Map>[];
  for (final t in d['transitions']) {
    final left = moved.contains(t['leftClipId']),
        right = moved.contains(t['rightClipId']);
    if (left && right) {
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
      keptTransitions.add(t as Map);
    }
  }
  if (operation.delta == Q.of(0)) {
    return before;
  }
  final touched = _carveOverwriteRanges(
    d,
    rangesByTrack,
    moved,
    version,
    newId,
  );
  _deleteAffectedTransitions(d, touched, moved, rangesByTrack);
  for (final id in moved) {
    final c = clips[id];
    c['timelineRange']['start'] = (_start(c as Map) + operation.delta).toJson();
    c['version'] = version(id);
  }
  for (final t in keptTransitions) {
    if ((d['transitions'] as List).any((x) => x['id'] == t['id'])) {
      t['cut'] = (Q.fromJson(t['cut']) + operation.delta).toJson();
      t['version'] = version(t['id'] as String);
    }
  }
  final oldDuration = Q.fromJson(s['duration']);
  var needed = oldDuration;
  for (final id in moved) {
    final end = _end(clips[id] as Map);
    if (end > needed) {
      needed = end;
    }
  }
  _rewriteMediaTracks(s, tracks, affected, version, newId, needed);
  followClipLocalCaptions(d, nextVersion: version);
  _markMovedLinksOutOfSync(d, moved);
  final result = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(result);
  return result;
}

void _pasteOverwriteCarve(
  Map d,
  List<Map<String, dynamic>> incoming,
  Map<String, String> trackMap,
  VersionAllocator version,
  IdAllocator newId,
) {
  final rangesByTrack = <String, List<(Q, Q)>>{};
  for (final c in incoming) {
    final dest = trackMap[c['trackId']] ?? c['trackId'] as String;
    rangesByTrack.putIfAbsent(dest, () => []).add((_start(c), _end(c)));
  }
  final touched = _carveOverwriteRanges(
    d,
    rangesByTrack,
    const {},
    version,
    newId,
  );
  _deleteAffectedTransitions(d, touched, const {}, rangesByTrack);
}
