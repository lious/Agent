part of 'edit_algebra.dart';

final class SetTransformKeyframe extends EditOperation {
  const SetTransformKeyframe(
    this.clipId,
    this.time,
    this.param,
    this.value, {
    this.interpolation = 'linear',
  });
  final String clipId;
  final Q time;
  final String param;
  final double value;
  final String interpolation;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'setTransformKeyframe',
    'clipId': clipId,
    'localTime': time.toJson(),
    'param': param,
    'value': value,
    'interpolation': interpolation,
  };
}

final class RemoveTransformKeyframe extends EditOperation {
  const RemoveTransformKeyframe(this.clipId, this.time, this.param);
  final String clipId;
  final Q time;
  final String param;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'removeTransformKeyframe',
    'clipId': clipId,
    'localTime': time.toJson(),
    'param': param,
  };
}

ProjectDocument _transformKeyframeEdit(
  ProjectDocument before,
  EditOperation operation,
  VersionAllocator version,
  IdAllocator id,
) {
  final adding = operation is SetTransformKeyframe;
  final clipId = adding
      ? operation.clipId
      : (operation as RemoveTransformKeyframe).clipId;
  final time = adding
      ? operation.time
      : (operation as RemoveTransformKeyframe).time;
  final param = adding
      ? operation.param
      : (operation as RemoveTransformKeyframe).param;
  if (!identityTransform2d.containsKey(param)) {
    throw const StudioException('TRANSFORM_ANIMATION_NOT_IMPLEMENTED');
  }
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
  if (track!['kind'] != 'video') {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  if (track['locked'] == true ||
      (selected['lockedFields'] as List).any(
        (v) =>
            v == '*' ||
            v == 'effects' ||
            v == 'effectIds' ||
            (v as String).startsWith('effects.') ||
            v.startsWith('effectIds.'),
      )) {
    throw const StudioException('FIELD_LOCKED');
  }
  if (time < Q.of(0) ||
      time > Q.fromJson(selected['timelineRange']['duration'])) {
    throw const StudioException('KEYFRAME_OUT_OF_RANGE');
  }
  final fps = FrameRate(sequence['frameRate']['n'], sequence['frameRate']['d']);
  if (fps.quantize(time, Rounding.tiesToEven) != time) {
    throw const StudioException('KEYFRAME_NOT_ON_FRAME');
  }
  if (adding && !['hold', 'linear'].contains(operation.interpolation)) {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  if (adding) {
    validateTransform2d({...identityTransform2d, param: operation.value});
  }
  final allIds = selected['effectIds'] as List;
  final ids = admittedClipEffects(
    d,
    selected,
  ).where((e) => e['type'] == 'transform2d').map((e) => e['id']).toList();
  Map effect;
  if (ids.isEmpty) {
    if (!adding) throw const StudioException('KEYFRAME_NOT_FOUND');
    final eid = id();
    effect = {
      'id': eid,
      'version': '0',
      'owner': {'kind': 'clip', 'id': clipId},
      'type': 'transform2d',
      'pluginVersion': '1.0.0',
      'enabled': true,
      'parameters': {...identityTransform2d, param: operation.value},
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
  final index = points.indexWhere(
    (k) => k['param'] == param && Q.fromJson(k['localTime']) == time,
  );
  if (adding) {
    final op = operation;
    if (index >= 0 &&
        points[index]['value'] == op.value &&
        points[index]['interpolation'] == op.interpolation) {
      return before;
    }
    final key = {
      'id': index >= 0 ? points[index]['id'] : id(),
      'param': param,
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
  if (points.length > 256) {
    throw const StudioException('TRANSFORM_KEYFRAME_LIMIT');
  }
  points.sort((a, b) {
    final c = Q.fromJson(a['localTime']).compareTo(Q.fromJson(b['localTime']));
    if (c != 0) return c;
    return (a['param'] as String).compareTo(b['param'] as String);
  });
  effect['keyframes'] = points;
  validatedTransformPoints(effect, selected);
  effect['version'] = version(effect['id']);
  selected['version'] = version(clipId);
  selected['effectIds'] = [for (final i in selected['effectIds']) i]
    ..sort(
      (a, b) => visualEffectOrder
          .indexOf(
            (d['effects'] as List).singleWhere((e) => e['id'] == a)['type'],
          )
          .compareTo(
            visualEffectOrder.indexOf(
              (d['effects'] as List).singleWhere((e) => e['id'] == b)['type'],
            ),
          ),
    );
  sequence['version'] = version(sequence['id']);
  final result = ProjectDocument.fromJson(d);
  requireLocalEditingWritable(result);
  return result;
}
