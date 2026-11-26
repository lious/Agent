part of 'edit_algebra.dart';

/// Materialize a separate audio Clip with a pinned stream/version and an explicit
/// LinkGroup. Unlike the legacy per-export opt-in, this intent is persisted.
final class ExtractAudioClip extends EditOperation {
  const ExtractAudioClip(this.videoClipId, this.audioStreamId);
  final String videoClipId, audioStreamId;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'extractAudioClip',
    'videoClipId': videoClipId,
    'audioStreamId': audioStreamId,
  };
}

final class LinkAudioVideo extends EditOperation {
  const LinkAudioVideo(this.videoClipId, this.audioClipId);
  final String videoClipId, audioClipId;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'linkAudioVideo',
    'videoClipId': videoClipId,
    'audioClipId': audioClipId,
  };
}

final class UnlinkAudioVideo extends EditOperation {
  const UnlinkAudioVideo(this.groupId);
  final String groupId;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'unlinkAudioVideo',
    'groupId': groupId,
  };
}

final class SetAudioTrackState extends EditOperation {
  const SetAudioTrackState(
    this.trackId, {
    required this.muted,
    required this.solo,
  });
  final String trackId;
  final bool muted, solo;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'setAudioTrackState',
    'trackId': trackId,
    'muted': muted,
    'solo': solo,
  };
}

