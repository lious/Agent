import 'package:studio_contracts/studio_contracts.dart';

import 'time.dart';

/// Plain captions. New cues with a unique covering host default to clipLocal and
/// follow that host on MoveClips. Existing or explicitly made-absolute cues stay
/// at authored timeline times. A cue with no unique covering host stays absolute.
/// Source anchors are explicit: [CaptionCue.anchoredToSource] stores a range in
/// the host's source window (offset from sourceRange.start) and keeps
/// timelineRange as the linear projection. Source cues reproject when the host
/// still covers that source window; an interval or rewrite that uncovers them
/// refuses the whole command (ANCHOR_OUT_OF_RANGE) instead of silently cropping.
/// Styles, words and speakers remain refused on admission. MP4 text burn-in
/// stays refused.
final class CaptionCue {
  CaptionCue(
    this.id,
    this.range,
    this.text, {
    this.language = 'und',
    Set<String> manualFields = const {},
    this.anchorKind = 'absolute',
    this.anchorClipId,
    this.anchorRange,
  }) : manualFields = Set.unmodifiable(manualFields) {
    requireId(id);
    if (range.start < Q.of(0) ||
        text.length > 4096 ||
        text.contains('\u0000') ||
        !RegExp(r'^[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*$').hasMatch(language) ||
        !manualFields.every(['text', 'timing', 'style', 'speaker'].contains)) {
      throw const StudioException('CAPTION_INVALID');
    }
    if (anchorKind == 'absolute') {
      if (anchorClipId != null || anchorRange != null) {
        throw const StudioException('ANCHOR_INVALID');
      }
    } else if (anchorKind == 'clipLocal' || anchorKind == 'source') {
      if (anchorClipId == null ||
          anchorRange == null ||
          anchorRange!.start < Q.of(0) ||
          anchorRange!.duration <= Q.of(0)) {
        throw const StudioException('ANCHOR_INVALID');
      }
      requireId(anchorClipId!);
    } else {
      throw const StudioException('CAPTION_RICH_EDIT_NOT_IMPLEMENTED');
    }
  }
  final String id, text, language, anchorKind;
  final String? anchorClipId;
  final TimeRange range;
  final TimeRange? anchorRange;
  final Set<String> manualFields;

  CaptionCue _copy({
    TimeRange? range,
    String? text,
    Set<String>? manualFields,
    String? anchorKind,
    String? anchorClipId,
    TimeRange? anchorRange,
    bool clearAnchor = false,
  }) => CaptionCue(
    id,
    range ?? this.range,
    text ?? this.text,
    language: language,
    manualFields: manualFields ?? this.manualFields,
    anchorKind: clearAnchor ? 'absolute' : (anchorKind ?? this.anchorKind),
    anchorClipId: clearAnchor ? null : (anchorClipId ?? this.anchorClipId),
    anchorRange: clearAnchor ? null : (anchorRange ?? this.anchorRange),
  );
  CaptionCue editText(String value, {bool automatic = false}) {
    if (automatic && manualFields.contains('text') && value != text) {
      throw const StudioException('MANUAL_FIELD_LOCKED');
    }
    return _copy(
      text: value,
      manualFields: {...manualFields, if (!automatic) 'text'},
    );
  }

  CaptionCue trim(TimeRange selection, {bool automatic = false}) {
    if (automatic && manualFields.contains('timing')) {
      throw const StudioException('MANUAL_FIELD_LOCKED');
    }
    final r = range.intersect(selection);
    if (r == null) throw const StudioException('CAPTION_EMPTY_TRIM');
    return _copy(
      range: r,
      anchorRange: _splitSourceRange(r.start, r.duration) ?? anchorRange,
      manualFields: {...manualFields, if (!automatic) 'timing'},
    );
  }

  List<CaptionCue> split(Q at, String rightId) {
    if (at <= range.start || at >= range.end) {
      throw const StudioException('CAPTION_SPLIT_RANGE');
    }
    final leftDur = at - range.start;
    final rightDur = range.end - at;
    return [
      _copy(
        range: TimeRange(range.start, leftDur),
        anchorRange: _splitSourceRange(range.start, leftDur) ?? anchorRange,
        manualFields: {...manualFields, 'timing'},
      ),
      CaptionCue(
        rightId,
        TimeRange(at, rightDur),
        text,
        language: language,
        manualFields: {...manualFields, 'timing'},
        anchorKind: anchorKind,
        anchorClipId: anchorClipId,
        anchorRange: _splitSourceRange(at, rightDur) ?? anchorRange,
      ),
    ];
  }

  /// Explicit source-coordinate mapping, not frame snapping. Existing manual text
  /// and timing ownership flags survive. Applying a map to a project is separate.
  CaptionCue mapSource({
    required Q timelineStart,
    required Q sourceStart,
    required Q rate,
  }) {
    if (rate <= Q.of(0)) throw const StudioException('TIME_MAP_MISMATCH');
    return CaptionCue(
      id,
      TimeRange(
        timelineStart + (range.start - sourceStart) / rate,
        range.duration / rate,
      ),
      text,
      language: language,
      manualFields: manualFields,
    );
  }

