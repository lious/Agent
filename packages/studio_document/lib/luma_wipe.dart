import 'package:studio_contracts/studio_contracts.dart';

import 'time.dart';

/// Registered plugin studio.fx/lumaWipe@1.0.0. Only maskMode=incomingLuma is
/// admitted on the Linux CPU reference path. This is an Effect.type legal
/// extension (plugin pattern), not a Transition.kind.
const lumaWipeEffectType = 'studio.fx/lumaWipe';
const lumaWipePluginVersion = '1.0.0';
const lumaWipeRequiredFeature = 'studio.craft.luma-wipe.v1';
const lumaWipeMaskIncoming = 'incomingLuma';
const lumaWipeSoftnessMin = 0.001;
const lumaWipeSoftnessMax = 0.5;

/// Rec.709 luma coefficients for linear RGB, matching the admitted colorBasic
/// consumer and s8f.
const rec709LumaR = 0.2126;
const rec709LumaG = 0.7152;
const rec709LumaB = 0.0722;

/// CPU reference path is enabled once this increment's goldens exist. GPU and
/// Web stay disabled; they must not be treated as consistent backends.
const lumaWipeCpuReferenceEnabled = true;

bool lumaWipeBackendEnabled(String backend) =>
    backend == 'cpu' && lumaWipeCpuReferenceEnabled;

bool isLumaWipeEffect(Map effect) => effect['type'] == lumaWipeEffectType;

List<Map> lumaWipeEffects(Map<String, dynamic> d) => [
  for (final e in d['effects'] as List)
    if (isLumaWipeEffect(e as Map)) e,
];

bool hasLumaWipeEffects(Map<String, dynamic> d) =>
    (d['effects'] as List).any((e) => isLumaWipeEffect(e as Map));

