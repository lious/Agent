part of 'edit_algebra.dart';

/// Internal session clipboard package. Not the OS clipboard and not a new
/// SQLite table: paste embeds this payload in one ordinary command.
final class ClipboardPayload {
  ClipboardPayload._({
    required this.projectId,
    required this.origin,
    required this.clipIds,
    required this.tracks,
    required this.clips,
    required this.effects,
    required this.linkGroups,
    required this.selectionGroups,
    required this.transitions,
    required this.hash,
  });
  final String projectId, hash;
  final Q origin;
  final List<String> clipIds, tracks;
  final List<Map<String, dynamic>> clips,
      effects,
      linkGroups,
      selectionGroups,
      transitions;
  Map<String, Object?> toJson() => {
    'projectId': projectId,
    'origin': origin.toJson(),
    'clipIds': clipIds,
    'tracks': tracks,
    'clips': clips,
    'effects': effects,
    'linkGroups': linkGroups,
    'selectionGroups': selectionGroups,
    'transitions': transitions,
    'hash': hash,
  };
  factory ClipboardPayload.fromJson(Map<String, dynamic> raw) {
    final body = Map<String, dynamic>.from(raw)..remove('hash');
    final hash = contentHash(body);
    if (raw['hash'] != hash) {
      throw const StudioException('CLIPBOARD_HASH_MISMATCH');
    }
    return ClipboardPayload._(
      projectId: raw['projectId'] as String,
      origin: Q.fromJson(raw['origin']),
      clipIds: List<String>.from(raw['clipIds'] as List),
      tracks: List<String>.from(raw['tracks'] as List),
      clips: [
        for (final c in raw['clips'] as List)
          Map<String, dynamic>.from(jsonDecode(jsonEncode(c)) as Map),
      ],
      effects: [
        for (final e in raw['effects'] as List)
          Map<String, dynamic>.from(jsonDecode(jsonEncode(e)) as Map),
      ],
      linkGroups: [
        for (final g in raw['linkGroups'] as List)
          Map<String, dynamic>.from(jsonDecode(jsonEncode(g)) as Map),
      ],
      selectionGroups: [
        for (final g in raw['selectionGroups'] as List)
          Map<String, dynamic>.from(jsonDecode(jsonEncode(g)) as Map),
      ],
      transitions: [
        for (final t in raw['transitions'] as List)
          Map<String, dynamic>.from(jsonDecode(jsonEncode(t)) as Map),
      ],
      hash: hash,
    );
  }
}

final class GroupClips extends EditOperation {
  GroupClips(Iterable<String> ids)
    : clipIds = List.unmodifiable(ids.take(100001).toList()..sort()) {
    _requireSelection(clipIds);
    if (clipIds.length < 2) {
      throw const StudioException('GROUP_TOO_SMALL');
    }
  }
  final List<String> clipIds;
  @override
  Map<String, Object?> toJson() => {'kind': 'groupClips', 'clipIds': clipIds};
}

final class UngroupClips extends EditOperation {
  UngroupClips(Iterable<String> ids)
    : groupIds = List.unmodifiable(ids.take(100001).toList()..sort()) {
    _requireSelection(groupIds);
  }
  final List<String> groupIds;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'ungroupClips',
    'groupIds': groupIds,
  };
}

/// Non-ripple lift of the complete admitted link+selection closure. Never
/// deletes original blobs/assets; leaves legal gaps and keeps duration.
final class LiftClips extends EditOperation {
  LiftClips(Iterable<String> ids)
    : clipIds = List.unmodifiable(ids.take(100001).toList()..sort()) {
    _requireSelection(clipIds);
  }
  final List<String> clipIds;
  @override
  Map<String, Object?> toJson() => {'kind': 'liftClips', 'clipIds': clipIds};
}

