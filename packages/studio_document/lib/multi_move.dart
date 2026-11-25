part of 'edit_algebra.dart';

/// Current admitted slice: same tracks. includeLinks defaults to true and
/// expands AV link and selection-group closure. includeLinks=false moves only
/// the explicit IDs, marks a partially moved link allowOutOfSync, and does
/// not rewrite stored offsets. mode=reject remains the default;
/// mode=overwrite carves destination intervals. mode=insert opens a
/// package-span hole at the destination and shifts later content; the source
/// is vacated as a gap and is not ripple-closed. Ripple trim/delete still
/// always include links.
final class MoveClips extends EditOperation {
  MoveClips(
    Iterable<String> ids,
    this.delta, {
    String mode = 'reject',
    this.includeLinks = true,
    Iterable<String>? rippleTrackIds,
  }) : mode = _requireCollisionMode(mode),
       clipIds = List.unmodifiable(ids.take(100001).toList()..sort()),
       rippleTrackIds = _validatedRippleTrackIds(mode, rippleTrackIds) {
    if (clipIds.isEmpty) throw const StudioException('EMPTY_SELECTION');
    if (clipIds.length > 100000) throw const StudioException('SELECTION_LIMIT');
    for (final id in clipIds) {
      requireId(id);
    }
    if (clipIds.toSet().length != clipIds.length) {
      throw const StudioException('DUPLICATE_SELECTION');
    }
  }
  final List<String> clipIds;
  final Q delta;
  final String mode;
  final bool includeLinks;

  /// Null means the default union of target tracks and unlocked syncLock
  /// media tracks. Only legal with mode=insert.
  final List<String>? rippleTrackIds;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'moveClips',
    'clipIds': clipIds,
    'delta': delta.toJson(),
    'mode': mode,
    'includeLinks': includeLinks,
    'targetTrackId': null,
    if (rippleTrackIds != null) 'rippleTrackIds': rippleTrackIds,
  };
}

/// Read-only preview of the SAME closure used by the pure edit. No filtered IDs.
List<String> expandedMoveClipIds(ProjectDocument before, MoveClips operation) =>
    operation.includeLinks
    ? expandedEditClipIds(before, operation.clipIds)
    : _explicitMoveClipIds(before, operation.clipIds);

/// Validate the requested IDs only. Do not pull in unselected link partners
/// or unselected selection-group members.
List<String> _explicitMoveClipIds(
  ProjectDocument before,
  Iterable<String> clipIds,
) {
  requireLocalEditingWritable(before);
  final d = before.toJson(), s = d['sequences'][0];
  final clips = <String, Map>{};
  final invalid = <String>{
    for (final cue in d['captions']) cue['id'] as String,
  };
  for (final t in s['tracks']) {
    for (final c in t['items']) {
      if (c['source'] == null || !['video', 'audio'].contains(t['kind'])) {
        invalid.add(c['id'] as String);
      } else {
        clips[c['id'] as String] = c as Map;
      }
    }
  }
  final result = <String>{};
  for (final id in clipIds) {
    if (!result.add(id)) {
      continue;
    }
    if (invalid.contains(id)) {
      throw const StudioException('SELECTION_ITEM_UNSUPPORTED');
    }
    if (clips[id] == null) {
      throw const StudioException('CLIP_NOT_FOUND');
    }
  }
  return List.unmodifiable(result.toList()..sort());
}

/// Mark a link allowOutOfSync when this command moved only some of its members.
/// Stored offsets stay as originally recorded.
void _markMovedLinksOutOfSync(Map d, Set<String> movedIds) {
  for (final g in d['linkGroups'] as List) {
    final ids = [for (final m in g['members'] as List) m['clipId'] as String];
    final movedMembers = ids.where(movedIds.contains).length;
    if (movedMembers == 0 || movedMembers == ids.length) {
      continue;
    }
    g['syncPolicy'] = 'allowOutOfSync';
  }
}

