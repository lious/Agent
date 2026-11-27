import 'package:studio_contracts/studio_contracts.dart';

import 'audio_bus.dart';
import 'time.dart';

const officialAudioSampleRate = 48000;

Q quantizeAudioSample(Q time, [Rounding mode = Rounding.tiesToEven]) => Q(
  sampleIndex(time, officialAudioSampleRate, mode),
  BigInt.from(officialAudioSampleRate),
);

bool officialManualGainLocked(Map clip) => (clip['lockedFields'] as List).any(
  (v) =>
      v == '*' ||
      v == 'effects' ||
      v == 'effectIds' ||
      v == 'gain' ||
      (v as String).startsWith('effects.') ||
      v.startsWith('effectIds.'),
);

/// Official audio clip effects: type=gain only. Limiter, pan, and visual
/// operators stay refused. Disabled nodes are not skipped.
List<Map> admittedAudioClipEffects(Map<String, dynamic> project, Map clip) {
  final result = <Map>[];
  final types = <String>{};
  for (final id in (clip['effectIds'] as List?) ?? const []) {
    final matches = ((project['effects'] as List?) ?? const []).where(
      (e) => e['id'] == id,
    );
    if (matches.length != 1) throw const StudioException('REF_NOT_FOUND');
    final e = matches.single as Map;
    final type = e['type'];
    if (type != 'gain' ||
        !types.add(type as String) ||
        e['pluginVersion'] != '1.0.0' ||
        e['owner']['kind'] != 'clip' ||
        e['owner']['id'] != clip['id'] ||
        (e['extensions'] as Map).isNotEmpty) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
    }
    validatedGainPoints(e, clip);
    result.add(e);
  }
  return result;
}

List<Map> validatedGainPoints(Map effect, Map clip) {
  final base = (effect['parameters']['gainDb'] as num).toDouble();
  _requireGainDb(base);
  final points = List<Map>.from(effect['keyframes']);
  if (points.length > 256) {
    throw const StudioException('GAIN_KEYFRAME_LIMIT');
  }
  final times = <Q>{};
  final duration = Q.fromJson(clip['timelineRange']['duration']);
  for (final k in points) {
    if (k['param'] != 'gainDb' ||
        k['easing'] != null ||
        !['hold', 'linear'].contains(k['interpolation'])) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
    }
    final value = k['value'];
    if (value is! num) {
      throw const StudioException('AUDIO_PARAMETER_RANGE');
    }
    _requireGainDb(value.toDouble());
    final t = Q.fromJson(k['localTime']);
    if (t < Q.of(0) || t > duration) {
      throw const StudioException('KEYFRAME_OUT_OF_RANGE');
    }
    if (quantizeAudioSample(t) != t) {
      throw const StudioException('KEYFRAME_NOT_ON_SAMPLE');
    }
    if (!times.add(t)) throw const StudioException('DUPLICATE_KEYFRAME');
  }
  points.sort(
    (a, b) => Q.fromJson(a['localTime']).compareTo(Q.fromJson(b['localTime'])),
  );
  return points;
}

void _requireGainDb(double db) {
  if (!db.isFinite || db < -96 || db > 12) {
    throw const StudioException('AUDIO_PARAMETER_RANGE');
  }
}

/// Clip-local seconds. Endpoints hold; outgoing interpolation is half-open
/// [a,b), exactly b selects b's value. Same rational policy as opacity.
double gainDbAt(Map effect, Q time, {List<Map>? points}) {
  final keys =
      points ??
      (List<Map>.from(effect['keyframes'])..sort(
        (a, b) =>
            Q.fromJson(a['localTime']).compareTo(Q.fromJson(b['localTime'])),
      ));
  if (keys.isEmpty) return (effect['parameters']['gainDb'] as num).toDouble();
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

List<Map> cropGainPoints(
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
  if (keys.isEmpty) return const [];
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
    'param': 'gainDb',
    'localTime': local.toJson(),
    'value': gainDbAt(effect, absolute, points: keys),
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

final class OfficialClipGain {
  const OfficialClipGain({required this.staticDb, this.automation});
  final double staticDb;
  final GainEnvelope? automation;
}

/// Persisted manual clip gain only. AUTO duck is never written into this
/// envelope. Disabled gain is unity (0 dB).
OfficialClipGain officialClipGain(Map<String, dynamic> project, Map clip) {
  final matches = admittedAudioClipEffects(
    project,
    clip,
  ).where((e) => e['type'] == 'gain');
  if (matches.isEmpty) return const OfficialClipGain(staticDb: 0);
  final effect = matches.single;
  if (effect['enabled'] == false) return const OfficialClipGain(staticDb: 0);
  final points = validatedGainPoints(effect, clip);
  if (points.isEmpty) {
    return OfficialClipGain(
      staticDb: (effect['parameters']['gainDb'] as num).toDouble(),
    );
  }
  return OfficialClipGain(
    staticDb: 0,
    automation: GainEnvelope([
      for (final k in points)
        GainPoint(
          Q.fromJson(k['localTime']),
          (k['value'] as num).toDouble(),
          interpolation: k['interpolation'] == 'hold'
              ? GainInterpolation.hold
              : GainInterpolation.linear,
        ),
    ]),
  );
}

({Map track, Map clip}) officialAudioClip(
  Map<String, dynamic> project,
  String clipId,
) {
  for (final sequence in project['sequences'] as List) {
    for (final track in sequence['tracks'] as List) {
      for (final clip in track['items'] as List) {
        if (clip['id'] == clipId && clip['source'] != null) {
          if (track['kind'] != 'audio') {
            throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
          }
          return (track: track as Map, clip: clip as Map);
        }
      }
    }
  }
  throw const StudioException('CLIP_NOT_FOUND');
}

/// Plans AUTO ducking against the persisted manual gain Effect. The Effect
/// bytes are not rewritten. A locked track or locked manual gain refuses the
/// whole application.
AnalysisGainPlayback applyOfficialClipAnalysis({
  required Map<String, dynamic> project,
  required String clipId,
  required List<TimeRange> speech,
  List<TimeRange> manualProtected = const [],
}) {
  final found = officialAudioClip(project, clipId);
  if (found.track['locked'] == true) {
    throw const StudioException('TRACK_LOCKED');
  }
  final gainLocked = officialManualGainLocked(found.clip);
  if (gainLocked) {
    throw const StudioException('MANUAL_LOCKED');
  }
  final official = officialClipGain(project, found.clip);
  final duration = Q.fromJson(found.clip['timelineRange']['duration']);
  final start = Q.fromJson(found.clip['timelineRange']['start']);
  final manual =
      official.automation ??
      GainEnvelope([
        GainPoint(Q.of(0), official.staticDb),
        if (duration > Q.of(0)) GainPoint(duration, official.staticDb),
      ]);
  return AnalysisGainPlayback.apply(
    manual: manual,
    clip: TimeRange(start, duration),
    speech: speech,
    manualProtected: manualProtected,
    trackLocked: false,
    gainLocked: false,
  );
}