/// Same-project paste onto existing same-kind tracks.
/// mode=reject is default; mode=overwrite carves destination intervals and
/// does not move later content. mode=insert splits ripple tracks at [at],
/// shifts later content by the package span, and fills gaps on non-target
/// ripple tracks. Cross-project import, new-track creation, ripple-close
/// of a move source, and OS clipboard are not opened in this slice.
final class PasteClips extends EditOperation {
  PasteClips(
    ClipboardPayload payload, {
    required this.at,
    Map<String, String>? targetTrackMap,
    String mode = 'reject',
    Iterable<String>? rippleTrackIds,
  }) : payload = ClipboardPayload.fromJson(payload.toJson()),
       targetTrackMap = Map.unmodifiable(
         Map<String, String>.from(targetTrackMap ?? const {}),
       ),
       mode = _requireCollisionMode(mode),
       rippleTrackIds = _validatedRippleTrackIds(mode, rippleTrackIds) {
    if (at < Q.of(0)) {
      throw const StudioException('NEGATIVE_TIMELINE_START');
    }
    for (final id in this.targetTrackMap.values) {
      requireId(id);
    }
    for (final id in this.targetTrackMap.keys) {
      requireId(id);
    }
  }
  final ClipboardPayload payload;
  final Q at;
  final Map<String, String> targetTrackMap;
  final String mode;
  final List<String>? rippleTrackIds;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'pasteClips',
    'payloadHash': payload.hash,
    'at': at.toJson(),
    'targetTrackMap': targetTrackMap,
    'mode': mode,
    'payload': payload.toJson(),
    if (rippleTrackIds != null) 'rippleTrackIds': rippleTrackIds,
  };
}

void _requireSelection(List<String> ids) {
  if (ids.isEmpty) {
    throw const StudioException('EMPTY_SELECTION');
  }
  if (ids.length > 100000) {
    throw const StudioException('SELECTION_LIMIT');
  }
  for (final id in ids) {
    requireId(id);
  }
  if (ids.toSet().length != ids.length) {
    throw const StudioException('DUPLICATE_SELECTION');
  }
}

/// Shared closure for move/copy/cut: admitted media clips, complete link
/// groups, and complete selection groups. Caption/gap/marker items refuse.
List<String> expandedEditClipIds(
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
  final links = {for (final g in d['linkGroups']) g['id']: g};
  final groups = {for (final g in d['selectionGroups']) g['id']: g};
  final result = <String>{};
  final queue = clipIds.toList();
  for (var i = 0; i < queue.length; i++) {
    final id = queue[i];
    if (!result.add(id)) {
      continue;
    }
    if (invalid.contains(id)) {
      throw const StudioException('SELECTION_ITEM_UNSUPPORTED');
    }
    final c = clips[id];
    if (c == null) {
      throw const StudioException('CLIP_NOT_FOUND');
    }
    final link = c['linkGroupId'];
    if (link != null) {
      final g = links[link];
      if (g == null) {
        throw const StudioException('LINK_MEMBERSHIP_MISMATCH');
      }
      for (final m in g['members']) {
        queue.add(m['clipId'] as String);
      }
    }
    final group = c['selectionGroupId'];
    if (group != null) {
      final g = groups[group];
      if (g == null) {
        throw const StudioException('GROUP_MEMBERSHIP_MISMATCH');
      }
      for (final m in g['memberClipIds']) {
        queue.add(m as String);
      }
    }
  }
  return List.unmodifiable(result.toList()..sort());
}

ClipboardPayload buildClipboard(
  ProjectDocument before,
  Iterable<String> clipIds,
) {
  final selected = expandedEditClipIds(before, clipIds).toSet();
  _requireTransitionsComplete(before.toJson(), selected);
  final d = before.toJson(), s = d['sequences'][0];
  final clips = <Map<String, dynamic>>[];
  final trackIds = <String>{};
  final starts = <Q>[];
  for (final t in s['tracks']) {
    for (final c in t['items']) {
      if (selected.contains(c['id'])) {
        clips.add(Map<String, dynamic>.from(jsonDecode(jsonEncode(c)) as Map));
        trackIds.add(t['id'] as String);
        starts.add(Q.fromJson(c['timelineRange']['start']));
      }
    }
  }
  starts.sort();
  final origin = starts.first;
  final effects = [
    for (final e in d['effects'])
      if (e['owner'] is Map && selected.contains(e['owner']['id']))
        Map<String, dynamic>.from(jsonDecode(jsonEncode(e)) as Map),
  ];
  final links = [
    for (final g in d['linkGroups'])
      if ((g['members'] as List).any((m) => selected.contains(m['clipId'])))
        Map<String, dynamic>.from(jsonDecode(jsonEncode(g)) as Map),
  ];
  final groups = [
    for (final g in d['selectionGroups'])
      if ((g['memberClipIds'] as List).any(selected.contains))
        Map<String, dynamic>.from(jsonDecode(jsonEncode(g)) as Map),
  ];
  final transitions = [
    for (final t in d['transitions'])
      if (selected.contains(t['leftClipId']))
        Map<String, dynamic>.from(jsonDecode(jsonEncode(t)) as Map),
  ];
  final body = {
    'projectId': d['projectId'],
    'origin': origin.toJson(),
    'clipIds': (selected.toList()..sort()),
    'tracks': (trackIds.toList()..sort()),
    'clips': clips,
    'effects': effects,
    'linkGroups': links,
    'selectionGroups': groups,
    'transitions': transitions,
  };
  return ClipboardPayload.fromJson({...body, 'hash': contentHash(body)});
}

