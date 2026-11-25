import 'package:studio_contracts/studio_contracts.dart';

import 'caption.dart';
import 'time.dart';

/// Sequence markers. [time] is always a sequence timeline position for both
/// absolute and clipLocal anchors; clipLocal markers also name a covering host
/// and follow that host by a captured local offset when the host moves.
///
/// Default new markers are absolute with ripple=false, so they stay put when
/// later content shifts. ripple=true absolute markers use the same interval
/// crop/split/shift as captions. A marker wholly inside a closed interval is
/// dropped as a crop-to-empty and comes back on undo; it is not silently
/// discarded outside the command inverse. clipLocal markers whose host still
/// covers them are not split by an insert-move destination hole. A remnant
/// with no covering host refuses the whole command. Marker labels are never
/// burned into preview or export media.
final class TimelineMarker {
  TimelineMarker(
    this.id, {
    required this.sequenceId,
    required this.label,
    required this.time,
    Q? duration,
    this.ripple = false,
    this.anchorKind = 'absolute',
    this.anchorClipId,
    List<num> colorRGBA = const [1, 0.8, 0.2, 1],
  }) : duration = duration ?? Q.of(0),
       colorRGBA = List.unmodifiable(
         colorRGBA.map((c) => c.toDouble()).toList(),
       ) {
    requireId(id);
    requireId(sequenceId);
    if (label.length > 1024 || label.contains('\u0000')) {
      throw const StudioException('MARKER_INVALID');
    }
    if (time < Q.of(0) || this.duration < Q.of(0)) {
      throw const StudioException('INVALID_RANGE');
    }
    if (this.colorRGBA.length != 4 ||
        this.colorRGBA.any((c) => c < 0 || c > 1)) {
      throw const StudioException('MARKER_INVALID');
    }
    if (anchorKind == 'absolute') {
      if (anchorClipId != null) {
        throw const StudioException('ANCHOR_INVALID');
      }
    } else if (anchorKind == 'clipLocal') {
      if (anchorClipId == null) {
        throw const StudioException('ANCHOR_INVALID');
      }
      requireId(anchorClipId!);
    } else {
      throw const StudioException('MARKER_ANCHOR_NOT_IMPLEMENTED');
    }
  }
  final String id, sequenceId, label, anchorKind;
  final String? anchorClipId;
  final Q time, duration;
  final bool ripple;
  final List<double> colorRGBA;

  TimelineMarker _copy({
    String? label,
    Q? time,
    Q? duration,
    bool? ripple,
    String? anchorKind,
    String? anchorClipId,
    List<num>? colorRGBA,
    bool clearAnchor = false,
  }) => TimelineMarker(
    id,
    sequenceId: sequenceId,
    label: label ?? this.label,
    time: time ?? this.time,
    duration: duration ?? this.duration,
    ripple: ripple ?? this.ripple,
    anchorKind: clearAnchor ? 'absolute' : (anchorKind ?? this.anchorKind),
    anchorClipId: clearAnchor ? null : (anchorClipId ?? this.anchorClipId),
    colorRGBA: colorRGBA ?? this.colorRGBA,
  );

  TimelineMarker edit({
    String? label,
    Q? time,
    Q? duration,
    bool? ripple,
    List<num>? colorRGBA,
  }) => _copy(
    label: label,
    time: time,
    duration: duration,
    ripple: ripple,
    colorRGBA: colorRGBA,
  );

  /// Pin this marker to a unique host that fully covers its current timeline
  /// range. [time] stays a sequence position; the local offset is captured
  /// when a later host move is applied.
  TimelineMarker anchoredToClip(String clipId, Q clipStart, Q clipDuration) {
    if (time < clipStart || time + duration > clipStart + clipDuration) {
      throw const StudioException('ANCHOR_OUT_OF_RANGE');
    }
    requireId(clipId);
    return _copy(anchorKind: 'clipLocal', anchorClipId: clipId);
  }

  TimelineMarker makeAbsolute() => _copy(clearAnchor: true);

  Map<String, Object?> toJson() => {
    'id': id,
    'sequenceId': sequenceId,
    'label': label,
    'colorRGBA': colorRGBA,
    'anchor': {'kind': anchorKind, 'clipId': anchorClipId},
    'time': time.toJson(),
    'duration': duration.toJson(),
    'ripple': ripple,
  };

  factory TimelineMarker.fromJson(Map<String, dynamic> m) {
    final anchor = m['anchor'];
    final kind = anchor['kind'] as String;
    if (kind != 'absolute' && kind != 'clipLocal') {
      throw const StudioException('MARKER_ANCHOR_NOT_IMPLEMENTED');
    }
    return TimelineMarker(
      m['id'] as String,
      sequenceId: m['sequenceId'] as String,
      label: m['label'] as String,
      time: Q.fromJson(m['time']),
      duration: Q.fromJson(m['duration']),
      ripple: m['ripple'] as bool,
      anchorKind: kind,
      anchorClipId: anchor['clipId'] as String?,
      colorRGBA: [
        for (final c in m['colorRGBA'] as List) (c as num).toDouble(),
      ],
    );
  }
}

