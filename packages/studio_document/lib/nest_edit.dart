part of 'edit_algebra.dart';

const compoundExternalLink = 'COMPOUND_EXTERNAL_LINK';

/// Create a child sequence and replace the selection's bounding interval
/// with a pinned nest clip. External AV links must be unlinked first or
/// included in full; this does not silently break sync.
final class MakeCompound extends EditOperation {
  const MakeCompound(this.clipIds, this.newSequenceId, this.name);
  final List<String> clipIds;
  final String newSequenceId, name;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'makeCompound',
    'clipIds': clipIds,
    'newSequenceId': newSequenceId,
    'name': name,
  };
}

ProjectDocument _makeCompound(
  ProjectDocument before,
  MakeCompound operation,
  VersionAllocator version,
  IdAllocator newId,
) {
  requireId(operation.newSequenceId);
  if (operation.clipIds.isEmpty) {
    throw const StudioException('CLIP_NOT_FOUND', 'makeCompound');
  }
  for (final id in operation.clipIds) {
    requireId(id);
  }
  if (operation.clipIds.toSet().length != operation.clipIds.length) {
    throw const StudioException('DUPLICATE_ID', 'makeCompound');
  }

  final d = before.toJson();
  if ((d['sequences'] as List).any((s) => s['id'] == operation.newSequenceId)) {
    throw StudioException('DUPLICATE_ID', operation.newSequenceId);
  }

  final located = <String, ({Map sequence, Map track, Map clip})>{};
  for (final sequence in d['sequences'] as List) {
    for (final track in sequence['tracks'] as List) {
      if (track['locked'] == true) {
        for (final item in track['items'] as List) {
          if (operation.clipIds.contains(item['id'])) {
            throw const StudioException('FIELD_LOCKED');
          }
        }
      }
      for (final item in track['items'] as List) {
        if (operation.clipIds.contains(item['id'])) {
          if (item['source'] == null) {
            throw const StudioException('CLIP_NOT_FOUND', 'gap');
          }
          located[item['id'] as String] = (
            sequence: sequence as Map,
            track: track as Map,
            clip: item as Map,
          );
        }
      }
    }
  }
  for (final id in operation.clipIds) {
    if (!located.containsKey(id)) {
      throw StudioException('CLIP_NOT_FOUND', id);
    }
  }
  final hostIds = {for (final loc in located.values) loc.sequence['id']};
  if (hostIds.length != 1) {
    throw const StudioException('COMPOUND_CROSS_SEQUENCE');
  }
  final host = located.values.first.sequence;
  final groups = d['linkGroups'] as List;

  // External links must be unlinked or entirely included. Do not mark
  // allowOutOfSync or drop a partner.
  for (final loc in located.values) {
    final gid = loc.clip['linkGroupId'];
    if (gid == null) continue;
    final group = groups.cast<Map>().where((g) => g['id'] == gid);
    if (group.isEmpty) throw StudioException('REF_NOT_FOUND', gid as String);
    final members = [
      for (final m in group.single['members'] as List) m['clipId'] as String,
    ];
    if (!members.every(operation.clipIds.contains)) {
      throw StudioException(compoundExternalLink, gid as String);
    }
  }

  Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);
  Q durationOf(Map c) => Q.fromJson(c['timelineRange']['duration']);
  Q endOf(Map c) => startOf(c) + durationOf(c);

  var boundStart = startOf(located.values.first.clip);
  var boundEnd = endOf(located.values.first.clip);
  for (final loc in located.values) {
    if (startOf(loc.clip) < boundStart) boundStart = startOf(loc.clip);
    if (endOf(loc.clip) > boundEnd) boundEnd = endOf(loc.clip);
  }
  final span = boundEnd - boundStart;
  if (span <= Q.of(0)) throw const StudioException('INVALID_RANGE');

  final participating = <String, Map>{};
  for (final loc in located.values) {
    participating[loc.track['id'] as String] = loc.track;
  }

  // Unselected items inside the bounding interval on a participating track
  // would collide with the nest.
  for (final track in participating.values) {
    for (final item in track['items'] as List) {
      if (operation.clipIds.contains(item['id'])) continue;
      if (item['source'] == null) continue;
      final s = startOf(item as Map), e = endOf(item);
      if (s < boundEnd && e > boundStart) {
        throw const StudioException('COLLISION', 'makeCompound');
      }
    }
  }

  if ((d['transitions'] as List).isNotEmpty || hasLumaWipeEffects(d)) {
    throw const StudioException('TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL');
  }

  final childVersion = version(operation.newSequenceId);
  final childTracks = <Map<String, dynamic>>[];
  var trackOrder = 0;
  final nestByKind = <String, Map<String, dynamic>>{};
  final parentNests = <({Map track, Map nest})>[];

  final sortedTracks = participating.values.toList()
    ..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));

  for (final parentTrack in sortedTracks) {
    final childTrackId = newId();
    final moved = [
      for (final loc in located.values)
        if (loc.track['id'] == parentTrack['id'])
          jsonDecode(jsonEncode(loc.clip)) as Map<String, dynamic>,
    ]..sort((a, b) => startOf(a).compareTo(startOf(b)));
    for (final clip in moved) {
      clip['trackId'] = childTrackId;
      clip['timelineRange'] = {
        'start': (startOf(clip) - boundStart).toJson(),
        'duration': durationOf(clip).toJson(),
      };
      clip['version'] = version(clip['id']);
    }
    final items = <Map<String, dynamic>>[];
    var cursor = Q.of(0);
    void addGap(Q until) {
      if (until <= cursor) return;
      items.add({
        'id': newId(),
        'trackId': childTrackId,
        'timelineRange': {
          'start': cursor.toJson(),
          'duration': (until - cursor).toJson(),
        },
      });
      cursor = until;
    }

    for (final clip in moved) {
      addGap(startOf(clip));
      items.add(clip);
      cursor = endOf(clip);
    }
    addGap(span);

    final childTrack =
        jsonDecode(jsonEncode(parentTrack)) as Map<String, dynamic>;
    childTrack['id'] = childTrackId;
    childTrack['sequenceId'] = operation.newSequenceId;
    childTrack['order'] = trackOrder++;
    childTrack['items'] = items;
    childTracks.add(childTrack);

    final nestId = newId();
    final nest = <String, dynamic>{
      'id': nestId,
      'name': operation.name,
      'version': version(nestId),
      'trackId': parentTrack['id'],
      'enabled': true,
      'linkGroupId': null,
      'selectionGroupId': null,
      'shotId': null,
      'candidateId': null,
      'provenanceId': null,
      'lockedFields': <dynamic>[],
      'effectIds': <dynamic>[],
      'source': {
        'kind': 'sequence',
        'id': operation.newSequenceId,
        'version': childVersion,
        'streamId': null,
      },
      'sourceRange': {'start': Q.of(0).toJson(), 'duration': span.toJson()},
      'timelineRange': {
        'start': boundStart.toJson(),
        'duration': span.toJson(),
      },
      'timeMap': {'kind': 'linear', 'rate': Q.of(1).toJson()},
    };
    nestByKind[parentTrack['kind'] as String] = nest;
    parentNests.add((track: parentTrack, nest: nest));
  }

  final child = jsonDecode(jsonEncode(host)) as Map<String, dynamic>;
  child['id'] = operation.newSequenceId;
  child['name'] = operation.name;
  child['version'] = childVersion;
  child['duration'] = span.toJson();
  child['markerIds'] = <dynamic>[];
  child['tracks'] = childTracks;
  (d['sequences'] as List).add(child);

  for (final pair in parentNests) {
    final kept = <dynamic>[];
    for (final item in pair.track['items'] as List) {
      final id = item['id'];
      if (operation.clipIds.contains(id)) continue;
      if (item['source'] == null) {
        final s = startOf(item as Map), e = endOf(item);
        if (s >= boundStart && e <= boundEnd) continue;
      }
      kept.add(item);
    }
    kept.add(pair.nest);
    kept.sort((a, b) => startOf(a as Map).compareTo(startOf(b as Map)));
    final normalized = <dynamic>[];
    var cursor = Q.of(0);
    void addGap(Q until, String trackId) {
      if (until <= cursor) return;
      normalized.add({
        'id': newId(),
        'trackId': trackId,
        'timelineRange': {
          'start': cursor.toJson(),
          'duration': (until - cursor).toJson(),
        },
      });
      cursor = until;
    }

    for (final item in kept) {
      addGap(startOf(item as Map), pair.track['id'] as String);
      normalized.add(item);
      cursor = endOf(item);
    }
    final hostEnd = Q.fromJson(host['duration']);
    if (cursor < hostEnd && pair.track['kind'] != 'audio') {
      // Do not invent a tail gap past the existing sequence end unless
      // a hole remains before the current host duration.
    }
    // Fill only an interior hole before existing later content; if the last
    // kept item ends before hostEnd and there was already a trailing gap,
    // restore a tail gap only when the original track had one. Prefer
    // leaving duration to the sequence clock: if last item ends before
    // hostEnd, add an explicit tail gap so IMPLICIT_GAP is not raised.
    if (cursor < hostEnd) {
      addGap(hostEnd, pair.track['id'] as String);
    }
    pair.track['items'] = normalized;
  }

  // If both video and audio nest clips were created from a complete link,
  // link the parent nest pair so sync is not silently broken.
  if (nestByKind.containsKey('video') && nestByKind.containsKey('audio')) {
    final groupId = newId();
    final video = nestByKind['video']!;
    final audio = nestByKind['audio']!;
    video['linkGroupId'] = groupId;
    audio['linkGroupId'] = groupId;
    (d['linkGroups'] as List).add({
      'id': groupId,
      'anchorClipId': video['id'],
      'syncPolicy': 'preserve',
      'members': [
        {'clipId': video['id'], 'offset': Q.of(0).toJson()},
        {'clipId': audio['id'], 'offset': Q.of(0).toJson()},
      ],
    });
  }

  host['version'] = version(host['id']);

  // Refuse cycles and depth greater than 8 using the same graph the
  // 2.24 NestResolver already officialized.
  final edges = <String, List<NestEdge>>{};
  for (final sequence in d['sequences'] as List) {
    final id = sequence['id'] as String;
    edges[id] = [
      for (final track in sequence['tracks'] as List)
        for (final item in track['items'] as List)
          if (item['source'] != null && item['source']['kind'] == 'sequence')
            NestEdge(
              clipId: item['id'] as String,
              childSequenceId: item['source']['id'] as String,
              version: item['source']['version'] as String,
            ),
    ];
  }
  NestResolver(edges).validate(root: d['rootSequenceId'] as String);

  return ProjectDocument.fromJson(d);
}

