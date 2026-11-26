import 'dart:convert';
import 'dart:typed_data';

import 'package:studio_contracts/studio_contracts.dart';

import 'marker.dart';
import 'strict_json.dart';
import 'time.dart';

/// Official marker sidecar named by the v1 addendum
/// (`docs/addenda/marker-sidecar-v1.md`), not by the original 104-spec
/// snapshot. This is not WebVTT chapters, CSV, or FCPXML, and it does not
/// change the core project Marker schema.
final class MarkerSidecar {
  static const formatName = 'studio.markers.sidecar';
  static const formatVersion = '1.0.0';
  static const mediaType = 'application/json';
  static const recommendedExtension = '.studio-markers.json';

  /// Write every selected marker (default: all markers in [project]).
  /// Missing selected ids are refused; markers are never silently dropped.
  /// [project] is a ProjectDocument JSON map (`project.toJson()`).
  static String export(Map<String, dynamic> project, {Iterable<String>? ids}) {
    final byId = <String, Map<String, dynamic>>{};
    final markers = project['markers'];
    if (markers is! List) {
      throw const StudioException('MARKER_SIDECAR_INVALID', '/markers');
    }
    for (final raw in markers) {
      final map = Map<String, dynamic>.from(raw as Map);
      final id = map['id'];
      if (id is! String) {
        throw const StudioException('MARKER_INVALID');
      }
      byId[id] = map;
    }
    final selected = <Map<String, Object?>>[];
    if (ids == null) {
      for (final map in byId.values) {
        selected.add(_officialMarkerJson(map));
      }
    } else {
      final seen = <String>{};
      for (final id in ids) {
        if (!seen.add(id)) {
          throw const StudioException('DUPLICATE_ID');
        }
        final map = byId[id];
        if (map == null) {
          throw StudioException('MARKER_SIDECAR_INVALID', '/markers/$id');
        }
        selected.add(_officialMarkerJson(map));
      }
    }
    selected.sort(_compareOfficial);
    return jsonEncode({
      'format': formatName,
      'formatVersion': formatVersion,
      'markers': selected,
    });
  }

  /// UTF-8 bytes of [export], without a BOM.
  static Uint8List exportBytes(
    Map<String, dynamic> project, {
    Iterable<String>? ids,
  }) => Uint8List.fromList(utf8.encode(export(project, ids: ids)));

  /// Validate and restore every official field from a sidecar [source]
  /// (UTF-8 [String] or bytes). Throws [StudioException] and never applies a
  /// partial marker list. See [tryImport] to also read unsupported-field
  /// warnings.
  /// [target] is the destination ProjectDocument JSON map.
  static MarkerStore import(Object source, Map<String, dynamic> target) =>
      tryImport(source, target).requireOk;

  static MarkerSidecarImport tryImport(
    Object source,
    Map<String, dynamic> target,
  ) {
    final result = _parse(source, target);
    if (result.markers == null) {
      return result;
    }
    return result;
  }
}

/// Successful import, or a whole-file refusal with a stable error code.
/// Unknown extra fields are listed in [warnings] and refused; they are never
/// stripped to invent a successful import.
final class MarkerSidecarImport {
  MarkerSidecarImport._ok(MarkerStore store)
    : markers = store,
      warnings = const {},
      code = null,
      path = '';

  MarkerSidecarImport._rejected({
    required String this.code,
    this.path = '',
    Set<String> warnings = const {},
  }) : markers = null,
       warnings = Set.unmodifiable(warnings);

  final MarkerStore? markers;
  final Set<String> warnings;
  final String? code;
  final String path;

  bool get isOk => markers != null;

  MarkerStore get requireOk {
    final store = markers;
    if (store != null) {
      return store;
    }
    throw StudioException(code!, path);
  }
}

const _envelopeKeys = {'format', 'formatVersion', 'markers'};
const _markerKeys = {
  'id',
  'sequenceId',
  'label',
  'colorRGBA',
  'anchor',
  'time',
  'duration',
  'ripple',
};
const _anchorKeys = {'kind', 'clipId'};
const _timeKeys = {'n', 'd'};
final _versionPattern = RegExp(
  r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$',
);

Map<String, Object?> _officialMarkerJson(Map<String, dynamic> raw) =>
    TimelineMarker.fromJson(raw).toJson();

int _compareOfficial(Map<String, Object?> a, Map<String, Object?> b) {
  final time = Q
      .fromJson(Map<String, dynamic>.from(a['time'] as Map))
      .compareTo(Q.fromJson(Map<String, dynamic>.from(b['time'] as Map)));
  if (time != 0) {
    return time;
  }
  return (a['id'] as String).compareTo(b['id'] as String);
}

