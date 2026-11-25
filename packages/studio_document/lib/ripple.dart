part of 'edit_algebra.dart';

/// First-version ripple delete or close: a single continuous timeline range
/// either from the complete link and selection closure, or from an explicit
/// [range] (DeleteSelection range). Later content on participating tracks
/// shifts left by L. Insert-mode moves still vacate their source as a gap;
/// closing that hole is this range command, not a new MoveClips mode.
/// Ripple-trim lengthening is not opened in this slice.
final class RippleDeleteClips extends EditOperation {
  RippleDeleteClips(
    Iterable<String> ids, {
    this.range,
    Iterable<String>? rippleTrackIds,
  }) : clipIds = List.unmodifiable(ids.take(100001).toList()..sort()),
       rippleTrackIds = _optionalRippleTrackList(rippleTrackIds) {
    if (range != null && clipIds.isNotEmpty) {
      throw const StudioException('RIPPLE_RANGE_AND_SELECTION');
    }
    if (range == null) {
      _requireSelection(clipIds);
    } else if (range!.start < Q.of(0)) {
      throw const StudioException('NEGATIVE_TIMELINE_START');
    }
  }
  final List<String> clipIds;
  final TimeRange? range;
  final List<String>? rippleTrackIds;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'rippleDeleteClips',
    'clipIds': clipIds,
    'includeLinks': true,
    if (range != null)
      'range': {
        'start': range!.start.toJson(),
        'duration': range!.duration.toJson(),
      },
    if (rippleTrackIds != null) 'rippleTrackIds': rippleTrackIds,
  };
}

({Q start, Q duration}) _contiguousRange(Iterable<Map> clips) {
  final xs = [for (final c in clips) (_start(c), _end(c))]
    ..sort((a, b) => a.$1.compareTo(b.$1));
  if (xs.isEmpty || xs.any((r) => r.$2 <= r.$1)) {
    throw const StudioException('RIPPLE_RANGE_NOT_CONTIGUOUS');
  }
  var begin = xs.first.$1;
  var finish = xs.first.$2;
  for (final r in xs.skip(1)) {
    if (r.$1 > finish) {
      throw const StudioException('RIPPLE_RANGE_NOT_CONTIGUOUS');
    }
    if (r.$2 > finish) {
      finish = r.$2;
    }
  }
  if (finish <= begin) {
    throw const StudioException('RIPPLE_RANGE_NOT_CONTIGUOUS');
  }
  return (start: begin, duration: finish - begin);
}

void _requireRippleCloseWritable({
  required Map d,
  required Set<String> ripple,
  required Set<String> targets,
  required Q start,
  required Q end,
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
      final raw = c as Map;
      final a = _start(raw);
      final b = _end(raw);
      if (a < end && b > start || a >= end) {
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
      final a = _start(c);
      final b = _end(c);
      _requireUnlocked(t as Map, c, 'timelineRange.start');
      if (a < end && b > start && !(a >= start && b <= end)) {
        _requireUnlocked(t, c, 'sourceRange');
      }
    }
  }
}

void _repairRippleDeleteTransitions(
  Map d,
  Q start,
  Q length,
  Map<String, String> splitAtStart,
  Map<String, String> splitAtEnd,
  VersionAllocator version,
) {
  final end = start + length;
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
    if (cut > start && cut < end) {
      continue;
    }
    if (cut >= end) {
      if (splitAtEnd.containsKey(left)) {
        left = splitAtEnd[left]!;
        t['leftClipId'] = left;
      }
      if (splitAtEnd.containsKey(right)) {
        right = splitAtEnd[right]!;
        t['rightClipId'] = right;
      }
      cut = cut - length;
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

ProjectDocument _rippleDeleteClips(
  ProjectDocument before,
  RippleDeleteClips operation,
  VersionAllocator version,
  IdAllocator newId,
) {
  final d = before.toJson(), s = d['sequences'][0];
  final tracks = s['tracks'] as List;
  final clips = {
    for (final t in tracks)
      for (final c in t['items'])
        if (c['source'] != null) c['id']: c,
  };
  late final Set<String> removedIds;
  late final Q at;
  late final Q length;
  late final Q end;
  if (operation.range != null) {
    final span = operation.range!;
    if (span.start < Q.of(0)) {
      throw const StudioException('NEGATIVE_TIMELINE_START');
    }
    removedIds = {};
    at = span.start;
    length = span.duration;
    end = span.end;
  } else {
    removedIds = expandedEditClipIds(before, operation.clipIds).toSet();
    final selected = [for (final id in removedIds) clips[id] as Map];
    final span = _contiguousRange(selected);
    at = span.start;
    length = span.duration;
    end = at + length;
  }
  if (_captionsWouldShift(d, at)) {
    throw const StudioException('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED');
  }
  final fps = FrameRate(s['frameRate']['n'], s['frameRate']['d']);
  final targets = {for (final id in removedIds) clips[id]['trackId'] as String};
  final ripple = _resolveRippleTrackIds(
    tracks: tracks,
    targets: targets,
    explicit: operation.rippleTrackIds,
  );
  final byId = {for (final t in tracks) t['id'] as String: t};
  for (final id in ripple) {
    _requireGrid(byId[id] as Map, at, fps);
    _requireGrid(byId[id] as Map, length, fps);
    _requireGrid(byId[id] as Map, end, fps);
  }
  for (final id in removedIds) {
    final c = clips[id] as Map;
    _requireUnlocked(
      byId[c['trackId'] as String] as Map,
      c,
      'timelineRange.start',
    );
  }
  _requireRippleCloseWritable(
    d: d,
    ripple: ripple,
    targets: targets,
    start: at,
    end: end,
  );
  // Split the later bound first so existing coordinates stay stable.
  final splitEnd = _splitRippleAt(d, ripple, end, const {}, version, newId);
  _rebuildSplitLinkGroups(d, splitEnd, newId);
  final splitStart = _splitRippleAt(d, ripple, at, const {}, version, newId);
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
  _shiftRippleFrom(d, ripple, end, Q.of(0) - length, const {}, version);
  _repairRippleDeleteTransitions(d, at, length, splitStart, splitEnd, version);
  final old = Q.fromJson(s['duration']);
  var minimum = old - length;
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