final class MarkerStore {
  MarkerStore(List<TimelineMarker> values)
    : markers = List.unmodifiable(
        values.toList()..sort((a, b) {
          final n = a.time.compareTo(b.time);
          return n == 0 ? a.id.compareTo(b.id) : n;
        }),
      ) {
    if (values.length > 10000) {
      throw const StudioException('MARKER_RESOURCE_LIMIT');
    }
    if (values.map((m) => m.id).toSet().length != values.length) {
      throw const StudioException('DUPLICATE_ID');
    }
  }
  final List<TimelineMarker> markers;
}

/// Host that uniquely covers a marker, including a zero-duration point.
/// [TimeRange] rejects empty durations, so point markers cannot reuse
/// [coveringCaptionHostClipId] directly.
String? coveringMarkerHostClipId(Map d, Q time, Q duration) {
  if (duration > Q.of(0)) {
    return coveringCaptionHostClipId(d, TimeRange(time, duration));
  }
  String? videoId;
  String? mediaId;
  var videoCount = 0, mediaCount = 0;
  for (final t in (d['sequences'] as List).first['tracks'] as List) {
    if (t['kind'] != 'video' && t['kind'] != 'audio') {
      continue;
    }
    for (final c in t['items']) {
      if (c['source'] == null) {
        continue;
      }
      final start = Q.fromJson(c['timelineRange']['start']);
      final end = start + Q.fromJson(c['timelineRange']['duration']);
      if (time < start || time >= end) {
        continue;
      }
      mediaCount++;
      mediaId = c['id'] as String;
      if (t['kind'] == 'video') {
        videoCount++;
        videoId = mediaId;
      }
    }
  }
  if (videoCount == 1) {
    return videoId;
  }
  if (mediaCount == 1) {
    return mediaId;
  }
  return null;
}

Map<String, Map> _markerMediaClips(Map d) {
  final clips = <String, Map>{};
  for (final t in (d['sequences'] as List).first['tracks'] as List) {
    for (final c in t['items']) {
      if (c['source'] != null &&
          (t['kind'] == 'video' || t['kind'] == 'audio')) {
        clips[c['id'] as String] = c as Map;
      }
    }
  }
  return clips;
}

bool _rangeCoveredByClip(Map clip, Q start, Q duration) {
  final clipStart = Q.fromJson(clip['timelineRange']['start']);
  final clipDur = Q.fromJson(clip['timelineRange']['duration']);
  return start >= clipStart && start + duration <= clipStart + clipDur;
}

/// Capture clipLocal locals (timeline time minus then-current host start).
/// Call before any host on the document is moved, split, or removed.
Map<String, Q> snapshotClipLocalMarkerLocals(Map d) {
  final clips = _markerMediaClips(d);
  final locals = <String, Q>{};
  for (final raw in d['markers'] as List) {
    final m = raw as Map;
    if (m['anchor']['kind'] != 'clipLocal') {
      continue;
    }
    final host = clips[m['anchor']['clipId']];
    if (host == null) {
      throw const StudioException('ANCHOR_OUT_OF_RANGE');
    }
    final start = Q.fromJson(m['time']);
    final duration = Q.fromJson(m['duration']);
    if (!_rangeCoveredByClip(host, start, duration)) {
      throw const StudioException('ANCHOR_OUT_OF_RANGE');
    }
    locals[m['id'] as String] =
        start - Q.fromJson(host['timelineRange']['start']);
  }
  return locals;
}

/// Rewrite clipLocal marker times from [locals] and the host's current start.
/// Missing or no-longer-covering hosts are left for [applyMarkerIntervalEdit]
/// or refused when no interval is being applied.
void applyClipLocalMarkerLocals(
  Map d,
  Map<String, Q> locals, {
  bool refuseUncovered = true,
}) {
  if (locals.isEmpty) {
    return;
  }
  final clips = _markerMediaClips(d);
  for (final raw in d['markers'] as List) {
    final m = raw as Map;
    final local = locals[m['id']];
    if (local == null || m['anchor']['kind'] != 'clipLocal') {
      continue;
    }
    final host = clips[m['anchor']['clipId']];
    if (host == null) {
      if (refuseUncovered) {
        throw const StudioException('ANCHOR_OUT_OF_RANGE');
      }
      continue;
    }
    final duration = Q.fromJson(m['duration']);
    final next = Q.fromJson(host['timelineRange']['start']) + local;
    if (!_rangeCoveredByClip(host, next, duration)) {
      if (refuseUncovered) {
        throw const StudioException('ANCHOR_OUT_OF_RANGE');
      }
      continue;
    }
    if (Q.fromJson(m['time']) != next) {
      m['time'] = next.toJson();
    }
  }
}