List<int> _utf8Bytes(Object source) {
  if (source is List<int>) {
    return source;
  }
  if (source is String) {
    return utf8.encode(source);
  }
  throw const StudioException('MARKER_SIDECAR_INVALID');
}

MarkerSidecarImport _parse(Object source, Map<String, dynamic> target) {
  final bytes = _utf8Bytes(source);
  if (bytes.length >= 3 &&
      bytes[0] == 0xef &&
      bytes[1] == 0xbb &&
      bytes[2] == 0xbf) {
    return MarkerSidecarImport._rejected(
      code: 'MARKER_SIDECAR_INVALID',
      path: '/bom',
    );
  }
  final Object? decoded;
  try {
    decoded = readStrictJson(bytes);
  } on StudioException catch (e) {
    return MarkerSidecarImport._rejected(code: e.code, path: e.path);
  }
  if (decoded is! Map) {
    return MarkerSidecarImport._rejected(
      code: 'MARKER_SIDECAR_INVALID',
      path: '/',
    );
  }
  final root = Map<String, Object?>.from(decoded);
  final warnings = <String>{};
  _collectUnknown(root, _envelopeKeys, '', warnings);
  if (!_hasString(root, 'format') ||
      !_hasString(root, 'formatVersion') ||
      !root.containsKey('markers')) {
    if (warnings.isNotEmpty) {
      return _unsupported(warnings);
    }
    return MarkerSidecarImport._rejected(
      code: 'MARKER_SIDECAR_INVALID',
      path: '/',
    );
  }
  if (root['format'] != MarkerSidecar.formatName) {
    if (warnings.isNotEmpty) {
      return _unsupported(warnings);
    }
    return MarkerSidecarImport._rejected(
      code: 'MARKER_SIDECAR_INVALID',
      path: '/format',
    );
  }
  final version = root['formatVersion'] as String;
  final match = _versionPattern.firstMatch(version);
  if (match == null || match[1] != '1') {
    if (warnings.isNotEmpty) {
      return _unsupported(warnings);
    }
    return MarkerSidecarImport._rejected(
      code: 'MARKER_SIDECAR_INVALID',
      path: '/formatVersion',
    );
  }
  final markersRaw = root['markers'];
  if (markersRaw is! List) {
    if (warnings.isNotEmpty) {
      return _unsupported(warnings);
    }
    return MarkerSidecarImport._rejected(
      code: 'MARKER_SIDECAR_INVALID',
      path: '/markers',
    );
  }
  for (var i = 0; i < markersRaw.length; i++) {
    final item = markersRaw[i];
    final base = '/markers/$i';
    if (item is! Map) {
      if (warnings.isNotEmpty) {
        return _unsupported(warnings);
      }
      return MarkerSidecarImport._rejected(
        code: 'MARKER_SIDECAR_INVALID',
        path: base,
      );
    }
    final map = Map<String, Object?>.from(item);
    _collectUnknown(map, _markerKeys, base, warnings);
    final anchor = map['anchor'];
    if (anchor is Map) {
      _collectUnknown(
        Map<String, Object?>.from(anchor),
        _anchorKeys,
        '$base/anchor',
        warnings,
      );
    }
    for (final field in ['time', 'duration']) {
      final value = map[field];
      if (value is Map) {
        _collectUnknown(
          Map<String, Object?>.from(value),
          _timeKeys,
          '$base/$field',
          warnings,
        );
      }
    }
  }
  if (warnings.isNotEmpty) {
    return _unsupported(warnings);
  }

  final parsed = <TimelineMarker>[];
  for (var i = 0; i < markersRaw.length; i++) {
    final path = '/markers/$i';
    try {
      parsed.add(
        _readMarker(Map<String, Object?>.from(markersRaw[i] as Map), path),
      );
    } on StudioException catch (e) {
      return MarkerSidecarImport._rejected(
        code: e.code,
        path: e.path.isEmpty ? path : e.path,
      );
    }
  }

  final MarkerStore store;
  try {
    store = MarkerStore(parsed);
  } on StudioException catch (e) {
    return MarkerSidecarImport._rejected(code: e.code, path: e.path);
  }

  try {
    _admitAgainstTarget(store, target);
  } on StudioException catch (e) {
    return MarkerSidecarImport._rejected(code: e.code, path: e.path);
  }
  return MarkerSidecarImport._ok(store);
}

MarkerSidecarImport _unsupported(Set<String> warnings) {
  final listed = warnings.toList()..sort();
  return MarkerSidecarImport._rejected(
    code: 'MARKER_SIDECAR_UNSUPPORTED',
    path: listed.join(','),
    warnings: warnings,
  );
}

void _collectUnknown(
  Map<String, Object?> map,
  Set<String> allowed,
  String base,
  Set<String> warnings,
) {
  for (final key in map.keys) {
    if (!allowed.contains(key)) {
      final path = base.isEmpty ? '/$key' : '$base/$key';
      warnings.add('MARKER_SIDECAR_UNSUPPORTED:$path');
    }
  }
}