const upgradePolicyUnsupported = 'UPGRADE_POLICY_UNSUPPORTED';
const upgradeRippleTracks = 'RIPPLE_TRACKS_REQUIRE_RIPPLE';

final _u64 = RegExp(r'^(0|[1-9][0-9]{0,18})$');

/// Retarget selected nest clips from a frozen [fromVersion] to the live
/// [toVersion]. If the child duration changes, [lengthPolicy] must be
/// fit, trim, or ripple. Other nests that still pin [fromVersion] are not
/// updated (no auto-follow).
final class UpgradeNest extends EditOperation {
  UpgradeNest(
    Iterable<String> clipIds,
    this.fromVersion,
    this.toVersion, {
    required this.lengthPolicy,
    Iterable<String> rippleTrackIds = const [],
  }) : clipIds = List.unmodifiable(clipIds.take(100001).toList()..sort()),
       rippleTrackIds = _optionalRippleTrackList(rippleTrackIds) ?? const [] {
    if (this.clipIds.isEmpty) {
      throw const StudioException('EMPTY_SELECTION');
    }
    if (this.clipIds.length > 100000) {
      throw const StudioException('SELECTION_LIMIT');
    }
    if (this.clipIds.toSet().length != this.clipIds.length) {
      throw const StudioException('DUPLICATE_SELECTION');
    }
    for (final id in this.clipIds) {
      requireId(id);
    }
    if (!_u64.hasMatch(fromVersion) || !_u64.hasMatch(toVersion)) {
      throw const StudioException('TIME_ENCODING', 'version');
    }
    if (lengthPolicy != 'fit' &&
        lengthPolicy != 'trim' &&
        lengthPolicy != 'ripple') {
      throw const StudioException(upgradePolicyUnsupported);
    }
    if (lengthPolicy != 'ripple' && this.rippleTrackIds.isNotEmpty) {
      throw const StudioException(upgradeRippleTracks);
    }
  }