  Map<String, Object?> toProjectJson(String trackId, {String version = '1'}) =>
      {
        'id': id,
        'version': version,
        'trackId': trackId,
        'timelineRange': {
          'start': range.start.toJson(),
          'duration': range.duration.toJson(),
        },
        'text': text,
        'language': language,
        'styleEffectId': null,
        'anchor': anchorKind == 'absolute'
            ? {'kind': 'absolute', 'clipId': null, 'range': null}
            : {
                'kind': anchorKind,
                'clipId': anchorClipId,
                'range': {
                  'start': anchorRange!.start.toJson(),
                  'duration': anchorRange!.duration.toJson(),
                },
              },
        'manualFields': manualFields.toList()..sort(),
        'words': <Object>[],
        'speakerId': null,
      };
  CaptionCue anchoredToClip(String clipId, Q clipStart, Q clipDuration) {
    final local = TimeRange(range.start - clipStart, range.duration);
    if (local.start < Q.of(0) || local.start + local.duration > clipDuration) {
      throw const StudioException('ANCHOR_OUT_OF_RANGE');
    }
    return _copy(
      anchorKind: 'clipLocal',
      anchorClipId: clipId,
      anchorRange: local,
    );
  }

  /// Bind this cue to the unique covering host in the source window.
  /// [anchorRange] is the offset from the clip's sourceRange.start under a
  /// linear time map of [rate]. The timeline range is left as authored and
  /// must already be the projection of that source window.
  CaptionCue anchoredToSource({
    required String clipId,
    required Q clipStart,
    required Q clipDuration,
    required Q sourceDuration,
    required Q rate,
  }) {
    if (rate <= Q.of(0)) {
      throw const StudioException('TIME_MAP_MISMATCH');
    }
    if (range.start < clipStart || range.end > clipStart + clipDuration) {
      throw const StudioException('ANCHOR_OUT_OF_RANGE');
    }
    final local = TimeRange(
      (range.start - clipStart) * rate,
      range.duration * rate,
    );
    if (local.start < Q.of(0) ||
        local.start + local.duration > sourceDuration) {
      throw const StudioException('ANCHOR_OUT_OF_RANGE');
    }
    return _copy(
      anchorKind: 'source',
      anchorClipId: clipId,
      anchorRange: local,
    );
  }

  /// Slice this cue's source-window range to the timeline piece
  /// [start, start+duration).
  TimeRange? _splitSourceRange(Q start, Q duration) {
    if (anchorKind != 'source' ||
        anchorRange == null ||
        range.duration <= Q.of(0)) {
      return null;
    }
    final rate = anchorRange!.duration / range.duration;
    return TimeRange(
      anchorRange!.start + (start - range.start) * rate,
      duration * rate,
    );
  }

  CaptionCue makeAbsolute() => _copy(clearAnchor: true);

  factory CaptionCue.fromProjectJson(Map<String, dynamic> c) {
    if (c['styleEffectId'] != null ||
        c['speakerId'] != null ||
        (c['words'] as List).isNotEmpty) {
      throw const StudioException('CAPTION_RICH_EDIT_NOT_IMPLEMENTED');
    }
    final anchor = c['anchor'];
    final kind = anchor['kind'] as String;
    if (kind != 'absolute' && kind != 'clipLocal' && kind != 'source') {
      throw const StudioException('CAPTION_RICH_EDIT_NOT_IMPLEMENTED');
    }
    String? clipId;
    TimeRange? local;
    if (kind == 'clipLocal' || kind == 'source') {
      if (anchor['clipId'] == null || anchor['range'] == null) {
        throw const StudioException('ANCHOR_INVALID');
      }
      clipId = anchor['clipId'] as String;
      local = TimeRange(
        Q.fromJson(anchor['range']['start']),
        Q.fromJson(anchor['range']['duration']),
      );
    } else if (anchor['clipId'] != null || anchor['range'] != null) {
      throw const StudioException('ANCHOR_INVALID');
    }
    return CaptionCue(
      c['id'] as String,
      TimeRange(
        Q.fromJson(c['timelineRange']['start']),
        Q.fromJson(c['timelineRange']['duration']),
      ),
      c['text'] as String,
      language: c['language'] as String,
      manualFields: Set<String>.from(c['manualFields'] as List),
      anchorKind: kind,
      anchorClipId: clipId,
      anchorRange: local,
    );
  }
}