bool _hasString(Map<String, Object?> map, String key) => map[key] is String;

TimelineMarker _readMarker(Map<String, Object?> raw, String path) {
  for (final key in _markerKeys) {
    if (!raw.containsKey(key)) {
      throw StudioException('MARKER_INVALID', '$path/$key');
    }
  }
  final id = raw['id'];
  final sequenceId = raw['sequenceId'];
  final label = raw['label'];
  final ripple = raw['ripple'];
  final color = raw['colorRGBA'];
  final anchorRaw = raw['anchor'];
  if (id is! String || sequenceId is! String || label is! String) {
    throw StudioException('MARKER_INVALID', path);
  }
  if (ripple is! bool) {
    throw StudioException('MARKER_INVALID', '$path/ripple');
  }
  if (color is! List || color.length != 4) {
    throw StudioException('MARKER_INVALID', '$path/colorRGBA');
  }
  final colorRGBA = <num>[];
  for (final c in color) {
    if (c is! num || c < 0 || c > 1) {
      throw StudioException('MARKER_INVALID', '$path/colorRGBA');
    }
    colorRGBA.add(c);
  }
  if (anchorRaw is! Map) {
    throw StudioException('ANCHOR_INVALID', '$path/anchor');
  }
  final anchor = Map<String, Object?>.from(anchorRaw);
  if (!anchor.containsKey('kind') || !anchor.containsKey('clipId')) {
    throw StudioException('ANCHOR_INVALID', '$path/anchor');
  }
  final kind = anchor['kind'];
  final clipId = anchor['clipId'];
  if (kind is! String) {
    throw StudioException('MARKER_ANCHOR_NOT_IMPLEMENTED', '$path/anchor/kind');
  }
  if (kind != 'absolute' && kind != 'clipLocal') {
    throw StudioException('MARKER_ANCHOR_NOT_IMPLEMENTED', '$path/anchor/kind');
  }
  if (kind == 'absolute') {
    if (clipId != null) {
      throw StudioException('ANCHOR_INVALID', '$path/anchor/clipId');
    }
  } else if (clipId is! String) {
    throw StudioException('ANCHOR_INVALID', '$path/anchor/clipId');
  }
  final time = _readTime(raw['time'], '$path/time');
  final duration = _readTime(raw['duration'], '$path/duration');
  return TimelineMarker(
    id,
    sequenceId: sequenceId,
    label: label,
    time: time,
    duration: duration,
    ripple: ripple,
    anchorKind: kind,
    anchorClipId: kind == 'clipLocal' ? clipId as String : null,
    colorRGBA: colorRGBA,
  );
}

Q _readTime(Object? raw, String path) {
  if (raw is! Map) {
    throw StudioException('TIME_ENCODING', path);
  }
  try {
    return Q.fromJson(Map<String, dynamic>.from(raw));
  } on StudioException catch (e) {
    throw StudioException(e.code, e.path.isEmpty ? path : e.path);
  }
}

void _admitAgainstTarget(MarkerStore store, Map<String, dynamic> target) {
  final sequencesRaw = target['sequences'];
  if (sequencesRaw is! List) {
    throw const StudioException('PARENT_MISMATCH');
  }
  final sequences = {
    for (final raw in sequencesRaw) (raw as Map)['id'] as String: raw,
  };
  for (final marker in store.markers) {
    final sequence = sequences[marker.sequenceId];
    if (sequence == null) {
      throw StudioException('PARENT_MISMATCH', '/markers/${marker.id}');
    }
    if (marker.anchorKind != 'clipLocal') {
      continue;
    }
    final host = _clipOnSequence(sequence, marker.anchorClipId!);
    if (host == null || !_rangeCovered(host, marker.time, marker.duration)) {
      throw StudioException('ANCHOR_OUT_OF_RANGE', '/markers/${marker.id}');
    }
  }
}

Map? _clipOnSequence(Map sequence, String clipId) {
  for (final rawTrack in sequence['tracks'] as List) {
    final track = rawTrack as Map;
    if (track['kind'] != 'video' && track['kind'] != 'audio') {
      continue;
    }
    for (final rawClip in track['items'] as List) {
      final clip = rawClip as Map;
      if (clip['id'] == clipId && clip['source'] != null) {
        return clip;
      }
    }
  }
  return null;
}

bool _rangeCovered(Map clip, Q start, Q duration) {
  final clipStart = Q.fromJson(clip['timelineRange']['start']);
  final clipDur = Q.fromJson(clip['timelineRange']['duration']);
  return start >= clipStart && start + duration <= clipStart + clipDur;
}
