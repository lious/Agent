part of 'edit_algebra.dart';

final class SetClipGain extends EditOperation {
  const SetClipGain(this.clipId, this.value);
  final String clipId;
  final double value;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'setClipGain',
    'clipId': clipId,
    'gainDb': value,
  };
}

final class SetGainKeyframe extends EditOperation {
  const SetGainKeyframe(
    this.clipId,
    this.time,
    this.value, {
    this.interpolation = 'linear',
  });
  final String clipId;
  final Q time;
  final double value;
  final String interpolation;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'setGainKeyframe',
    'clipId': clipId,
    'localTime': time.toJson(),
    'gainDb': value,
    'interpolation': interpolation,
  };
}

final class RemoveGainKeyframe extends EditOperation {
  const RemoveGainKeyframe(this.clipId, this.time);
  final String clipId;
  final Q time;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'removeGainKeyframe',
    'clipId': clipId,
    'localTime': time.toJson(),
  };
}

bool _clipGainFieldsLocked(Map track, Map clip) =>
    track['locked'] == true || officialManualGainLocked(clip);

ProjectDocument _setClipGain(
  ProjectDocument before,
  SetClipGain op,
  VersionAllocator version,
  IdAllocator id,
) {
  if (!op.value.isFinite || op.value < -96 || op.value > 12) {
    throw const StudioException('AUDIO_PARAMETER_RANGE');
  }
  final d = before.toJson(), s = d['sequences'][0];
  for (final t in s['tracks']) {
    for (final c in t['items']) {
      if (c['id'] != op.clipId || c['source'] == null) continue;
      if (t['kind'] != 'audio') {
        throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
      }
      if (_clipGainFieldsLocked(t as Map, c as Map)) {
        throw const StudioException('FIELD_LOCKED');
      }
      final allIds = c['effectIds'] as List;
      final ids = admittedAudioClipEffects(
        d,
        c,
      ).where((e) => e['type'] == 'gain').map((e) => e['id']).toList();
      if (ids.isNotEmpty &&
          ((d['effects'] as List).singleWhere(
                    (e) => e['id'] == ids.single,
                  )['keyframes']
                  as List)
              .isNotEmpty) {
        throw const StudioException(
          'ANIMATED_GAIN_REQUIRES_EXPLICIT_KEYFRAME_EDIT',
        );
      }
      if (ids.isEmpty && op.value == 0) return before;
      final existing = ids.isEmpty
          ? null
          : (d['effects'] as List).singleWhere((e) => e['id'] == ids.single)
                as Map;
      if (existing != null &&
          existing['parameters']['gainDb'] == op.value &&
          existing['enabled'] == true) {
        return before;
      }
      final eid = existing?['id'] as String? ?? id();
      final e = {
        'id': eid,
        'version': version(eid),
        'owner': {'kind': 'clip', 'id': c['id']},
        'type': 'gain',
        'pluginVersion': '1.0.0',
        'enabled': true,
        'parameters': {'gainDb': op.value},
        'keyframes': <dynamic>[],
        'extensions': <String, dynamic>{},
      };
      d['effects'] = [
        for (final old in d['effects'])
          if (old['id'] != eid) old,
        e,
      ];
      c['effectIds'] = [
        for (final i in allIds)
          if (i != eid) i,
        eid,
      ];
      c['version'] = version(c['id']);
      s['version'] = version(s['id']);
      final result = ProjectDocument.fromJson(d);
      requireLocalEditingWritable(result);
      return result;
    }
  }
  throw const StudioException('CLIP_NOT_FOUND');
}

ProjectDocument _gainKeyframeEdit(
  ProjectDocument before,
  EditOperation operation,
  VersionAllocator version,
  IdAllocator id,
) {
  final adding = operation is SetGainKeyframe;
  final clipId = adding
      ? operation.clipId
      : (operation as RemoveGainKeyframe).clipId;
  final time = adding ? operation.time : (operation as RemoveGainKeyframe).time;
  final d = before.toJson();
  final sequence = d['sequences'][0];
  Map? selected;
  Map? track;
  for (final t in sequence['tracks']) {
    for (final c in t['items']) {
      if (c['id'] == clipId && c['source'] != null) {
        selected = c;
        track = t;
      }
    }
  }
  if (selected == null) throw const StudioException('CLIP_NOT_FOUND');
  if (track!['kind'] != 'audio') {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  if (_clipGainFieldsLocked(track, selected)) {
    throw const StudioException('FIELD_LOCKED');
  }
  if (time < Q.of(0) ||
      time > Q.fromJson(selected['timelineRange']['duration'])) {
    throw const StudioException('KEYFRAME_OUT_OF_RANGE');
  }
  if (quantizeAudioSample(time) != time) {
    throw const StudioException('KEYFRAME_NOT_ON_SAMPLE');
  }
  if (adding &&
      (!operation.value.isFinite ||
          operation.value < -96 ||
          operation.value > 12)) {
    throw const StudioException('AUDIO_PARAMETER_RANGE');
  }
  if (adding && !['hold', 'linear'].contains(operation.interpolation)) {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  final allIds = selected['effectIds'] as List;
  final ids = admittedAudioClipEffects(
    d,
    selected,
  ).where((e) => e['type'] == 'gain').map((e) => e['id']).toList();
  Map effect;
  if (ids.isEmpty) {
    if (!adding) throw const StudioException('KEYFRAME_NOT_FOUND');
    final eid = id();
    effect = {
      'id': eid,
      'version': '0',
      'owner': {'kind': 'clip', 'id': clipId},
      'type': 'gain',
      'pluginVersion': '1.0.0',
      'enabled': true,
      'parameters': {'gainDb': 0},
      'keyframes': <Map>[],
      'extensions': <String, dynamic>{},
    };
    (d['effects'] as List).add(effect);
    selected['effectIds'] = [...allIds, eid];
  } else {
    effect =
        (d['effects'] as List).singleWhere((e) => e['id'] == ids.single) as Map;
  }
  final points = List<Map>.from(effect['keyframes']);
  final index = points.indexWhere((k) => Q.fromJson(k['localTime']) == time);
  if (adding) {
    final op = operation;
    if (index >= 0 &&
        points[index]['value'] == op.value &&
        points[index]['interpolation'] == op.interpolation) {
      return before;
    }
    final key = {
      'id': index >= 0 ? points[index]['id'] : id(),
      'param': 'gainDb',
      'localTime': time.toJson(),
      'value': op.value,
      'interpolation': op.interpolation,
      'easing': null,
    };
    if (index >= 0) {
      points[index] = key;
    } else {
      points.add(key);
    }
  } else {
    if (index < 0) throw const StudioException('KEYFRAME_NOT_FOUND');
    points.removeAt(index);
  }
  points.sort(
    (a, b) => Q.fromJson(a['localTime']).compareTo(Q.fromJson(b['localTime'])),
  );
  effect['keyframes'] = points;
  effect['version'] = version(effect['id']);
  selected['version'] = version(clipId);
  sequence['version'] = version(sequence['id']);
  final result = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(result);
  return result;
}