ProjectDocument _moveClips(
  ProjectDocument before,
  MoveClips operation,
  VersionAllocator version,
  IdAllocator newId,
) {
  if (operation.mode == 'overwrite') {
    return _overwriteMoveClips(before, operation, version, newId);
  }
  if (operation.mode == 'insert') {
    return _insertMoveClips(before, operation, version, newId);
  }
  final moved = expandedMoveClipIds(before, operation).toSet();
  final d = before.toJson(), s = d['sequences'][0];
  final markerLocals = snapshotClipLocalMarkerLocals(d);
  final sourceAbs = snapshotSourceCaptionAbsolutes(d);
  final tracks = s['tracks'] as List;
  final clips = {
    for (final t in tracks)
      for (final c in t['items'])
        if (c['source'] != null) c['id']: c,
  };
  final trackById = {for (final t in tracks) t['id']: t};
  final affected = <String>{};
  final fps = FrameRate(s['frameRate']['n'], s['frameRate']['d']);
  Q start(Map c) => Q.fromJson(c['timelineRange']['start']);
  Q end(Map c) => start(c) + Q.fromJson(c['timelineRange']['duration']);
  void unlocked(Map c, String field) {
    if (trackById[c['trackId']]['locked'] == true ||
        (c['lockedFields'] as List).any(
          (f) =>
              f == '*' ||
              f == field ||
              field.startsWith('$f.') ||
              (f as String).startsWith('$field.'),
        )) {
      throw const StudioException('FIELD_LOCKED');
    }
  }

  // Validate the COMPLETE closure before changing any object, even zero delta.
  for (final id in moved) {
    final c = clips[id] as Map, t = trackById[c['trackId']];
    unlocked(c, 'timelineRange.start');
    final next = start(c) + operation.delta;
    if (next < Q.of(0)) throw const StudioException('NEGATIVE_TIMELINE_START');
    if (t['kind'] == 'video' &&
        fps.quantize(next, Rounding.tiesToEven) != next) {
      throw const StudioException('NOT_ON_FRAME');
    }
    if (t['kind'] == 'audio' &&
        Q(sampleIndex(next, 48000, Rounding.tiesToEven), BigInt.from(48000)) !=
            next) {
      throw const StudioException('NOT_ON_SAMPLE');
    }
    affected.add(c['trackId'] as String);
  }
  final transitions = <Map>[];
  for (final t in d['transitions']) {
    final left = moved.contains(t['leftClipId']),
        right = moved.contains(t['rightClipId']);
    if (left != right) {
      throw const StudioException('TRANSITION_MOVE_REQUIRES_BOTH');
    }
    if (left) {
      unlocked(clips[t['leftClipId']] as Map, 'transitions');
      unlocked(clips[t['rightClipId']] as Map, 'transitions');
      transitions.add(t as Map);
    }
  }
  if (operation.delta == Q.of(0)) return before;
  for (final id in moved) {
    final c = clips[id];
    c['timelineRange']['start'] = (start(c as Map) + operation.delta).toJson();
    c['version'] = version(id);
  }
  for (final t in transitions) {
    t['cut'] = (Q.fromJson(t['cut']) + operation.delta).toJson();
    t['version'] = version(t['id'] as String);
  }
  // Remove the WHOLE moved set conceptually before the overlap test: all final
  // intervals are checked together, so adjacent selected clips may move as one.
  var maximum = Q.fromJson(
    s['duration'],
  ); // Move is not implicit ripple/shorten.
  for (final track in tracks.where((t) => affected.contains(t['id']))) {
    final oldItems = track['items'] as List;
    final oldGaps = {
      for (final c in oldItems)
        if (c['source'] == null) '${start(c as Map)}:${end(c)}': c,
    };
    final items = oldItems.where((c) => c['source'] != null).toList()
      ..sort((a, b) {
        final cmp = start(a as Map).compareTo(start(b as Map));
        return cmp != 0
            ? cmp
            : (a['id'] as String).compareTo(b['id'] as String);
      });
    final normalized = <dynamic>[];
    var cursor = Q.of(0);
    void gap(Q until) {
      if (until <= cursor) return;
      normalized.add(
        oldGaps['$cursor:$until'] ??
            {
              'id': newId(),
              'trackId': track['id'],
              'timelineRange': {
                'start': cursor.toJson(),
                'duration': (until - cursor).toJson(),
              },
            },
      );
    }

    for (final c in items) {
      if (start(c as Map) < cursor) throw const StudioException('COLLISION');
      gap(start(c));
      normalized.add(c);
      cursor = end(c);
    }
    var retained = cursor;
    if (oldItems.isNotEmpty &&
        oldItems.last['source'] == null &&
        end(oldItems.last as Map) > retained) {
      retained = end(oldItems.last as Map);
    }
    if (track['kind'] == 'video' && Q.fromJson(s['duration']) > retained) {
      // Audio may end between video frames. Preserve duration using a legal
      // video Gap boundary, never fabricate an off-grid tail gap.
      retained = fps.quantize(Q.fromJson(s['duration']), Rounding.ceil);
    }
    gap(retained);
    cursor = retained;
    track['items'] = normalized;
    if (cursor > maximum) maximum = cursor;
  }
  s['duration'] = maximum.toJson();
  s['version'] = version(s['id'] as String);
  // Source ranges/time maps, clip-local effects/keyframes/automation and link
  // offsets remain unchanged. Absolute captions stay at authored times.
  // clipLocal and source-anchored cues translate with their host;
  // uncovering a source window refuses the whole command.
  applySourceCaptionAbsolutes(d, sourceAbs, nextVersion: version);
  followClipLocalCaptions(d, nextVersion: version);
  applyClipLocalMarkerLocals(d, markerLocals);
  _markMovedLinksOutOfSync(d, moved);
  final result = ProjectDocument.fromJson(
    d,
  ); // handles/adjacency/closure revalidated.
  requireLocalEditingWritable(result);
  return result;
}