void _requireTransitionsComplete(Map d, Set<String> selected) {
  for (final t in d['transitions']) {
    final left = selected.contains(t['leftClipId']),
        right = selected.contains(t['rightClipId']);
    if (left != right) {
      throw const StudioException('TRANSITION_COPY_REQUIRES_BOTH');
    }
  }
}

void _requireUnlocked(Map track, Map clip, String field) {
  if (track['locked'] == true ||
      (clip['lockedFields'] as List).any(
        (f) =>
            f == '*' ||
            f == field ||
            field.startsWith('$f.') ||
            (f as String).startsWith('$field.'),
      )) {
    throw const StudioException('FIELD_LOCKED');
  }
}

Q _start(Map c) => Q.fromJson(c['timelineRange']['start']);
Q _end(Map c) => _start(c) + Q.fromJson(c['timelineRange']['duration']);

void _rewriteMediaTracks(
  Map s,
  List tracks,
  Set<String> affected,
  VersionAllocator version,
  IdAllocator newId,
  Q minimumDuration,
) {
  final fps = FrameRate(s['frameRate']['n'], s['frameRate']['d']);
  var maximum = minimumDuration;
  for (final track in tracks.where((t) => affected.contains(t['id']))) {
    final oldItems = track['items'] as List;
    final oldGaps = {
      for (final c in oldItems)
        if (c['source'] == null) '${_start(c as Map)}:${_end(c)}': c,
    };
    final items = oldItems.where((c) => c['source'] != null).toList()
      ..sort((a, b) {
        final cmp = _start(a as Map).compareTo(_start(b as Map));
        return cmp != 0
            ? cmp
            : (a['id'] as String).compareTo(b['id'] as String);
      });
    final normalized = <dynamic>[];
    var cursor = Q.of(0);
    void gap(Q until) {
      if (until <= cursor) {
        return;
      }
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
      if (_start(c as Map) < cursor) {
        throw const StudioException('COLLISION');
      }
      gap(_start(c));
      normalized.add(c);
      cursor = _end(c);
    }
    var retained = cursor;
    if (oldItems.isNotEmpty &&
        oldItems.last['source'] == null &&
        _end(oldItems.last as Map) > retained) {
      retained = _end(oldItems.last as Map);
    }
    if (minimumDuration > retained) {
      retained = minimumDuration;
    }
    if (track['kind'] == 'video' &&
        retained != fps.quantize(retained, Rounding.ceil)) {
      // Audio may end between video frames. Preserve duration using a legal
      // video Gap boundary, never fabricate an off-grid tail gap.
      retained = fps.quantize(retained, Rounding.ceil);
    }
    gap(retained);
    cursor = retained;
    track['items'] = normalized;
    if (cursor > maximum) {
      maximum = cursor;
    }
  }
  s['duration'] = maximum.toJson();
  s['version'] = version(s['id'] as String);
}

ProjectDocument _clipboardEdit(
  ProjectDocument before,
  EditOperation operation,
  VersionAllocator version,
  IdAllocator newId,
) {
  if (operation is GroupClips) {
    return _groupClips(before, operation, version, newId);
  }
  if (operation is UngroupClips) {
    return _ungroupClips(before, operation, version);
  }
  if (operation is LiftClips) {
    return _liftClips(before, operation, version, newId);
  }
  return _pasteClips(before, operation as PasteClips, version, newId);
}