void syncSequenceMarkerIds(Map d) {
  final s = (d['sequences'] as List).first;
  final ids = [for (final m in d['markers'] as List) m['id'] as String]..sort();
  s['markerIds'] = ids;
}

void requireWritableMarkers(Map d) {
  final markers = d['markers'] as List;
  if (markers.length > 10000) {
    throw const StudioException('MARKER_RESOURCE_LIMIT');
  }
  final s = (d['sequences'] as List).first;
  final sequenceId = s['id'] as String;
  final ids = {for (final m in markers) m['id'] as String};
  if (ids.length != markers.length) {
    throw const StudioException('DUPLICATE_ID');
  }
  final listed = [for (final id in s['markerIds'] as List) id as String];
  if (listed.length != ids.length || listed.any((id) => !ids.contains(id))) {
    throw const StudioException('MARKER_IDS_MISMATCH');
  }
  final clips = _markerMediaClips(d);
  for (final raw in markers) {
    final m = TimelineMarker.fromJson(Map<String, dynamic>.from(raw as Map));
    if (m.sequenceId != sequenceId) {
      throw const StudioException('PARENT_MISMATCH');
    }
    if (m.anchorKind == 'clipLocal') {
      final host = clips[m.anchorClipId];
      if (host == null || !_rangeCoveredByClip(host, m.time, m.duration)) {
        throw const StudioException('ANCHOR_OUT_OF_RANGE');
      }
    }
  }
}

/// Crop, split, and shift markers across one interval. See [TimelineMarker].
///
/// Call after media hosts have been rewritten and [applyClipLocalMarkerLocals]
/// has run for surviving hosts (use [refuseUncovered]: false so a host that
/// left a closed range can be dropped here instead of aborting). This path
/// must not also call [applyClipLocalMarkerLocals] with refuse-uncovered
/// after a close, which would refuse a marker that should be cropped away.
void applyMarkerIntervalEdit(
  Map d, {
  required Q at,
  required Q length,
  required bool opening,
  required String Function() newId,
}) {
  if (length <= Q.of(0)) {
    throw const StudioException('INVALID_TIME_RANGE');
  }
  final markers = d['markers'];
  if (markers is! List || markers.isEmpty) {
    return;
  }
  final clips = _markerMediaClips(d);
  final next = <Map<String, dynamic>>[];
  for (final raw in markers) {
    final marker = _cloneMarkerMap(raw as Map);
    final kind = marker['anchor']['kind'] as String;
    if (kind != 'absolute' && kind != 'clipLocal') {
      throw const StudioException('MARKER_ANCHOR_NOT_IMPLEMENTED');
    }
    final start = Q.fromJson(marker['time']);
    final duration = Q.fromJson(marker['duration']);
    if (kind == 'clipLocal' &&
        _clipLocalMarkerStillCovered(clips, marker, start, duration)) {
      next.add(marker);
      continue;
    }
    if (kind == 'absolute' && marker['ripple'] != true) {
      if (!opening && _whollyInsideClosed(start, duration, at, length)) {
        continue;
      }
      next.add(marker);
      continue;
    }
    _emitMarkerPieces(
      marker,
      _markerIntervalPieces(
        start: start,
        duration: duration,
        at: at,
        length: length,
        opening: opening,
      ),
      next: next,
      newId: newId,
    );
  }
  d['markers'] = next;
  _rebindClipLocalMarkersAfterInterval(d);
  syncSequenceMarkerIds(d);
}

bool _clipLocalMarkerStillCovered(
  Map<String, Map> clips,
  Map marker,
  Q start,
  Q duration,
) {
  final host = clips[marker['anchor']['clipId']];
  return host != null && _rangeCoveredByClip(host, start, duration);
}

bool _whollyInsideClosed(Q start, Q duration, Q at, Q length) {
  final end = at + length;
  if (duration == Q.of(0)) {
    return start >= at && start < end;
  }
  return start >= at && start + duration <= end;
}