/// Hermite smoothstep used by the s8f luma formula.
double lumaSmoothstep(double edge0, double edge1, double x) {
  if (edge0 == edge1) return x < edge0 ? 0 : 1;
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Progress p=clamp((t-(cut-before))/(before+after),0,1). Endpoints are exact.
Q lumaWipeProgress(Q time, Q cut, Q before, Q after) {
  final length = before + after;
  final elapsed = time - (cut - before);
  if (elapsed <= Q.of(0)) return Q.of(0);
  if (elapsed >= length) return Q.of(1);
  return elapsed / length;
}

/// s8f weight w from incoming-leg linear RGB, progress p, softness and invert.
/// p=0 yields w=0 (all A); p=1 yields w=1 (all B) for m in [0,1].
double lumaWipeWeight({
  required double p,
  required double red,
  required double green,
  required double blue,
  required double softness,
  required bool invert,
}) {
  if (p <= 0) return 0;
  if (p >= 1) return 1;
  var m = rec709LumaR * red + rec709LumaG * green + rec709LumaB * blue;
  if (invert) m = 1 - m;
  m = m.clamp(0.0, 1.0);
  final threshold = 1 + softness - p * (1 + 2 * softness);
  return lumaSmoothstep(threshold - softness, threshold + softness, m);
}

void _requireClosedLumaParameters(Map parameters) {
  const required = {
    'sequenceId',
    'trackId',
    'leftClipId',
    'rightClipId',
    'cut',
    'before',
    'after',
    'maskMode',
    'maskAssetRef',
    'softness',
    'invert',
  };
  if (parameters.length != required.length ||
      !required.every(parameters.containsKey)) {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  final mode = parameters['maskMode'];
  if (mode == 'assetLuma' || mode == 'assetAlpha') {
    final mask = parameters['maskAssetRef'];
    if (mask is Map && mask['kind'] == 'asset') {
      throw const StudioException('MASK_MEDIA_UNSUPPORTED');
    }
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  if (mode != lumaWipeMaskIncoming) {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  if (parameters['maskAssetRef'] != null) {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  final invert = parameters['invert'];
  if (invert is! bool) {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  final softness = parameters['softness'];
  if (softness is! num ||
      !softness.isFinite ||
      softness < lumaWipeSoftnessMin ||
      softness > lumaWipeSoftnessMax) {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  for (final id in ['sequenceId', 'trackId', 'leftClipId', 'rightClipId']) {
    if (parameters[id] is! String || (parameters[id] as String).isEmpty) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
    }
  }
}

Q lumaParamTime(Map parameters, String key) =>
    Q.fromJson(Map<String, dynamic>.from(parameters[key] as Map));

/// Same Transition handles formula as project_semantics: left needs a tail of
/// [after], right needs a head of [before]. No freeze fallback.
bool lumaHandlesAvailable(Map left, Map right, Q before, Q after, Map assets) {
  for (final pair in [
    [left, after, true],
    [right, before, false],
  ]) {
    final clip = pair[0] as Map, need = pair[1] as Q, tail = pair[2] as bool;
    final src = clip['source'];
    if (src == null ||
        src['kind'] != 'asset' ||
        clip['timeMap']['kind'] != 'linear') {
      return false;
    }
    final asset = assets[src['id']];
    if (asset == null || asset['version'] != src['version']) {
      return false;
    }
    final streams = (asset['streams'] as List).where(
      (s) => s['id'] == src['streamId'],
    );
    if (streams.length != 1) return false;
    final available = tail
        ? Q.fromJson(streams.single['duration']) -
              Q.fromJson(clip['sourceRange']['start']) -
              Q.fromJson(clip['sourceRange']['duration'])
        : Q.fromJson(clip['sourceRange']['start']);
    if (available < need * Q.fromJson(clip['timeMap']['rate'])) {
      return false;
    }
  }
  return true;
}

TimeRange lumaWindow(Q cut, Q before, Q after) =>
    TimeRange(cut - before, before + after);

bool lumaWindowsOverlap(TimeRange a, TimeRange b) =>
    a.start < b.end && b.start < a.end;

void requireAdmittedRequiredFeatures(Map<String, dynamic> d) {
  final features = List<String>.from(d['requiredFeatures'] as List);
  if (features.toSet().length != features.length) {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  final unique = features.toSet();
  final other = unique.difference({lumaWipeRequiredFeature});
  if (other.isNotEmpty) {
    throw StudioException('FEATURE_NOT_IMPLEMENTED', 'requiredFeatures');
  }
  if (unique.contains(lumaWipeRequiredFeature) != hasLumaWipeEffects(d)) {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
}

bool isAdmittedSequenceLumaWipe(Map<String, dynamic> d, Map effect) {
  if (!isLumaWipeEffect(effect)) return false;
  final seq = d['sequences'][0];
  return effect['pluginVersion'] == lumaWipePluginVersion &&
      effect['owner']['kind'] == 'sequence' &&
      effect['owner']['id'] == seq['id'] &&
      (effect['extensions'] as Map).isEmpty &&
      (effect['keyframes'] as List).isEmpty;
}

void requireLumaWipeProfile(Map<String, dynamic> d) {
  requireAdmittedRequiredFeatures(d);
  final effects = lumaWipeEffects(d);
  if (effects.isEmpty) return;
  if (!lumaWipeBackendEnabled('cpu')) {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  final seq = d['sequences'][0];
  final fps = FrameRate(seq['frameRate']['n'], seq['frameRate']['d']);
  final tracks = {for (final t in seq['tracks']) t['id']: t};
  final clips = {
    for (final t in seq['tracks'])
      for (final c in t['items']) c['id']: c,
  };
  final assets = {for (final a in d['assets'] as List) a['id']: a};
  final windows = <String, List<TimeRange>>{};
  void occupy(String trackId, TimeRange window) {
    final previous = windows.putIfAbsent(trackId, () => []);
    for (final old in previous) {
      if (lumaWindowsOverlap(window, old)) {
        throw const StudioException('TRANSITION_WINDOW_CONFLICT');
      }
    }
    previous.add(window);
  }

  for (final t in d['transitions'] as List) {
    if (t['enabled'] != true) continue;
    final before = Q.fromJson(t['before']), after = Q.fromJson(t['after']);
    if (before + after > Q.of(0)) {
      occupy(
        t['trackId'] as String,
        lumaWindow(Q.fromJson(t['cut']), before, after),
      );
    }
  }
  for (final e in effects) {
    if (!isAdmittedSequenceLumaWipe(d, e)) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
    }
    if (e['enabled'] != true) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
    }
    final p = Map<String, dynamic>.from(e['parameters'] as Map);
    _requireClosedLumaParameters(p);
    if (p['sequenceId'] != seq['id']) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
    }
    final track = tracks[p['trackId']];
    final left = clips[p['leftClipId']], right = clips[p['rightClipId']];
    if (track == null ||
        left == null ||
        right == null ||
        track['kind'] != 'video' ||
        track['muted'] == true ||
        left['trackId'] != track['id'] ||
        right['trackId'] != track['id']) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
    }
    for (final c in [left, right]) {
      if (c['source'] == null ||
          c['source']['kind'] != 'asset' ||
          c['enabled'] != true ||
          c['timeMap']['kind'] != 'linear' ||
          Q.fromJson(c['timeMap']['rate']) != Q.of(1)) {
        throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
      }
    }
    final cut = lumaParamTime(p, 'cut'),
        before = lumaParamTime(p, 'before'),
        after = lumaParamTime(p, 'after');
    for (final q in [cut, before, after]) {
      if (fps.quantize(q, Rounding.tiesToEven) != q) {
        throw const StudioException('TRANSITION_NOT_ON_FRAME');
      }
    }
    final leftEnd =
        Q.fromJson(left['timelineRange']['start']) +
        Q.fromJson(left['timelineRange']['duration']);
    final rightStart = Q.fromJson(right['timelineRange']['start']);
    if (leftEnd != cut || rightStart != cut) {
      throw const StudioException('TRANSITION_NOT_ADJACENT');
    }
    if (before < Q.of(0) || after < Q.of(0) || before + after <= Q.of(0)) {
      throw const StudioException('TRANSITION_RANGE');
    }
    if (!lumaHandlesAvailable(left, right, before, after, assets)) {
      throw const StudioException('HANDLE_UNAVAILABLE');
    }
    occupy(p['trackId'] as String, lumaWindow(cut, before, after));
  }
}

void reportLumaWipeSemantics(
  Map<String, dynamic> d,
  void Function(String code, String path) issue,
  Map clips,
  Map tracks,
  Map<String, Map<dynamic, dynamic>> indexes,
) {
  for (final effect in d['effects'] as List) {
    if (!isLumaWipeEffect(effect as Map)) continue;
    final path = '/effects';
    final p = effect['parameters'];
    if (p is! Map) {
      issue('UNSUPPORTED_EDIT_TECHNIQUE', path);
      continue;
    }
    try {
      _requireClosedLumaParameters(Map<String, dynamic>.from(p));
    } on StudioException catch (e) {
      issue(e.code, path);
      continue;
    }
    final left = clips[p['leftClipId']],
        right = clips[p['rightClipId']],
        track = tracks[p['trackId']];
    if (left == null || right == null || track == null) {
      issue('REF_NOT_FOUND', path);
      continue;
    }
    final cut = lumaParamTime(p, 'cut'),
        before = lumaParamTime(p, 'before'),
        after = lumaParamTime(p, 'after');
    if (track['sequenceId'] != p['sequenceId'] ||
        left['trackId'] != track['id'] ||
        right['trackId'] != track['id'] ||
        (Q.fromJson(left['timelineRange']['start']) +
                Q.fromJson(left['timelineRange']['duration'])) !=
            cut ||
        Q.fromJson(right['timelineRange']['start']) != cut) {
      issue('TRANSITION_NOT_ADJACENT', path);
    }
    if (before < Q.of(0) || after < Q.of(0) || before + after <= Q.of(0)) {
      issue('TRANSITION_RANGE', path);
    }
  }
}

final class LumaWipeSample {
  const LumaWipeSample({
    required this.progress,
    required this.softness,
    required this.invert,
  });
  final Q progress;
  final double softness;
  final bool invert;
  Map<String, Object> toRecipe() => {
    'p': progress.toJson(),
    'softness': softness,
    'invert': invert,
  };
}
