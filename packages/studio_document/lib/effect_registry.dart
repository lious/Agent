import 'package:studio_contracts/studio_contracts.dart';

import 'time.dart';

/// One actually consumed node, not the full EffectRegistry/keyframe contract.
/// Rec.709 opaque source -> linear premultiplied opacity over black. q16 is the
/// versioned CPU recipe quantization; unknown techniques remain unsupported.
int clipOpacityQ16(Map<String, dynamic> project, Map clip, [Q? localTime]) {
  final ids = clip['effectIds'] as List;
  if (ids.isEmpty) return 65536;
  if (ids.length != 1) {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  final matches = (project['effects'] as List).where(
    (e) => e['id'] == ids.single,
  );
  if (matches.length != 1) throw const StudioException('REF_NOT_FOUND');
  final e = matches.single;
  if (e['type'] != 'opacity' ||
      e['pluginVersion'] != '1.0.0' ||
      e['owner']['kind'] != 'clip' ||
      e['owner']['id'] != clip['id'] ||
      (e['extensions'] as Map).isNotEmpty) {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  final points = validatedOpacityPoints(e, clip);
  final rate = project['sequences'][0]['frameRate'];
  final fps = FrameRate(rate['n'], rate['d']);
  for (final k in points) {
    final t = Q.fromJson(k['localTime']);
    if (fps.quantize(t, Rounding.tiesToEven) != t) {
      throw const StudioException('KEYFRAME_NOT_ON_FRAME');
    }
  }
  final value = opacityValueAt(e, localTime ?? Q.of(0), points: points);
  return e['enabled'] == false ? 65536 : (value * 65536).round();
}

List<Map> validatedOpacityPoints(Map effect, Map clip) {
  final base = (effect['parameters']['value'] as num).toDouble();
  if (!base.isFinite || base < 0 || base > 1) {
    throw const StudioException('OPACITY_RANGE');
  }
  final points = List<Map>.from(effect['keyframes']);
  if (points.length > 256) {
    throw const StudioException('OPACITY_KEYFRAME_LIMIT');
  }
  final times = <Q>{};
  final duration = Q.fromJson(clip['timelineRange']['duration']);
  for (final k in points) {
    if (k['param'] != 'value' ||
        k['easing'] != null ||
        !['hold', 'linear'].contains(k['interpolation'])) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
    }
    final value = k['value'];
    if (value is! num || !value.isFinite || value < 0 || value > 1) {
      throw const StudioException('OPACITY_RANGE');
    }
    final t = Q.fromJson(k['localTime']);
    if (t < Q.of(0) || t > duration) {
      throw const StudioException('KEYFRAME_OUT_OF_RANGE');
    }
    if (!times.add(t)) throw const StudioException('DUPLICATE_KEYFRAME');
  }
  points.sort(
    (a, b) => Q.fromJson(a['localTime']).compareTo(Q.fromJson(b['localTime'])),
  );
  return points;
}

/// Clip-local project seconds, independent of source slip. Endpoints hold;
/// outgoing interpolation is half-open [a,b), exactly b selects b's value.
/// Rational alpha first, a single Float64 conversion; never accumulate per frame.
double opacityValueAt(Map effect, Q time, {List<Map>? points}) {
  final keys =
      points ??
      (List<Map>.from(effect['keyframes'])..sort(
        (a, b) =>
            Q.fromJson(a['localTime']).compareTo(Q.fromJson(b['localTime'])),
      ));
  if (keys.isEmpty) return (effect['parameters']['value'] as num).toDouble();
  if (time <= Q.fromJson(keys.first['localTime'])) {
    return (keys.first['value'] as num).toDouble();
  }
  var lo = 1, hi = keys.length;
  while (lo < hi) {
    final mid = (lo + hi) ~/ 2;
    if (time < Q.fromJson(keys[mid]['localTime'])) {
      hi = mid;
    } else {
      lo = mid + 1;
    }
  }
  if (lo == keys.length) return (keys.last['value'] as num).toDouble();
  final left = keys[lo - 1],
      right = keys[lo],
      a = Q.fromJson(left['localTime']),
      b = Q.fromJson(right['localTime']);
  final v = (left['value'] as num).toDouble();
  if (left['interpolation'] == 'hold') return v;
  final alpha = (time - a) / (b - a);
  return v +
      ((right['value'] as num).toDouble() - v) *
          (alpha.n.toDouble() / alpha.d.toDouble());
}

/// Crop/rebase a curve, preserving endpoint values and outgoing interpolation.
/// The duration endpoint is a non-rendered control point (owner domain is closed).
List<Map> cropOpacityPoints(
  Map effect,
  Q offset,
  Q duration,
  String Function() id,
) {
  final keys = List<Map>.from(effect['keyframes'])
    ..sort(
      (a, b) =>
          Q.fromJson(a['localTime']).compareTo(Q.fromJson(b['localTime'])),
    );
  String mode(Q t) {
    if (t < Q.fromJson(keys.first['localTime'])) return 'hold';
    for (var i = keys.length - 1; i >= 0; i--) {
      if (Q.fromJson(keys[i]['localTime']) <= t) {
        return i == keys.length - 1
            ? 'hold'
            : keys[i]['interpolation'] as String;
      }
    }
    return 'hold';
  }

  Map boundary(Q absolute, Q local) => {
    'id': id(),
    'param': 'value',
    'localTime': local.toJson(),
    'value': opacityValueAt(effect, absolute, points: keys),
    'interpolation': mode(absolute),
    'easing': null,
  };
  return [
    boundary(offset, Q.of(0)),
    for (final k in keys)
      if (Q.fromJson(k['localTime']) > offset &&
          Q.fromJson(k['localTime']) < offset + duration)
        {...k, 'localTime': (Q.fromJson(k['localTime']) - offset).toJson()},
    boundary(offset + duration, duration),
  ];
}

List<int> opacityScheduleQ16(
  Map<String, dynamic> project,
  Map clip,
  FrameRate fps,
) {
  final count = fps
      .frameIndex(
        Q.fromJson(clip['timelineRange']['duration']),
        Rounding.tiesToEven,
      )
      .toInt();
  if (count < 1 || count > 120000) {
    throw const StudioException('OPACITY_SCHEDULE_RANGE');
  }
  final effect = (project['effects'] as List).singleWhere(
    (e) => e['id'] == (clip['effectIds'] as List).single,
  ) as Map;
  final points = validatedOpacityPoints(effect, clip);
  return [
    for (var i = 0; i < count; i++)
      effect['enabled'] == false
          ? 65536
          : (opacityValueAt(
                      effect,
                      fps.frameTime(BigInt.from(i)),
                      points: points,
                    ) *
                    65536)
                .round(),
  ];
}