List<({Q start, Q duration})> _markerIntervalPieces({
  required Q start,
  required Q duration,
  required Q at,
  required Q length,
  required bool opening,
}) {
  if (duration == Q.of(0)) {
    if (opening) {
      return [(start: start < at ? start : start + length, duration: duration)];
    }
    if (start < at) {
      return [(start: start, duration: duration)];
    }
    if (start >= at + length) {
      return [(start: start - length, duration: duration)];
    }
    return const [];
  }
  final cueEnd = start + duration;
  final end = at + length;
  if (opening) {
    if (cueEnd <= at) {
      return [(start: start, duration: duration)];
    }
    if (start >= at) {
      return [(start: start + length, duration: duration)];
    }
    return [
      (start: start, duration: at - start),
      (start: at + length, duration: cueEnd - at),
    ];
  }
  if (cueEnd <= at) {
    return [(start: start, duration: duration)];
  }
  if (start >= end) {
    return [(start: start - length, duration: duration)];
  }
  if (start >= at && cueEnd <= end) {
    return const [];
  }
  if (start < at && cueEnd <= end) {
    return [(start: start, duration: at - start)];
  }
  if (start >= at && cueEnd > end) {
    return [(start: at, duration: cueEnd - end)];
  }
  return [
    (start: start, duration: at - start),
    (start: at, duration: cueEnd - end),
  ];
}

void _emitMarkerPieces(
  Map<String, dynamic> marker,
  List<({Q start, Q duration})> pieces, {
  required List<Map<String, dynamic>> next,
  required String Function() newId,
}) {
  if (pieces.isEmpty) {
    return;
  }
  marker['time'] = pieces.first.start.toJson();
  marker['duration'] = pieces.first.duration.toJson();
  next.add(marker);
  for (final piece in pieces.skip(1)) {
    final right = _cloneMarkerMap(marker);
    right['id'] = newId();
    right['time'] = piece.start.toJson();
    right['duration'] = piece.duration.toJson();
    next.add(right);
  }
}

Map<String, dynamic> _cloneMarkerMap(Map raw) {
  return <String, dynamic>{
    ...Map<String, dynamic>.from(raw),
    'anchor': Map<String, dynamic>.from(raw['anchor'] as Map),
    'colorRGBA': List<dynamic>.from(raw['colorRGBA'] as List),
    'time': Map<String, dynamic>.from(raw['time'] as Map),
    'duration': Map<String, dynamic>.from(raw['duration'] as Map),
  };
}

void _rebindClipLocalMarkersAfterInterval(Map d) {
  final clips = _markerMediaClips(d);
  for (final raw in d['markers'] as List) {
    final m = raw as Map;
    if (m['anchor']['kind'] != 'clipLocal') {
      continue;
    }
    final start = Q.fromJson(m['time']);
    final duration = Q.fromJson(m['duration']);
    final preferred = m['anchor']['clipId'] as String;
    final current = clips[preferred];
    var hostId = preferred;
    if (current == null || !_rangeCoveredByClip(current, start, duration)) {
      final cover = coveringCaptionHostClipId(d, TimeRange(start, duration));
      if (cover == null) {
        throw const StudioException('ANCHOR_OUT_OF_RANGE');
      }
      hostId = cover;
    }
    if (hostId != preferred) {
      m['anchor']['clipId'] = hostId;
    }
  }
}

void _makeMarkerAbsolute(Map marker) {
  if (marker['anchor']['kind'] == 'absolute' &&
      marker['anchor']['clipId'] == null) {
    return;
  }
  marker['anchor'] = {'kind': 'absolute', 'clipId': null};
}

/// Rebind a clipLocal marker to a remnant that still uniquely covers it.
/// A marker that now spans the cut, or has no covering host, becomes
/// absolute at the same sequence time rather than being dropped.
void applyMarkersAfterSplit(Map d) {
  final markers = d['markers'];
  if (markers is! List || markers.isEmpty) {
    return;
  }
  for (final raw in markers) {
    final m = raw as Map;
    if (m['anchor']['kind'] != 'clipLocal') {
      continue;
    }
    final start = Q.fromJson(m['time']);
    final duration = Q.fromJson(m['duration']);
    final cover = coveringMarkerHostClipId(d, start, duration);
    if (cover == null) {
      _makeMarkerAbsolute(m);
      continue;
    }
    if (m['anchor']['clipId'] != cover) {
      m['anchor']['clipId'] = cover;
    }
  }
}

/// Leave-gap trim keeps sequence times. A clipLocal marker still covered by
/// the trimmed host stays clipLocal; one that now sits in the vacated gap
/// becomes absolute at the same time.
void applyMarkersAfterLeaveGapTrim(
  Map d, {
  required String hostId,
  required Q newStart,
  required Q newEnd,
}) {
  final markers = d['markers'];
  if (markers is! List || markers.isEmpty) {
    return;
  }
  for (final raw in markers) {
    final m = raw as Map;
    if (m['anchor']['kind'] != 'clipLocal') {
      continue;
    }
    if (m['anchor']['clipId'] != hostId) {
      continue;
    }
    final start = Q.fromJson(m['time']);
    final duration = Q.fromJson(m['duration']);
    if (start >= newStart && start + duration <= newEnd) {
      continue;
    }
    _makeMarkerAbsolute(m);
  }
}