ProjectDocument _persistentAudioEdit(
  ProjectDocument before,
  EditOperation operation,
  VersionAllocator version,
  IdAllocator id,
) {
  final d = before.toJson(),
      s = d['sequences'][0],
      tracks = s['tracks'] as List,
      groups = d['linkGroups'] as List;
  final sourceAbs = snapshotSourceCaptionAbsolutes(d);
  final markerLocals = snapshotClipLocalMarkerLocals(d);
  ({Q start, Q end, String id})? leaveGapHost;
  final leaveGapHostIds = <String>[];
  final leaveGapClipId = switch (operation) {
    TrimClip(:final clipId, ripple: false) => clipId,
    DeleteClip(:final clipId, ripple: false) => clipId,
    _ => null,
  };
  if (leaveGapClipId != null) {
    for (final t in tracks) {
      for (final c in t['items']) {
        if (c['id'] == leaveGapClipId && c['source'] != null) {
          final cs = Q.fromJson(c['timelineRange']['start']);
          leaveGapHost = (
            start: cs,
            end: cs + Q.fromJson(c['timelineRange']['duration']),
            id: leaveGapClipId,
          );
          leaveGapHostIds.add(leaveGapClipId);
          final gid = c['linkGroupId'];
          if (gid != null) {
            for (final g in groups) {
              if (g['id'] == gid) {
                for (final m in g['members']) {
                  final mid = m['clipId'] as String;
                  if (!leaveGapHostIds.contains(mid)) {
                    leaveGapHostIds.add(mid);
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  final changed = <String>{};
  Q start(Map c) => Q.fromJson(c['timelineRange']['start']);
  Q duration(Map c) => Q.fromJson(c['timelineRange']['duration']);
  Q end(Map c) => start(c) + duration(c);
  Map track(Map c) => tracks.singleWhere((t) => t['id'] == c['trackId']) as Map;
  Map clip(String key) {
    for (final t in tracks) {
      for (final c in t['items']) {
        if (c['id'] == key && c['source'] != null) return c as Map;
      }
    }
    throw const StudioException('CLIP_NOT_FOUND');
  }

  void writable(Map c, List<String> paths) {
    if (track(c)['locked'] == true) throw const StudioException('FIELD_LOCKED');
    for (final field in c['lockedFields']) {
      if (paths.any(
        (p) =>
            p == field ||
            p.startsWith('$field.') ||
            (field as String).startsWith('$p.'),
      )) {
        throw const StudioException('FIELD_LOCKED');
      }
    }
  }

  void set(Map c, String range, String field, Q value) {
    c[range][field] = value.toJson();
    changed.add(c['id'] as String);
  }

  void link(Map v, Map a) {
    if (track(v)['kind'] != 'video' || track(a)['kind'] != 'audio') {
      throw const StudioException('LINK_TRACK_MISMATCH');
    }
    for (final c in [v, a]) {
      writable(c, ['linkGroupId']);
      if (c['linkGroupId'] != null) {
        throw const StudioException('CLIP_ALREADY_LINKED');
      }
    }
    final group = id();
    v['linkGroupId'] = group;
    a['linkGroupId'] = group;
    changed.addAll([v['id'] as String, a['id'] as String]);
    groups.add({
      'id': group,
      'anchorClipId': v['id'],
      'members': [
        {'clipId': v['id'], 'offset': Q.of(0).toJson()},
        {'clipId': a['id'], 'offset': (start(a) - start(v)).toJson()},
      ],
      'syncPolicy': 'preserve',
    });
  }

  var retain = Q.fromJson(s['duration']);
  if (operation is ExtractAudioClip) {
    final video = clip(operation.videoClipId);
    writable(video, ['linkGroupId']);
    if (video['linkGroupId'] != null) {
      throw const StudioException('CLIP_ALREADY_LINKED');
    }
    if (track(video)['kind'] != 'video' ||
        video['timeMap']['kind'] != 'linear' ||
        Q.fromJson(video['timeMap']['rate']) != Q.of(1)) {
      throw const StudioException('AUDIO_EXTRACTION_TIME_MAP_UNSUPPORTED');
    }
    final asset = (d['assets'] as List).singleWhere(
      (a) => a['id'] == video['source']['id'],
    );
    final audio = (asset['streams'] as List).where(
      (st) => st['id'] == operation.audioStreamId && st['type'] == 'audio',
    );
    if (audio.length != 1) throw const StudioException('AUDIO_STREAM_REQUIRED');
    final visual = (asset['streams'] as List).singleWhere(
      (st) => st['id'] == video['source']['streamId'],
    );
    Q origin(dynamic st) =>
        Q(BigInt.parse(st['startPTS'] as String), BigInt.one) *
        Q.fromJson(st['timeBase']);
    final aStart = Q(
          sampleIndex(start(video), 48000, Rounding.tiesToEven),
          BigInt.from(48000),
        ),
        aEnd = Q(
          sampleIndex(end(video), 48000, Rounding.tiesToEven),
          BigInt.from(48000),
        );
    final sourceStart =
        origin(visual) +
        Q.fromJson(video['sourceRange']['start']) -
        origin(audio.single) +
        (aStart - start(video));
    if (sourceStart < Q.of(0) ||
        sourceStart + aEnd - aStart > Q.fromJson(audio.single['duration'])) {
      throw const StudioException('AUDIO_SOURCE_RANGE_UNAVAILABLE');
    }
    final audioTracks = tracks.where((t) => t['kind'] == 'audio');
    final Map at;
    if (audioTracks.isEmpty) {
      at = {
        'id': id(),
        'sequenceId': s['id'],
        'name': 'Audio',
        'kind': 'audio',
        'order': tracks.fold<int>(
          0,
          (m, t) => t['order'] >= m ? (t['order'] as int) + 1 : m,
        ),
        'locked': false,
        'muted': false,
        'solo': false,
        'syncLock': true,
        'targeted': true,
        'busId': s['masterBusId'],
        'items': <dynamic>[],
      };
      tracks.add(at);
    } else {
      at = audioTracks.single as Map;
    }
    if (at['locked'] == true) throw const StudioException('FIELD_LOCKED');
    final copy = jsonDecode(jsonEncode(video)) as Map<String, dynamic>;
    copy['id'] = id();
    copy['version'] = '0';
    copy['trackId'] = at['id'];
    copy['name'] = '${video['name']} audio';
    copy['source']['streamId'] = operation.audioStreamId;
    copy['timelineRange'] = {
      'start': aStart.toJson(),
      'duration': (aEnd - aStart).toJson(),
    };
    copy['sourceRange'] = {
      'start': sourceStart.toJson(),
      'duration': (aEnd - aStart).toJson(),
    };
    copy['lockedFields'] = <String>[];
    copy['effectIds'] = <String>[]; // Visual opacity is never copied to audio.
    (at['items'] as List).add(copy);
    link(video, copy);
  } else if (operation is LinkAudioVideo) {
    link(clip(operation.videoClipId), clip(operation.audioClipId));
  } else if (operation is UnlinkAudioVideo) {
    final matches = groups.where((g) => g['id'] == operation.groupId).toList();
    if (matches.length != 1) {
      throw const StudioException('LINK_GROUP_NOT_FOUND');
    }
    for (final member in matches.single['members']) {
      final c = clip(member['clipId'] as String);
      writable(c, ['linkGroupId']);
      c['linkGroupId'] = null;
      changed.add(c['id'] as String);
    }
    groups.remove(matches.single);
  } else if (operation is SetAudioTrackState) {
    final matches = tracks
        .where((t) => t['id'] == operation.trackId && t['kind'] == 'audio')
        .toList();
    if (matches.length != 1) {
      throw const StudioException('AUDIO_TRACK_REQUIRED');
    }
    final t = matches.single;
    if (t['locked'] == true) throw const StudioException('FIELD_LOCKED');
    if (t['muted'] == operation.muted && t['solo'] == operation.solo) {
      return before;
    }
    t['muted'] = operation.muted;
    t['solo'] = operation.solo;
  } else if (operation is DeleteClip && operation.ripple) {
    // Reuse RippleDeleteClips: link closure, interval captions/markers, and
    // source-window refusal. Do not rewrite this as LINKED_RIPPLE or
    // CAPTION_SYNC_EDIT_NOT_IMPLEMENTED.
    return _rippleDeleteClips(
      before,
      RippleDeleteClips([operation.clipId]),
      version,
      id,
    );
  } else if (operation is TrimClip && operation.ripple) {
    // Reuse RippleTrimClip: link closure, interval captions/markers, and
    // source-window refusal. Do not rewrite this as LINKED_RIPPLE.
    return _rippleTrimClip(
      before,
      RippleTrimClip(operation.clipId, operation.edge, operation.delta),
      version,
      id,
    );
  } else {
    if ((d['captions'] as List).isNotEmpty &&
        !(operation is SplitClip ||
            (operation is TrimClip && !operation.ripple) ||
            (operation is DeleteClip && !operation.ripple) ||
            operation is MoveClip ||
            operation is SlipClip ||
            operation is RollCut ||
            operation is SlideClip)) {
      throw const StudioException('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED');
    }
    if (operation is SlideClip) {
      final left = clip(operation.leftId);
      final mid = clip(operation.clipId);
      final right = clip(operation.rightId);
      if (left['trackId'] != mid['trackId'] ||
          mid['trackId'] != right['trackId'] ||
          start(left) + duration(left) != start(mid) ||
          start(mid) + duration(mid) != start(right)) {
        throw const StudioException('NOT_ADJACENT');
      }
      List<Map> groupOf(Map c) => c['linkGroupId'] == null
          ? [c]
          : [
              for (final m in groups.singleWhere(
                (g) => g['id'] == c['linkGroupId'],
              )['members'])
                clip(m['clipId'] as String),
            ];
      final lefts = groupOf(left);
      final mids = groupOf(mid);
      final rights = groupOf(right);
      for (final c in [...lefts, ...mids, ...rights]) {
        writable(c, ['timelineRange', 'sourceRange', 'timeMap']);
      }
      if (operation.delta == Q.of(0)) {
        return before;
      }
      final usedLefts = <String>{};
      final usedRights = <String>{};
      for (final m in mids) {
        Map? leftPartner;
        Map? rightPartner;
        for (final a in lefts) {
          if (a['trackId'] == m['trackId'] &&
              start(a) + duration(a) == start(m)) {
            leftPartner = a;
            break;
          }
        }
        for (final b in rights) {
          if (b['trackId'] == m['trackId'] &&
              start(m) + duration(m) == start(b)) {
            rightPartner = b;
            break;
          }
        }
        if (leftPartner == null || rightPartner == null) {
          throw const StudioException('NOT_ADJACENT');
        }
        usedLefts.add(leftPartner['id'] as String);
        usedRights.add(rightPartner['id'] as String);
        final ra = Q.fromJson(leftPartner['timeMap']['rate']);
        final rb = Q.fromJson(rightPartner['timeMap']['rate']);
        final delta = operation.delta;
        set(
          leftPartner,
          'timelineRange',
          'duration',
          duration(leftPartner) + delta,
        );
        set(
          leftPartner,
          'sourceRange',
          'duration',
          Q.fromJson(leftPartner['sourceRange']['duration']) + ra * delta,
        );
        set(m, 'timelineRange', 'start', start(m) + delta);
        set(
          rightPartner,
          'timelineRange',
          'start',
          start(rightPartner) + delta,
        );
        set(
          rightPartner,
          'timelineRange',
          'duration',
          duration(rightPartner) - delta,
        );
        set(
          rightPartner,
          'sourceRange',
          'start',
          Q.fromJson(rightPartner['sourceRange']['start']) + rb * delta,
        );
        set(
          rightPartner,
          'sourceRange',
          'duration',
          Q.fromJson(rightPartner['sourceRange']['duration']) - rb * delta,
        );
      }
      if (usedLefts.length != lefts.length ||
          usedRights.length != rights.length) {
        throw const StudioException('NOT_ADJACENT');
      }
    } else if (operation is RollCut) {
      final left = clip(operation.leftId);
      final right = clip(operation.rightId);
      if (left['trackId'] != right['trackId'] ||
          start(left) + duration(left) != start(right)) {
        throw const StudioException('NOT_ADJACENT');
      }
      List<Map> groupOf(Map c) => c['linkGroupId'] == null
          ? [c]
          : [
              for (final m in groups.singleWhere(
                (g) => g['id'] == c['linkGroupId'],
              )['members'])
                clip(m['clipId'] as String),
            ];
      final lefts = groupOf(left);
      final rights = groupOf(right);
      for (final c in [...lefts, ...rights]) {
        writable(c, ['timelineRange', 'sourceRange', 'timeMap']);
      }
      if (operation.delta == Q.of(0)) {
        return before;
      }
      final usedRights = <String>{};
      for (final a in lefts) {
        Map? partner;
        for (final b in rights) {
          if (b['trackId'] == a['trackId'] &&
              start(a) + duration(a) == start(b)) {
            partner = b;
            break;
          }
        }
        if (partner == null) {
          throw const StudioException('NOT_ADJACENT');
        }
        usedRights.add(partner['id'] as String);
        final ra = Q.fromJson(a['timeMap']['rate']);
        final rb = Q.fromJson(partner['timeMap']['rate']);
        final delta = operation.delta;
        set(a, 'timelineRange', 'duration', duration(a) + delta);
        set(
          a,
          'sourceRange',
          'duration',
          Q.fromJson(a['sourceRange']['duration']) + ra * delta,
        );
        set(partner, 'timelineRange', 'start', start(partner) + delta);
        set(partner, 'timelineRange', 'duration', duration(partner) - delta);
        set(
          partner,
          'sourceRange',
          'start',
          Q.fromJson(partner['sourceRange']['start']) + rb * delta,
        );
        set(
          partner,
          'sourceRange',
          'duration',
          Q.fromJson(partner['sourceRange']['duration']) - rb * delta,
        );
      }
      if (usedRights.length != rights.length) {
        throw const StudioException('NOT_ADJACENT');
      }
    } else {
      final key = switch (operation) {
        MoveClip(:final clipId) => clipId,
        TrimClip(:final clipId) => clipId,
        SlipClip(:final clipId) => clipId,
        DeleteClip(:final clipId) => clipId,
        SplitClip(:final clipId) => clipId,
        _ => throw const StudioException(
          'AUDIO_TIMELINE_EDIT_MODE_NOT_IMPLEMENTED',
        ),
      };
      final selected = clip(key);
      final members = selected['linkGroupId'] == null
          ? [selected]
          : [
              for (final m in groups.singleWhere(
                (g) => g['id'] == selected['linkGroupId'],
              )['members'])
                clip(m['clipId'] as String),
            ];
      if (operation is TrimClip && operation.ripple ||
          operation is DeleteClip && operation.ripple) {
        throw const StudioException('LINKED_RIPPLE_NOT_IMPLEMENTED');
      }
      for (final c in members) {
        writable(c, ['timelineRange', 'sourceRange', 'timeMap']);
      }
      final delta = switch (operation) {
        MoveClip(:final delta) => delta,
        TrimClip(:final delta) => delta,
        SlipClip(:final sourceDelta) => sourceDelta,
        _ => null,
      };
      if (delta == Q.of(0)) return before;
      if (operation is SplitClip) {
        final splitAt = operation.at;
        if (splitAt <= start(selected) || splitAt >= end(selected)) {
          throw const StudioException('INVALID_SPLIT');
        }
        final rights = <Map>[];
        for (final c in members) {
          final local = splitAt - start(selected);
          if (local <= Q.of(0) || local >= duration(c)) {
            throw const StudioException('LINKED_SPLIT_RANGE');
          }
          final rate = Q.fromJson(c['timeMap']['rate']),
              oldDuration = duration(c),
              oldSource = Q.fromJson(c['sourceRange']['start']);
          final right = jsonDecode(jsonEncode(c)) as Map<String, dynamic>;
          right['id'] = c['id'] == key ? operation.rightId : id();
          right['version'] = '0';
          changed.add(right['id'] as String);
          right['timelineRange'] = {
            'start': (start(c) + local).toJson(),
            'duration': (oldDuration - local).toJson(),
          };
          right['sourceRange'] = {
            'start': (oldSource + rate * local).toJson(),
            'duration': (rate * (oldDuration - local)).toJson(),
          };
          right['linkGroupId'] = null;
          set(c, 'timelineRange', 'duration', local);
          set(c, 'sourceRange', 'duration', rate * local);
          (track(c)['items'] as List).add(right);
          rights.add(right);
        }
        if (rights.length > 1) {
          link(
            rights.singleWhere((c) => track(c)['kind'] == 'video'),
            rights.singleWhere((c) => track(c)['kind'] == 'audio'),
          );
        }
      } else {
        for (final c in members) {
          final rate = Q.fromJson(c['timeMap']['rate']);
          switch (operation) {
            case MoveClip():
              set(c, 'timelineRange', 'start', start(c) + operation.delta);
            case TrimClip():
              if (operation.edge != 'in' && operation.edge != 'out') {
                throw const StudioException('INVALID_EDGE');
              }
              final incoming = operation.edge == 'in';
              set(
                c,
                'timelineRange',
                'duration',
                duration(c) +
                    (incoming ? Q.of(0) - operation.delta : operation.delta),
              );
              set(
                c,
                'sourceRange',
                'duration',
                Q.fromJson(c['sourceRange']['duration']) +
                    (incoming
                        ? Q.of(0) - rate * operation.delta
                        : rate * operation.delta),
              );
              if (incoming) {
                set(c, 'timelineRange', 'start', start(c) + operation.delta);
                set(
                  c,
                  'sourceRange',
                  'start',
                  Q.fromJson(c['sourceRange']['start']) +
                      rate * operation.delta,
                );
              }
            case SlipClip():
              set(
                c,
                'sourceRange',
                'start',
                Q.fromJson(c['sourceRange']['start']) + operation.sourceDelta,
              );
            case DeleteClip():
              (track(c)['items'] as List).remove(c);
            default:
              throw StateError('handled');
          }
        }
        if (operation is DeleteClip && selected['linkGroupId'] != null) {
          groups.removeWhere((g) => g['id'] == selected['linkGroupId']);
        }
      }
    }
  }
  // Canonical gaps and per-track collision/grid checks happen only after the whole
  // linked transaction. Failure never leaks a half-edited ProjectDocument.
  var maximum = Q.of(0);
  for (final t in tracks.where((t) => t['kind'] != 'caption')) {
    final items =
        (t['items'] as List).where((c) => c['source'] != null).toList()
          ..sort((a, b) => start(a).compareTo(start(b)));
    final normalized = <dynamic>[];
    var cursor = Q.of(0);
    for (final c in items) {
      if (start(c) < cursor) throw const StudioException('COLLISION');
      if (start(c) > cursor) {
        normalized.add({
          'id': id(),
          'trackId': t['id'],
          'timelineRange': {
            'start': cursor.toJson(),
            'duration': (start(c) - cursor).toJson(),
          },
        });
      }
      if (changed.contains(c['id'])) c['version'] = version(c['id'] as String);
      normalized.add(c);
      cursor = end(c);
    }
    // Preserve the pre-edit overall end only on video, not as forced tail padding
    // on every audio track. Explicit existing tail gaps are retained below.
    final oldTrack = (before.toJson()['sequences'][0]['tracks'] as List).where(
      (x) => x['id'] == t['id'],
    );
    if (oldTrack.isNotEmpty) {
      final oldItems = oldTrack.single['items'] as List;
      if (oldItems.isNotEmpty && oldItems.last['source'] == null) {
        final tailEnd = end(oldItems.last as Map);
        if (tailEnd > cursor) cursor = tailEnd;
      }
    }
    if (t['kind'] == 'video' && retain > cursor) cursor = retain;
    final builtEnd = normalized.isEmpty ? Q.of(0) : end(normalized.last as Map);
    if (cursor > builtEnd) {
      normalized.add({
        'id': id(),
        'trackId': t['id'],
        'timelineRange': {
          'start': builtEnd.toJson(),
          'duration': (cursor - builtEnd).toJson(),
        },
      });
    }
    t['items'] = normalized;
    if (cursor > maximum) maximum = cursor;
  }
  for (final c in d['captions']) {
    if (end(c as Map) > maximum) maximum = end(c);
  }
  s['duration'] = maximum.toJson();
  s['version'] = version(s['id'] as String);
  _normalizeOpacityOwners(d, version, id, before, operation);
  if (operation is SplitClip) {
    applySourceCaptionAbsolutes(d, sourceAbs, nextVersion: version);
    applyCaptionsAfterSplit(d, nextVersion: version);
    applyMarkersAfterSplit(d);
  } else if (operation is MoveClip) {
    applySourceCaptionAbsolutes(d, sourceAbs, nextVersion: version);
    followClipLocalCaptions(d, nextVersion: version);
    applyClipLocalMarkerLocals(d, markerLocals);
  } else if (operation is DeleteClip &&
      !operation.ripple &&
      leaveGapHost != null) {
    applySourceCaptionAbsolutes(d, sourceAbs, nextVersion: version);
    for (final hostId in leaveGapHostIds) {
      applyCaptionsAfterLeaveGapDelete(d, hostId: hostId, nextVersion: version);
      applyMarkersAfterLeaveGapDelete(d, hostId: hostId);
    }
  } else if (operation is TrimClip &&
      !operation.ripple &&
      leaveGapHost != null) {
    Q ns = leaveGapHost.start;
    Q ne = leaveGapHost.end;
    var found = false;
    for (final t in tracks) {
      for (final c in t['items']) {
        if (c['id'] == leaveGapHost.id && c['source'] != null) {
          ns = start(c as Map);
          ne = end(c);
          found = true;
        }
      }
    }
    if (found) {
      applySourceCaptionAbsolutes(d, sourceAbs, nextVersion: version);
      for (final hostId in leaveGapHostIds) {
        applyCaptionsAfterLeaveGapTrim(
          d,
          hostId: hostId,
          oldStart: leaveGapHost.start,
          oldEnd: leaveGapHost.end,
          newStart: ns,
          newEnd: ne,
          newId: id,
          nextVersion: version,
        );
        applyMarkersAfterLeaveGapTrim(
          d,
          hostId: hostId,
          newStart: ns,
          newEnd: ne,
        );
      }
    }
  } else if (operation is SlipClip) {
    applySourceCaptionAbsolutes(d, sourceAbs, nextVersion: version);
  } else if (operation is RollCut) {
    applySourceCaptionAbsolutes(d, sourceAbs, nextVersion: version);
    followClipLocalCaptions(d, nextVersion: version);
    applyClipLocalMarkerLocals(d, markerLocals);
  } else if (operation is SlideClip) {
    applySourceCaptionAbsolutes(d, sourceAbs, nextVersion: version);
    followClipLocalCaptions(d, nextVersion: version);
    applyClipLocalMarkerLocals(d, markerLocals);
  }
  final result = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(result);
  return result;
}