  final List<String> clipIds;
  final String fromVersion, toVersion, lengthPolicy;
  final List<String> rippleTrackIds;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'upgradeNest',
    'clipIds': clipIds,
    'fromVersion': fromVersion,
    'toVersion': toVersion,
    'lengthPolicy': lengthPolicy,
    'rippleTrackIds': rippleTrackIds,
  };
}

ProjectDocument _upgradeNest(
  ProjectDocument before,
  UpgradeNest operation,
  VersionAllocator version,
  IdAllocator newId,
) {
  final d = before.toJson();
  Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);
  Q durationOf(Map c) => Q.fromJson(c['timelineRange']['duration']);
  Q endOf(Map c) => startOf(c) + durationOf(c);

  final located = <String, ({Map sequence, Map track, Map clip})>{};
  for (final sequence in d['sequences'] as List) {
    for (final track in sequence['tracks'] as List) {
      for (final item in track['items'] as List) {
        if (!operation.clipIds.contains(item['id'])) continue;
        if (item['source'] == null || item['source']['kind'] != 'sequence') {
          throw StudioException('CLIP_NOT_FOUND', item['id'] as String);
        }
        if (track['locked'] == true) {
          throw const StudioException('FIELD_LOCKED');
        }
        located[item['id'] as String] = (
          sequence: sequence as Map,
          track: track as Map,
          clip: item as Map,
        );
      }
    }
  }
  for (final id in operation.clipIds) {
    if (!located.containsKey(id)) {
      throw StudioException('CLIP_NOT_FOUND', id);
    }
  }

  final hostIds = {for (final loc in located.values) loc.sequence['id']};
  if (hostIds.length != 1) {
    throw const StudioException('COMPOUND_CROSS_SEQUENCE');
  }
  final host = located.values.first.sequence;
  if (host['id'] != d['rootSequenceId']) {
    throw const StudioException('FEATURE_NOT_IMPLEMENTED', 'upgradeNest.host');
  }

  final childIds = {
    for (final loc in located.values) loc.clip['source']['id'] as String,
  };
  if (childIds.length != 1) {
    throw const StudioException('COMPOUND_CROSS_SEQUENCE', 'child');
  }
  final childId = childIds.single;
  final children = [
    for (final s in d['sequences'] as List)
      if (s['id'] == childId) s as Map,
  ];
  if (children.length != 1) {
    throw StudioException('REF_NOT_FOUND', childId);
  }
  final child = children.single;
  if (child['version'] != operation.toVersion) {
    throw StudioException('SOURCE_VERSION_MISSING', operation.toVersion);
  }
  for (final loc in located.values) {
    final pin = loc.clip['source'];
    if (pin['id'] != childId || pin['version'] != operation.fromVersion) {
      throw StudioException('SOURCE_VERSION_MISSING', operation.fromVersion);
    }
  }

  final groups = d['linkGroups'] as List;
  for (final loc in located.values) {
    final gid = loc.clip['linkGroupId'];
    if (gid == null) continue;
    final group = groups.cast<Map>().where((g) => g['id'] == gid);
    if (group.isEmpty) throw StudioException('REF_NOT_FOUND', gid as String);
    final members = [
      for (final m in group.single['members'] as List) m['clipId'] as String,
    ];
    if (!members.every(operation.clipIds.contains)) {
      throw StudioException(compoundExternalLink, gid as String);
    }
  }

  if ((d['transitions'] as List).isNotEmpty || hasLumaWipeEffects(d)) {
    throw const StudioException('TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL');
  }

  final childDuration = Q.fromJson(child['duration']);
  if (childDuration <= Q.of(0)) {
    throw const StudioException('INVALID_RANGE', 'child');
  }

  final targets = <String>{
    for (final loc in located.values) loc.track['id'] as String,
  };
  final oldEnds = <String, Q>{
    for (final loc in located.values) loc.clip['id'] as String: endOf(loc.clip),
  };
  final oldDurations = <String, Q>{
    for (final loc in located.values)
      loc.clip['id'] as String: durationOf(loc.clip),
  };

  Set<String> ripple = targets;
  if (operation.lengthPolicy == 'ripple') {
    ripple = _resolveRippleTrackIds(
      tracks: host['tracks'] as List,
      targets: targets,
      explicit: operation.rippleTrackIds,
    );
    // Refuse a locked syncLock track that would have to move, except the
    // upgraded nest's own target tracks (those already checked FIELD_LOCKED).
    _requireRippleWritable(
      d: d,
      ripple: ripple,
      targets: targets,
      at: oldEnds.values.reduce((a, b) => a < b ? a : b),
      protected: operation.clipIds.toSet(),
    );
  }

  for (final loc in located.values) {
    final nest = loc.clip;
    final oldTimeline = oldDurations[nest['id'] as String]!;
    if (operation.lengthPolicy == 'fit') {
      if (oldTimeline <= Q.of(0)) {
        throw const StudioException('INVALID_RANGE');
      }
      nest['sourceRange'] = {
        'start': Q.of(0).toJson(),
        'duration': childDuration.toJson(),
      };
      nest['timeMap'] = {
        'kind': 'linear',
        'rate': (childDuration / oldTimeline).toJson(),
      };
      // timelineDuration stays.
    } else if (operation.lengthPolicy == 'trim') {
      final used = childDuration < oldTimeline ? childDuration : oldTimeline;
      nest['sourceRange'] = {
        'start': Q.of(0).toJson(),
        'duration': used.toJson(),
      };
      nest['timeMap'] = {'kind': 'linear', 'rate': Q.of(1).toJson()};
      nest['timelineRange']['duration'] = used.toJson();
    } else {
      nest['sourceRange'] = {
        'start': Q.of(0).toJson(),
        'duration': childDuration.toJson(),
      };
      nest['timeMap'] = {'kind': 'linear', 'rate': Q.of(1).toJson()};
      nest['timelineRange']['duration'] = childDuration.toJson();
    }
    nest['source']['version'] = operation.toVersion;
    nest['version'] = version(nest['id'] as String);
  }

  if (operation.lengthPolicy == 'ripple') {
    for (final loc in located.values) {
      final id = loc.clip['id'] as String;
      final delta = durationOf(loc.clip) - oldDurations[id]!;
      if (delta == Q.of(0)) continue;
      _shiftRippleFrom(d, ripple, oldEnds[id]!, delta, {id}, version);
    }
  }

  void rebuildGaps(Map track) {
    final items = [for (final item in track['items'] as List) item as Map]
      ..sort((a, b) => startOf(a).compareTo(startOf(b)));
    final media = [
      for (final item in items)
        if (item['source'] != null) item,
    ];
    final normalized = <Map<String, dynamic>>[];
    var cursor = Q.of(0);
    void addGap(Q until) {
      if (until <= cursor) return;
      normalized.add({
        'id': newId(),
        'trackId': track['id'],
        'timelineRange': {
          'start': cursor.toJson(),
          'duration': (until - cursor).toJson(),
        },
      });
      cursor = until;
    }

    for (final item in media) {
      addGap(startOf(item));
      normalized.add(Map<String, dynamic>.from(item));
      cursor = endOf(item);
    }
    final hostEnd = Q.fromJson(host['duration']);
    if (cursor < hostEnd) addGap(hostEnd);
    track['items'] = normalized;
  }

  final touched = {
    ...targets,
    if (operation.lengthPolicy == 'ripple') ...ripple,
  };
  for (final track in host['tracks'] as List) {
    if (touched.contains(track['id'])) {
      rebuildGaps(track as Map);
    }
  }

  host['version'] = version(host['id'] as String);
  var covered = Q.of(0);
  for (final track in host['tracks'] as List) {
    for (final item in track['items'] as List) {
      final e = endOf(item as Map);
      if (e > covered) covered = e;
    }
  }
  host['duration'] = covered.toJson();

  final edges = <String, List<NestEdge>>{};
  for (final sequence in d['sequences'] as List) {
    final id = sequence['id'] as String;
    edges[id] = [
      for (final track in sequence['tracks'] as List)
        for (final item in track['items'] as List)
          if (item['source'] != null && item['source']['kind'] == 'sequence')
            NestEdge(
              clipId: item['id'] as String,
              childSequenceId: item['source']['id'] as String,
              version: item['source']['version'] as String,
            ),
    ];
  }
  NestResolver(edges).validate(root: d['rootSequenceId'] as String);

  final after = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(after);
  return after;
}