ProjectDocument _groupClips(
  ProjectDocument before,
  GroupClips operation,
  VersionAllocator version,
  IdAllocator newId,
) {
  // Grouping is not a link: explicit IDs only, never silently add AV partners.
  final d = before.toJson(), s = d['sequences'][0];
  final tracks = {for (final t in s['tracks']) t['id']: t};
  final clips = {
    for (final t in s['tracks'])
      for (final c in t['items'])
        if (c['source'] != null) c['id']: c,
  };
  final existing = <String>{};
  for (final id in operation.clipIds) {
    final c = clips[id];
    if (c == null) {
      throw const StudioException('CLIP_NOT_FOUND');
    }
    final track = tracks[c['trackId']];
    if (track == null || !['video', 'audio'].contains(track['kind'])) {
      throw const StudioException('SELECTION_ITEM_UNSUPPORTED');
    }
    _requireUnlocked(track as Map, c as Map, 'selectionGroupId');
    if (c['selectionGroupId'] != null) {
      existing.add(c['selectionGroupId'] as String);
    }
  }
  if (existing.length == 1) {
    final group = (d['selectionGroups'] as List).singleWhere(
      (g) => g['id'] == existing.single,
    );
    final members = List<String>.from(group['memberClipIds'] as List)..sort();
    if (contentHash(members) == contentHash(operation.clipIds)) {
      return before;
    }
    throw const StudioException('GROUP_ALREADY_MEMBER');
  }
  if (existing.isNotEmpty) {
    throw const StudioException('GROUP_ALREADY_MEMBER');
  }
  final groupId = newId();
  (d['selectionGroups'] as List).add({
    'id': groupId,
    'memberClipIds': operation.clipIds,
  });
  for (final id in operation.clipIds) {
    final c = clips[id] as Map;
    c['selectionGroupId'] = groupId;
    c['version'] = version(id);
  }
  s['version'] = version(s['id'] as String);
  final result = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(result);
  return result;
}

ProjectDocument _ungroupClips(
  ProjectDocument before,
  UngroupClips operation,
  VersionAllocator version,
) {
  final d = before.toJson(), s = d['sequences'][0];
  final tracks = {for (final t in s['tracks']) t['id']: t};
  final clips = {
    for (final t in s['tracks'])
      for (final c in t['items'])
        if (c['source'] != null) c['id']: c,
  };
  final groups = {for (final g in d['selectionGroups']) g['id']: g};
  var changed = false;
  for (final id in operation.groupIds) {
    final group = groups[id];
    if (group == null) {
      throw const StudioException('GROUP_NOT_FOUND');
    }
    for (final memberId in group['memberClipIds']) {
      final c = clips[memberId];
      if (c == null) {
        throw const StudioException('GROUP_MEMBERSHIP_MISMATCH');
      }
      _requireUnlocked(
        tracks[c['trackId']] as Map,
        c as Map,
        'selectionGroupId',
      );
    }
  }
  final removing = operation.groupIds.toSet();
  for (final id in operation.groupIds) {
    for (final memberId in groups[id]['memberClipIds']) {
      final c = clips[memberId] as Map;
      if (c['selectionGroupId'] != null) {
        c['selectionGroupId'] = null;
        c['version'] = version(memberId as String);
        changed = true;
      }
    }
  }
  final beforeCount = (d['selectionGroups'] as List).length;
  (d['selectionGroups'] as List).removeWhere((g) => removing.contains(g['id']));
  if ((d['selectionGroups'] as List).length != beforeCount) {
    changed = true;
  }
  if (!changed) {
    return before;
  }
  s['version'] = version(s['id'] as String);
  final result = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(result);
  return result;
}