Map<String, Map> _mediaClipsById(Map d) {
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

Q _linearRate(Map clip) {
  final tm = clip['timeMap'];
  if (tm is! Map || tm['kind'] != 'linear') {
    throw const StudioException('TIME_MAP_MISMATCH');
  }
  final rate = Q.fromJson(tm['rate']);
  if (rate <= Q.of(0)) {
    throw const StudioException('TIME_MAP_MISMATCH');
  }
  return rate;
}

bool _sourceWindowCovers(Map clip, TimeRange local) {
  if (local.start < Q.of(0) || local.duration <= Q.of(0)) {
    return false;
  }
  final srcDur = Q.fromJson(clip['sourceRange']['duration']);
  return local.start + local.duration <= srcDur;
}

TimeRange projectSourceCaptionTimeline(Map clip, TimeRange sourceLocal) {
  if (!_sourceWindowCovers(clip, sourceLocal)) {
    throw const StudioException('ANCHOR_OUT_OF_RANGE');
  }
  final rate = _linearRate(clip);
  final tlStart = Q.fromJson(clip['timelineRange']['start']);
  return TimeRange(
    tlStart + sourceLocal.start / rate,
    sourceLocal.duration / rate,
  );
}

/// Snapshot of a source-anchored cue as absolute media source time
/// (`host.sourceRange.start + anchor.range.start`) so a later rewrite that
/// shifts the host's source window can restore the same picture.
String _clipStreamId(Map clip) {
  final source = clip['source'];
  if (source is! Map || source['streamId'] is! String) {
    throw const StudioException('REF_NOT_FOUND');
  }
  return source['streamId'] as String;
}

bool _absSourceCoveredBy(Map clip, SourceCaptionAbsolute snap) {
  if (_clipStreamId(clip) != snap.streamId) {
    return false;
  }
  final srcStart = Q.fromJson(clip['sourceRange']['start']);
  return _sourceWindowCovers(
    clip,
    TimeRange(snap.absStart - srcStart, snap.duration),
  );
}

/// The unique current media clip, if any, whose source window still holds
/// [snap]'s absolute source range on the same stream (including a split remnant
/// that inherited the original host's id only on one side).
Map? _uniqueCoveringSourceCaptionHost(
  Map<String, Map> clips,
  SourceCaptionAbsolute snap,
) {
  Map? found;
  for (final clip in clips.values) {
    if (!_absSourceCoveredBy(clip, snap)) {
      continue;
    }
    if (found != null) {
      return null;
    }
    found = clip;
  }
  return found;
}

final class SourceCaptionAbsolute {
  const SourceCaptionAbsolute({
    required this.clipId,
    required this.streamId,
    required this.absStart,
    required this.duration,
  });
  final String clipId;
  final String streamId;
  final Q absStart;
  final Q duration;
}

Map<String, SourceCaptionAbsolute> snapshotSourceCaptionAbsolutes(Map d) {
  final clips = _mediaClipsById(d);
  final out = <String, SourceCaptionAbsolute>{};
  for (final cue in d['captions'] as List) {
    final anchor = cue['anchor'];
    if (anchor['kind'] != 'source') {
      continue;
    }
    final clipId = anchor['clipId'] as String;
    final clip = clips[clipId];
    if (clip == null) {
      throw const StudioException('REF_NOT_FOUND');
    }
    final srcStart = Q.fromJson(clip['sourceRange']['start']);
    final local = TimeRange(
      Q.fromJson(anchor['range']['start']),
      Q.fromJson(anchor['range']['duration']),
    );
    out[cue['id'] as String] = SourceCaptionAbsolute(
      clipId: clipId,
      streamId: _clipStreamId(clip),
      absStart: srcStart + local.start,
      duration: local.duration,
    );
  }
  return out;
}

/// Restore source-local ranges from [snaps] after a media rewrite, then
/// reproject timelineRange. A host that no longer covers the absolute source
/// window refuses the whole command when [refuseUncovered] is true (the default
/// for this slice: no silent crop or drop of source-anchored cues).
void applySourceCaptionAbsolutes(
  Map d,
  Map<String, SourceCaptionAbsolute> snaps, {
  bool refuseUncovered = true,
  String Function(String id)? nextVersion,
}) {
  if (snaps.isEmpty) {
    return;
  }
  final clips = _mediaClipsById(d);
  for (final cue in d['captions'] as List) {
    final snap = snaps[cue['id']];
    if (snap == null) {
      continue;
    }
    final anchor = cue['anchor'];
    if (anchor['kind'] != 'source') {
      continue;
    }
    var clip = clips[snap.clipId] ?? clips[anchor['clipId']];
    if (clip == null || !_absSourceCoveredBy(clip, snap)) {
      clip = _uniqueCoveringSourceCaptionHost(clips, snap);
    }
    if (clip == null) {
      if (refuseUncovered) {
        throw const StudioException('ANCHOR_OUT_OF_RANGE');
      }
      continue;
    }
    final srcStart = Q.fromJson(clip['sourceRange']['start']);
    final local = TimeRange(snap.absStart - srcStart, snap.duration);
    final projected = projectSourceCaptionTimeline(clip, local);
    final hostId = clip['id'] as String;
    final prevStart = Q.fromJson(cue['timelineRange']['start']);
    final prevDur = Q.fromJson(cue['timelineRange']['duration']);
    final prevLocalStart = Q.fromJson(anchor['range']['start']);
    final prevLocalDur = Q.fromJson(anchor['range']['duration']);
    final prevHost = anchor['clipId'];
    final changed =
        prevHost != hostId ||
        prevStart != projected.start ||
        prevDur != projected.duration ||
        prevLocalStart != local.start ||
        prevLocalDur != local.duration;
    if (anchor['clipId'] != hostId) {
      anchor['clipId'] = hostId;
    }
    anchor['range'] = {
      'start': local.start.toJson(),
      'duration': local.duration.toJson(),
    };
    cue['timelineRange'] = {
      'start': projected.start.toJson(),
      'duration': projected.duration.toJson(),
    };
    if (changed && nextVersion != null) {
      cue['version'] = nextVersion(cue['id'] as String);
    }
  }
}

/// Rewrite clipLocal cue timelineRange from the host clip's current start, and
/// reproject source-anchored cues from the host linear time map when the source
/// window still covers them. Absolute cues are left unchanged. Missing hosts refuse.
void followClipLocalCaptions(Map d, {String Function(String id)? nextVersion}) {
  final clips = _mediaClipsById(d);
  for (final cue in d['captions'] as List) {
    final anchor = cue['anchor'];
    final kind = anchor['kind'] as String;
    if (kind == 'absolute') {
      continue;
    }
    if (kind != 'clipLocal' && kind != 'source') {
      throw const StudioException('CAPTION_RICH_EDIT_NOT_IMPLEMENTED');
    }
    final clip = clips[anchor['clipId']];
    if (clip == null || anchor['range'] == null) {
      throw const StudioException('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED');
    }
    if (kind == 'source') {
      final local = TimeRange(
        Q.fromJson(anchor['range']['start']),
        Q.fromJson(anchor['range']['duration']),
      );
      final next = projectSourceCaptionTimeline(clip, local);
      final prevStart = Q.fromJson(cue['timelineRange']['start']);
      final prevDur = Q.fromJson(cue['timelineRange']['duration']);
      if (prevStart == next.start && prevDur == next.duration) {
        continue;
      }
      cue['timelineRange'] = {
        'start': next.start.toJson(),
        'duration': next.duration.toJson(),
      };
      if (nextVersion != null) {
        cue['version'] = nextVersion(cue['id'] as String);
      }
      continue;
    }
    final localStart = Q.fromJson(anchor['range']['start']);
    final localDur = Q.fromJson(anchor['range']['duration']);
    final clipStart = Q.fromJson(clip['timelineRange']['start']);
    final clipDur = Q.fromJson(clip['timelineRange']['duration']);
    if (localStart < Q.of(0) || localStart + localDur > clipDur) {
      throw const StudioException('ANCHOR_OUT_OF_RANGE');
    }
    final nextStart = clipStart + localStart;
    final prevStart = Q.fromJson(cue['timelineRange']['start']);
    final prevDur = Q.fromJson(cue['timelineRange']['duration']);
    if (prevStart == nextStart && prevDur == localDur) {
      continue;
    }
    cue['timelineRange'] = {
      'start': nextStart.toJson(),
      'duration': localDur.toJson(),
    };
    if (nextVersion != null) {
      cue['version'] = nextVersion(cue['id'] as String);
    }
  }
}

/// After a cue timing edit, recompute clipLocal anchor.range from timelineRange.
void syncClipLocalCaptionRanges(Map d) {
  final clips = _mediaClipsById(d);
  for (final cue in d['captions'] as List) {
    final anchor = cue['anchor'];
    final kind = anchor['kind'] as String;
    if (kind == 'absolute') {
      continue;
    }
    if (kind != 'clipLocal' && kind != 'source') {
      throw const StudioException('CAPTION_RICH_EDIT_NOT_IMPLEMENTED');
    }
    final clip = clips[anchor['clipId']];
    if (clip == null) {
      throw const StudioException('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED');
    }
    final clipStart = Q.fromJson(clip['timelineRange']['start']);
    final clipDur = Q.fromJson(clip['timelineRange']['duration']);
    final start = Q.fromJson(cue['timelineRange']['start']);
    final duration = Q.fromJson(cue['timelineRange']['duration']);
    if (start < clipStart || start + duration > clipStart + clipDur) {
      throw const StudioException('ANCHOR_OUT_OF_RANGE');
    }
    if (kind == 'source') {
      final rate = _linearRate(clip);
      final local = TimeRange((start - clipStart) * rate, duration * rate);
      if (!_sourceWindowCovers(clip, local)) {
        throw const StudioException('ANCHOR_OUT_OF_RANGE');
      }
      anchor['range'] = {
        'start': local.start.toJson(),
        'duration': local.duration.toJson(),
      };
      continue;
    }
    final localStart = start - clipStart;
    if (localStart < Q.of(0) || localStart + duration > clipDur) {
      throw const StudioException('ANCHOR_OUT_OF_RANGE');
    }
    anchor['range'] = {
      'start': localStart.toJson(),
      'duration': duration.toJson(),
    };
  }
}

String? coveringCaptionHostClipId(Map d, TimeRange cue) {
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
      if (cue.start < start || cue.end > end) {
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

/// Default a newly authored absolute cue to clipLocal when a unique host fully
/// covers it. Existing absolute IDs are not converted; spanning or gapped cues
/// stay absolute.
CaptionCue defaultClipLocalIfCovered(Map d, CaptionCue cue) {
  if (cue.anchorKind != 'absolute') {
    return cue;
  }
  final id = coveringCaptionHostClipId(d, cue.range);
  if (id == null) {
    return cue;
  }
  final host = _mediaClipsById(d)[id]!;
  return cue.anchoredToClip(
    id,
    Q.fromJson(host['timelineRange']['start']),
    Q.fromJson(host['timelineRange']['duration']),
  );
}

/// Crop, split, and shift admitted cues across one interval.
///
/// A close removes `[at, at+length)` then shifts later absolute cues left by
/// [length]. An open splits at [at] and shifts the right side and later
/// absolute cues right by [length]. Text is never rewritten. A right remnant
/// gets a new id. A cue wholly inside a closed interval is dropped as a
/// crop-to-empty, not as a silent loss, and comes back on undo. A source-anchored cue whose host still covers
/// its source window is reprojected; one that would be uncovered or cropped
/// refuses (ANCHOR_OUT_OF_RANGE).
///
/// clipLocal cues follow their current host when the host still fully covers
/// the local range, so an insert-move of an unsplit host does not split its
/// cues at the destination hole. When the host is gone or no longer covers
/// the cue, the same interval transform is applied in timeline space and each
/// remnant is rebound to a covering host. A remnant with no covering host
/// refuses the whole command. This path must not also call
/// [followClipLocalCaptions] on the same interval, which would double-shift
/// later clipLocal cues that already followed here; a later MoveClips
/// placement may still call follow once hosts move again.
void applyCaptionIntervalEdit(
  Map d, {
  required Q at,
  required Q length,
  required bool opening,
  required String Function() newId,
  String Function(String id)? nextVersion,
}) {
  if (length <= Q.of(0)) {
    throw const StudioException('INVALID_TIME_RANGE');
  }
  final captions = d['captions'];
  if (captions is! List || captions.isEmpty) {
    return;
  }
  final lockedTracks = <String>{};
  for (final t in (d['sequences'] as List).first['tracks'] as List) {
    if (t['kind'] == 'caption' && t['locked'] == true) {
      lockedTracks.add(t['id'] as String);
    }
  }
  final clips = _mediaClipsById(d);
  final next = <Map<String, dynamic>>[];
  for (final raw in captions) {
    final cue = _cloneCaptionMap(raw as Map);
    final kind = cue['anchor']['kind'] as String;
    if (kind != 'absolute' && kind != 'clipLocal' && kind != 'source') {
      throw const StudioException('CAPTION_RICH_EDIT_NOT_IMPLEMENTED');
    }
    final start = Q.fromJson(cue['timelineRange']['start']);
    final duration = Q.fromJson(cue['timelineRange']['duration']);
    if (kind == 'source') {
      final host = clips[cue['anchor']['clipId']];
      if (host == null) {
        throw const StudioException('REF_NOT_FOUND');
      }
      final local = TimeRange(
        Q.fromJson(cue['anchor']['range']['start']),
        Q.fromJson(cue['anchor']['range']['duration']),
      );
      final followed = projectSourceCaptionTimeline(host, local);
      _emitCaptionPieces(
        cue,
        [(start: followed.start, duration: followed.duration)],
        originalStart: start,
        originalDuration: duration,
        lockedTracks: lockedTracks,
        next: next,
        newId: newId,
        nextVersion: nextVersion,
      );
      continue;
    }
    if (kind == 'clipLocal' &&
        _clipLocalStillCoveredByHost(clips, cue, start, duration)) {
      final followed = _clipLocalFollowedRange(clips, cue);
      _emitCaptionPieces(
        cue,
        [(start: followed.start, duration: followed.duration)],
        originalStart: start,
        originalDuration: duration,
        lockedTracks: lockedTracks,
        next: next,
        newId: newId,
        nextVersion: nextVersion,
      );
      continue;
    }
    _emitCaptionPieces(
      cue,
      _captionIntervalPieces(
        start: start,
        duration: duration,
        at: at,
        length: length,
        opening: opening,
      ),
      originalStart: start,
      originalDuration: duration,
      lockedTracks: lockedTracks,
      next: next,
      newId: newId,
      nextVersion: nextVersion,
    );
  }
  d['captions'] = next;
  _rebindClipLocalCaptionsAfterInterval(d, nextVersion: nextVersion);
}

bool _clipLocalStillCoveredByHost(
  Map<String, Map> clips,
  Map cue,
  Q timelineStart,
  Q timelineDuration,
) {
  final anchor = cue['anchor'] as Map;
  final host = clips[anchor['clipId']];
  if (host == null || anchor['range'] is! Map) {
    return false;
  }
  final hostStart = Q.fromJson(host['timelineRange']['start']);
  final hostEnd = hostStart + Q.fromJson(host['timelineRange']['duration']);
  final localStart = Q.fromJson(anchor['range']['start']);
  final localDur = Q.fromJson(anchor['range']['duration']);
  final desiredStart = hostStart + localStart;
  final desiredEnd = desiredStart + localDur;
  if (desiredStart < hostStart || desiredEnd > hostEnd) {
    return false;
  }
  return true;
}

TimeRange _clipLocalFollowedRange(Map<String, Map> clips, Map cue) {
  final anchor = cue['anchor'] as Map;
  final host = clips[anchor['clipId']]!;
  final hostStart = Q.fromJson(host['timelineRange']['start']);
  final localStart = Q.fromJson(anchor['range']['start']);
  final localDur = Q.fromJson(anchor['range']['duration']);
  return TimeRange(hostStart + localStart, localDur);
}

List<({Q start, Q duration})> _captionIntervalPieces({
  required Q start,
  required Q duration,
  required Q at,
  required Q length,
  required bool opening,
}) {
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

void _emitCaptionPieces(
  Map<String, dynamic> cue,
  List<({Q start, Q duration})> pieces, {
  required Q originalStart,
  required Q originalDuration,
  required Set<String> lockedTracks,
  required List<Map<String, dynamic>> next,
  required String Function() newId,
  String Function(String id)? nextVersion,
}) {
  final changed =
      pieces.length != 1 ||
      pieces.isEmpty ||
      pieces.first.start != originalStart ||
      pieces.first.duration != originalDuration;
  if (changed && lockedTracks.contains(cue['trackId'])) {
    throw const StudioException('FIELD_LOCKED');
  }
  if (pieces.isEmpty) {
    return;
  }
  _writeCaptionTimeline(
    cue,
    pieces.first.start,
    pieces.first.duration,
    nextVersion,
  );
  next.add(cue);
  for (final piece in pieces.skip(1)) {
    final right = _cloneCaptionMap(cue);
    right['id'] = newId();
    right['version'] = nextVersion != null
        ? nextVersion(right['id'] as String)
        : '1';
    _writeCaptionTimeline(right, piece.start, piece.duration, null);
    next.add(right);
  }
}

void _writeCaptionTimeline(
  Map cue,
  Q start,
  Q duration,
  String Function(String id)? nextVersion,
) {
  final prevStart = Q.fromJson(cue['timelineRange']['start']);
  final prevDur = Q.fromJson(cue['timelineRange']['duration']);
  if (prevStart == start && prevDur == duration) {
    return;
  }
  cue['timelineRange'] = {
    'start': start.toJson(),
    'duration': duration.toJson(),
  };
  if (nextVersion != null) {
    cue['version'] = nextVersion(cue['id'] as String);
  }
}

Map<String, dynamic> _cloneCaptionMap(Map raw) {
  final anchor = Map<String, dynamic>.from(raw['anchor'] as Map);
  if (anchor['range'] is Map) {
    anchor['range'] = Map<String, dynamic>.from(anchor['range'] as Map);
  }
  return <String, dynamic>{
    ...Map<String, dynamic>.from(raw),
    'timelineRange': Map<String, dynamic>.from(raw['timelineRange'] as Map),
    'anchor': anchor,
    'manualFields': List<String>.from(
      (raw['manualFields'] as List?) ?? const [],
    ),
    if (raw['words'] is List) 'words': List<dynamic>.from(raw['words'] as List),
  };
}

/// Rebind each clipLocal cue to a host that fully covers its (already
/// transformed) timeline range, then sync local ranges. Missing coverage
/// refuses the whole command; remnants are never silently dropped or
/// converted to absolute.
void _rebindClipLocalCaptionsAfterInterval(
  Map d, {
  String Function(String id)? nextVersion,
}) {
  final clips = _mediaClipsById(d);
  for (final cue in d['captions'] as List) {
    final anchor = cue['anchor'];
    if (anchor['kind'] != 'clipLocal') {
      continue;
    }
    final range = TimeRange(
      Q.fromJson(cue['timelineRange']['start']),
      Q.fromJson(cue['timelineRange']['duration']),
    );
    final preferred = anchor['clipId'] as String;
    final current = clips[preferred];
    var hostId = preferred;
    if (current == null ||
        range.start < Q.fromJson(current['timelineRange']['start']) ||
        range.end >
            Q.fromJson(current['timelineRange']['start']) +
                Q.fromJson(current['timelineRange']['duration'])) {
      final cover = coveringCaptionHostClipId(d, range);
      if (cover == null) {
        throw const StudioException('ANCHOR_OUT_OF_RANGE');
      }
      hostId = cover;
    }
    if (hostId != preferred) {
      anchor['clipId'] = hostId;
      if (nextVersion != null) {
        cue['version'] = nextVersion(cue['id'] as String);
      }
    }
  }
  syncClipLocalCaptionRanges(d);
}

final class CaptionStore {
  CaptionStore(List<CaptionCue> values)
    : cues = List.unmodifiable(
        values.toList()..sort((a, b) {
          final n = a.range.start.compareTo(b.range.start);
          return n == 0 ? a.id.compareTo(b.id) : n;
        }),
      ) {
    if (values.length > 10000) {
      throw const StudioException('CAPTION_RESOURCE_LIMIT');
    }
    if (values.map((c) => c.id).toSet().length != values.length) {
      throw const StudioException('DUPLICATE_ID');
    }
    for (var i = 1; i < cues.length; i++) {
      if (cues[i - 1].range.overlaps(cues[i].range)) {
        throw const StudioException('CAPTION_OVERLAP');
      }
    }
  }
  final List<CaptionCue> cues;
}

enum CaptionFormat { srt, vtt, ass }

final class CaptionImport {
  CaptionImport(List<CaptionCue> values, Set<String> warnings)
    : captions = CaptionStore(values),
      warnings = Set.unmodifiable(warnings);
  final CaptionStore captions;
  final Set<String> warnings;
}

final class CaptionFormats {
  static Q _time(String raw, {bool ass = false}) {
    final match = RegExp(
      ass
          ? r'^(\d{1,6}):([0-5]\d):([0-5]\d)\.(\d{2})$'
          : r'^(?:(\d{1,6}):)?([0-5]\d):([0-5]\d)[.,](\d{3})$',
    ).firstMatch(raw);
    if (match == null) throw const StudioException('SUBTITLE_TIMECODE');
    final scale = ass ? 100 : 1000,
        h = int.parse(match[1] ?? '0'),
        m = int.parse(match[2]!),
        s = int.parse(match[3]!),
        f = int.parse(match[4]!);
    return Q.of((h * 3600 + m * 60 + s) * scale + f, scale);
  }

  static String _text(String raw, Set<String> warnings) {
    if (RegExp(r'<[^>]*>').hasMatch(raw)) {
      warnings.add('SUBTITLE_MARKUP_DROPPED');
    }
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }

  static CaptionImport decode(String input, CaptionFormat format) {
    if (input.length > 4 * 1024 * 1024) {
      throw const StudioException('SUBTITLE_RESOURCE_LIMIT');
    }
    input = input
        .replaceFirst(RegExp('^\ufeff'), '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final cues = <CaptionCue>[], warnings = <String>{};
    void add(Q start, Q end, String text) {
      if (cues.length >= 10000) {
        throw const StudioException('CAPTION_RESOURCE_LIMIT');
      }
      cues.add(
        CaptionCue(
          'cue-${cues.length + 1}',
          TimeRange(start, end - start),
          text,
        ),
      );
    }

    if (format == CaptionFormat.ass) {
      warnings.add('ASS_STYLE_FONT_NOT_RENDERED');
      var events = false, formatSeen = false;
      for (final line in input.split('\n')) {
        if (line.startsWith('[')) {
          events = line.trim() == '[Events]';
          continue;
        }
        if (!events || line.trim().isEmpty || line.startsWith(';')) continue;
        if (line.startsWith('Format:')) {
          if (line.substring(7).replaceAll(' ', '') !=
              'Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text') {
            throw const StudioException('ASS_FORMAT_UNSUPPORTED');
          }
          formatSeen = true;
          continue;
        }
        if (!line.startsWith('Dialogue:')) {
          warnings.add('ASS_EVENT_DROPPED');
          continue;
        }
        if (!formatSeen) throw const StudioException('ASS_FORMAT_REQUIRED');
        final fields = line.substring(9).trimLeft().split(',');
        if (fields.length < 10) {
          throw const StudioException('ASS_DIALOGUE_INVALID');
        }
        var text = fields.sublist(9).join(',');
        if (RegExp(r'\{[^}]*\}').hasMatch(text)) {
          warnings.add('ASS_OVERRIDE_DROPPED');
        }
        text = text
            .replaceAll(RegExp(r'\{[^}]*\}'), '')
            .replaceAll(r'\N', '\n')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\h', '\u00a0');
        add(
          _time(fields[1].trim(), ass: true),
          _time(fields[2].trim(), ass: true),
          text,
        );
      }
      return CaptionImport(cues, warnings);
    }
    if (format == CaptionFormat.vtt) {
      if (!RegExp(r'^WEBVTT(?:[^\n]*)\n(?:\n|$)').hasMatch('$input\n')) {
        throw const StudioException('WEBVTT_HEADER_REQUIRED');
      }
      final first = input.indexOf('\n');
      input = first < 0 ? '' : input.substring(first + 1);
    }
    for (final block in input.split(RegExp(r'\n[ \t]*\n+'))) {
      final lines = block
          .replaceFirst(RegExp(r'^\n+'), '')
          .replaceFirst(RegExp(r'\n+$'), '')
          .split('\n');
      if (lines.every((s) => s.isEmpty)) continue;
      if (format == CaptionFormat.vtt &&
          (lines[0].startsWith('NOTE') ||
              lines[0] == 'STYLE' ||
              lines[0] == 'REGION')) {
        warnings.add('WEBVTT_METADATA_DROPPED');
        continue;
      }
      final timeLine = lines[0].contains('-->') ? 0 : 1;
      if (lines.length <= timeLine) {
        throw const StudioException('SUBTITLE_CUE_INVALID');
      }
      final m = RegExp(r'^(\S+)\s+-->\s+(\S+)(.*)$')
          .firstMatch(lines[timeLine]);
      if (m == null) throw const StudioException('SUBTITLE_TIMECODE');
      if (m[3]!.trim().isNotEmpty) warnings.add('WEBVTT_CUE_SETTINGS_DROPPED');
      add(
        _time(m[1]!),
        _time(m[2]!),
        _text(lines.skip(timeLine + 1).join('\n'), warnings),
      );
    }
    return CaptionImport(cues, warnings);
  }

  /// ASS export requires registered font/style layout and is intentionally absent;
  /// parsing the static text subset does not claim deterministic ASS rendering.
  static String encode(CaptionStore store, CaptionFormat format) {
    if (format == CaptionFormat.ass) {
      throw const StudioException('ASS_EXPORT_FONT_POLICY_REQUIRED');
    }
    String clock(BigInt ms) {
      if (ms > BigInt.from(3599999999999)) {
        throw const StudioException('SUBTITLE_TIMECODE_RANGE');
      }
      final t = ms.toInt(),
          h = t ~/ 3600000,
          m = t ~/ 60000 % 60,
          s = t ~/ 1000 % 60,
          f = t % 1000;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}${format == CaptionFormat.srt ? ',' : '.'}${f.toString().padLeft(3, '0')}';
    }

    final out = StringBuffer(format == CaptionFormat.vtt ? 'WEBVTT\n\n' : '');
    var index = 0;
    for (final c in store.cues) {
      final start = sampleIndex(c.range.start, 1000, Rounding.tiesToEven),
          end = sampleIndex(c.range.end, 1000, Rounding.tiesToEven);
      if (end <= start) {
        throw const StudioException('SUBTITLE_TIME_QUANTIZATION');
      }
      if (c.text.startsWith('\n') ||
          c.text.endsWith('\n') ||
          c.text.contains('\n\n')) {
        throw const StudioException('SUBTITLE_BLANK_LINE_UNREPRESENTABLE');
      }
      final text = c.text
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');
      out.writeln('${++index}\n${clock(start)} --> ${clock(end)}\n$text\n');
    }
    return out.toString();
  }
}

Set<String> _lockedCaptionTrackIds(Map d) => {
  for (final t in (d['sequences'] as List).first['tracks'] as List)
    if (t['kind'] == 'caption' && t['locked'] == true) t['id'] as String,
};

void _makeCaptionAbsolute(Map cue, String Function(String id)? nextVersion) {
  final anchor = cue['anchor'] as Map;
  if (anchor['kind'] == 'absolute' &&
      anchor['clipId'] == null &&
      anchor['range'] == null) {
    return;
  }
  cue['anchor'] = {'kind': 'absolute', 'clipId': null, 'range': null};
  if (nextVersion != null) {
    cue['version'] = nextVersion(cue['id'] as String);
  }
}

void _bindCaptionToHost(
  Map d,
  Map cue,
  String hostId, {
  String Function(String id)? nextVersion,
}) {
  final anchor = cue['anchor'] as Map;
  final clips = _mediaClipsById(d);
  final host = clips[hostId]!;
  final hostStart = Q.fromJson(host['timelineRange']['start']);
  final hostDur = Q.fromJson(host['timelineRange']['duration']);
  final start = Q.fromJson(cue['timelineRange']['start']);
  final duration = Q.fromJson(cue['timelineRange']['duration']);
  if (start < hostStart || start + duration > hostStart + hostDur) {
    throw const StudioException('ANCHOR_OUT_OF_RANGE');
  }
  final changed = anchor['kind'] != 'clipLocal' || anchor['clipId'] != hostId;
  anchor['kind'] = 'clipLocal';
  anchor['clipId'] = hostId;
  anchor['range'] = {
    'start': (start - hostStart).toJson(),
    'duration': duration.toJson(),
  };
  if (changed && nextVersion != null) {
    cue['version'] = nextVersion(cue['id'] as String);
  }
}

/// After a [SplitClip], keep every cue's text and authored timeline range.
/// A clipLocal cue that is still uniquely covered is rebound to that remnant.
/// A cue that now spans the cut becomes absolute rather than splitting text.
/// Source-anchored cues must be restored with [applySourceCaptionAbsolutes]
/// first; a cue that would be uncovered or cropped still refuses.
void applyCaptionsAfterSplit(Map d, {String Function(String id)? nextVersion}) {
  final captions = d['captions'];
  if (captions is! List || captions.isEmpty) {
    return;
  }
  final locked = _lockedCaptionTrackIds(d);
  for (final raw in captions) {
    final cue = raw as Map;
    final kind = cue['anchor']['kind'] as String;
    if (kind == 'absolute' || kind == 'source') {
      continue;
    }
    if (kind != 'clipLocal') {
      throw const StudioException('CAPTION_RICH_EDIT_NOT_IMPLEMENTED');
    }
    final range = TimeRange(
      Q.fromJson(cue['timelineRange']['start']),
      Q.fromJson(cue['timelineRange']['duration']),
    );
    final cover = coveringCaptionHostClipId(d, range);
    if (cover == null) {
      if (locked.contains(cue['trackId'])) {
        throw const StudioException('FIELD_LOCKED');
      }
      _makeCaptionAbsolute(cue, nextVersion);
      continue;
    }
    _bindCaptionToHost(d, cue, cover, nextVersion: nextVersion);
  }
}

Q _qMax(Q a, Q b) => a > b ? a : b;
Q _qMin(Q a, Q b) => a < b ? a : b;

({Q start, Q duration})? _intersectRange(Q start, Q duration, Q from, Q to) {
  final begin = _qMax(start, from);
  final end = _qMin(start + duration, to);
  if (end <= begin) {
    return null;
  }
  return (start: begin, duration: end - begin);
}

/// After a leave-gap [TrimClip], later content is not shifted. Cues keep their
/// authored times when they still sit on the host; a portion that now falls
/// in the vacated gap becomes an absolute remnant (new id, same text). Source
/// cues are not cropped here — restore them with [applySourceCaptionAbsolutes].
void applyCaptionsAfterLeaveGapTrim(
  Map d, {
  required String hostId,
  required Q oldStart,
  required Q oldEnd,
  required Q newStart,
  required Q newEnd,
  required String Function() newId,
  String Function(String id)? nextVersion,
}) {
  final captions = d['captions'];
  if (captions is! List || captions.isEmpty) {
    return;
  }
  if (newEnd <= newStart) {
    throw const StudioException('INVALID_RANGE');
  }
  final locked = _lockedCaptionTrackIds(d);
  final vacated = <({Q start, Q end})>[];
  if (newStart > oldStart) {
    vacated.add((start: oldStart, end: newStart));
  }
  if (newEnd < oldEnd) {
    vacated.add((start: newEnd, end: oldEnd));
  }
  final next = <Map<String, dynamic>>[];
  for (final raw in captions) {
    final cue = _cloneCaptionMap(raw as Map);
    final kind = cue['anchor']['kind'] as String;
    if (kind == 'absolute' || kind == 'source') {
      next.add(cue);
      continue;
    }
    if (kind != 'clipLocal') {
      throw const StudioException('CAPTION_RICH_EDIT_NOT_IMPLEMENTED');
    }
    if (cue['anchor']['clipId'] != hostId) {
      next.add(cue);
      continue;
    }
    final start = Q.fromJson(cue['timelineRange']['start']);
    final duration = Q.fromJson(cue['timelineRange']['duration']);
    final hostPart = _intersectRange(start, duration, newStart, newEnd);
    final gapParts = [
      for (final g in vacated)
        ?_intersectRange(start, duration, g.start, g.end),
    ];
    final unchanged =
        hostPart != null &&
        gapParts.isEmpty &&
        hostPart.start == start &&
        hostPart.duration == duration;
    if (unchanged) {
      _bindCaptionToHost(d, cue, hostId, nextVersion: nextVersion);
      next.add(cue);
      continue;
    }
    if (locked.contains(cue['trackId'])) {
      throw const StudioException('FIELD_LOCKED');
    }
    if (hostPart != null) {
      _writeCaptionTimeline(
        cue,
        hostPart.start,
        hostPart.duration,
        nextVersion,
      );
      _bindCaptionToHost(d, cue, hostId, nextVersion: nextVersion);
      next.add(cue);
    }
    for (final part in gapParts) {
      final remnant = hostPart == null && identical(part, gapParts.first)
          ? cue
          : _cloneCaptionMap(cue);
      if (!identical(remnant, cue) || hostPart != null) {
        remnant['id'] = newId();
        remnant['version'] = nextVersion != null
            ? nextVersion(remnant['id'] as String)
            : '1';
      }
      _writeCaptionTimeline(remnant, part.start, part.duration, null);
      _makeCaptionAbsolute(remnant, null);
      next.add(remnant);
    }
  }
  d['captions'] = next;
}