ProjectDocument _liftClips(
  ProjectDocument before,
  LiftClips operation,
  VersionAllocator version,
  IdAllocator newId,
) {
  final removed = expandedEditClipIds(before, operation.clipIds).toSet();
  final d = before.toJson();
  _requireTransitionsComplete(d, removed);
  final s = d['sequences'][0];
  final tracks = s['tracks'] as List;
  final trackById = {for (final t in tracks) t['id']: t};
  final clips = {
    for (final t in tracks)
      for (final c in t['items'])
        if (c['source'] != null) c['id']: c,
  };
  final affected = <String>{};
  for (final id in removed) {
    final c = clips[id] as Map, t = trackById[c['trackId']] as Map;
    _requireUnlocked(t, c, 'timelineRange.start');
    if ((d['transitions'] as List).any(
      (tr) => tr['leftClipId'] == id || tr['rightClipId'] == id,
    )) {
      _requireUnlocked(t, c, 'transitions');
    }
    affected.add(c['trackId'] as String);
  }
  for (final t in tracks) {
    (t['items'] as List).removeWhere((c) => removed.contains(c['id']));
  }
  (d['effects'] as List).removeWhere(
    (e) => e['owner'] is Map && removed.contains(e['owner']['id']),
  );
  (d['transitions'] as List).removeWhere(
    (t) =>
        removed.contains(t['leftClipId']) || removed.contains(t['rightClipId']),
  );
  (d['linkGroups'] as List).removeWhere(
    (g) => (g['members'] as List).any((m) => removed.contains(m['clipId'])),
  );
  for (final g in d['selectionGroups']) {
    (g['memberClipIds'] as List).removeWhere(removed.contains);
    for (final id in g['memberClipIds']) {
      final c = clips[id];
      if (c != null) {
        c['version'] = version(id as String);
      }
    }
  }
  (d['selectionGroups'] as List).removeWhere(
    (g) => (g['memberClipIds'] as List).isEmpty,
  );
  _rewriteMediaTracks(
    s,
    tracks,
    affected,
    version,
    newId,
    Q.fromJson(s['duration']),
  );
  final result = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(result);
  return result;
}

ProjectDocument _pasteClips(
  ProjectDocument before,
  PasteClips operation,
  VersionAllocator version,
  IdAllocator newId,
) {
  final payload = operation.payload;
  final d = before.toJson();
  final markerLocals = snapshotClipLocalMarkerLocals(d);
  if (payload.projectId != d['projectId']) {
    throw const StudioException('CROSS_PROJECT_PASTE_NOT_IMPLEMENTED');
  }
  final s = d['sequences'][0];
  final tracks = s['tracks'] as List;
  final trackById = {for (final t in tracks) t['id']: t};
  final assets = {for (final a in d['assets']) a['id']: a};
  final map = Map<String, String>.from(operation.targetTrackMap);
  for (final id in payload.tracks) {
    map.putIfAbsent(id, () => id);
    final dest = trackById[map[id]];
    final src = trackById[id];
    if (dest == null) {
      throw const StudioException('TRACK_NOT_FOUND');
    }
    if (src != null && src['kind'] != dest['kind']) {
      throw const StudioException('TRACK_KIND_MISMATCH');
    }
    if (src == null) {
      // Payload track no longer exists; destination kind must still be inferred
      // from the copied clips themselves below.
    }
  }
  for (final c in payload.clips) {
    final dest = trackById[map[c['trackId']]];
    if (dest == null) {
      throw const StudioException('TRACK_NOT_FOUND');
    }
    final source = c['source'];
    if (source == null || source['kind'] != 'asset') {
      throw const StudioException('SELECTION_ITEM_UNSUPPORTED');
    }
    final asset = assets[source['id']];
    if (asset == null) {
      throw const StudioException('REF_NOT_FOUND');
    }
    if (asset['version'] != source['version']) {
      throw const StudioException('SOURCE_VERSION_MISSING');
    }
    final kind = dest['kind'];
    if (kind != 'video' && kind != 'audio') {
      throw const StudioException('SELECTION_ITEM_UNSUPPORTED');
    }
    if (!(asset['streams'] as List).any(
      (st) => st['id'] == source['streamId'] && st['type'] == kind,
    )) {
      throw const StudioException('TRACK_KIND_MISMATCH');
    }
  }
  final fps = FrameRate(s['frameRate']['n'], s['frameRate']['d']);
  final delta = operation.at - payload.origin;
  final ids = <String, String>{};
  String remap(String id) => ids.putIfAbsent(id, newId);
  for (final c in payload.clips) {
    remap(c['id'] as String);
    for (final e in c['effectIds'] as List) {
      remap(e as String);
    }
    if (c['linkGroupId'] != null) {
      remap(c['linkGroupId'] as String);
    }
    if (c['selectionGroupId'] != null) {
      remap(c['selectionGroupId'] as String);
    }
  }
  for (final g in payload.linkGroups) {
    remap(g['id'] as String);
    remap(g['anchorClipId'] as String);
  }
  for (final g in payload.selectionGroups) {
    remap(g['id'] as String);
  }
  for (final t in payload.transitions) {
    remap(t['id'] as String);
  }
  final incoming = <Map<String, dynamic>>[];
  final affected = <String>{};
  for (final raw in payload.clips) {
    final c = Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)) as Map);
    final destId = map[raw['trackId']]!;
    final dest = trackById[destId] as Map;
    final start = _start(c) + delta;
    if (start < Q.of(0)) {
      throw const StudioException('NEGATIVE_TIMELINE_START');
    }
    if (dest['kind'] == 'video' &&
        fps.quantize(start, Rounding.tiesToEven) != start) {
      throw const StudioException('NOT_ON_FRAME');
    }
    if (dest['kind'] == 'audio' &&
        Q(sampleIndex(start, 48000, Rounding.tiesToEven), BigInt.from(48000)) !=
            start) {
      throw const StudioException('NOT_ON_SAMPLE');
    }
    _requireUnlocked(dest, c, 'timelineRange.start');
    c['id'] = remap(raw['id'] as String);
    c['version'] = '1';
    c['trackId'] = destId;
    c['timelineRange'] = {
      'start': start.toJson(),
      'duration': c['timelineRange']['duration'],
    };
    c['effectIds'] = [
      for (final e in raw['effectIds'] as List) remap(e as String),
    ];
    c['linkGroupId'] = raw['linkGroupId'] == null
        ? null
        : remap(raw['linkGroupId'] as String);
    c['selectionGroupId'] = raw['selectionGroupId'] == null
        ? null
        : remap(raw['selectionGroupId'] as String);
    incoming.add(c);
    affected.add(destId);
  }
  if (operation.mode == 'overwrite') {
    _pasteOverwriteCarve(
      d,
      incoming,
      {
        for (final c in incoming)
          c['trackId'] as String: c['trackId'] as String,
      },
      version,
      newId,
    );
  }
  var minimumDuration = Q.fromJson(s['duration']);
  if (operation.mode == 'insert') {
    final opened = _pasteInsertOpen(
      d,
      incoming,
      operation.rippleTrackIds,
      version,
      newId,
    );
    affected.addAll(opened.rippleTrackIds);
    minimumDuration = opened.minimumDuration;
  }
  for (final c in incoming) {
    (trackById[c['trackId']]['items'] as List).add(c);
  }
  for (final raw in payload.effects) {
    final e = Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)) as Map);
    e['id'] = remap(raw['id'] as String);
    e['version'] = '1';
    if (e['owner'] is Map && e['owner']['kind'] == 'clip') {
      e['owner'] = {'kind': 'clip', 'id': remap(raw['owner']['id'] as String)};
    }
    if (e['keyframes'] is List) {
      e['keyframes'] = [
        for (final k in e['keyframes'] as List)
          {
            ...Map<String, dynamic>.from(k as Map),
            'id': remap(k['id'] as String),
          },
      ];
    }
    (d['effects'] as List).add(e);
  }
  for (final raw in payload.linkGroups) {
    final g = Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)) as Map);
    g['id'] = remap(raw['id'] as String);
    g['anchorClipId'] = remap(raw['anchorClipId'] as String);
    g['members'] = [
      for (final m in raw['members'] as List)
        {'clipId': remap(m['clipId'] as String), 'offset': m['offset']},
    ];
    (d['linkGroups'] as List).add(g);
  }
  for (final raw in payload.selectionGroups) {
    final g = Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)) as Map);
    g['id'] = remap(raw['id'] as String);
    g['memberClipIds'] = [
      for (final id in raw['memberClipIds'] as List) remap(id as String),
    ];
    (d['selectionGroups'] as List).add(g);
  }
  for (final raw in payload.transitions) {
    final t = Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)) as Map);
    t['id'] = remap(raw['id'] as String);
    t['version'] = '1';
    t['trackId'] = map[raw['trackId']] ?? raw['trackId'];
    t['leftClipId'] = remap(raw['leftClipId'] as String);
    t['rightClipId'] = remap(raw['rightClipId'] as String);
    t['cut'] = (Q.fromJson(raw['cut']) + delta).toJson();
    (d['transitions'] as List).add(t);
  }
  _rewriteMediaTracks(s, tracks, affected, version, newId, minimumDuration);
  followClipLocalCaptions(d, nextVersion: version);
  if (operation.mode != 'insert') {
    applyClipLocalMarkerLocals(d, markerLocals);
  }
  final result = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(result);
  return result;
}
