import 'dart:convert';

import 'package:json_canonicalizer/json_canonicalizer.dart';

import 'src/project_schema.dart';
import 'time.dart';

import 'package:studio_contracts/studio_contracts.dart';

part 'project_semantics.dart';

final class ValidationIssue {
  const ValidationIssue(this.phase, this.code, this.path);
  final String phase, code, path;
  @override
  String toString() => '$phase:$code:$path';
}

/// Closed, local-schema evaluator for the vocabulary used by Project 2.0.0.
/// Not a general-purpose Draft202012 implementation; no remote ref fetching.
final class DocumentValidator {
  DocumentValidator()
    : _schema = jsonDecode(projectSchemaJson) as Map<String, dynamic>;
  final Map<String, dynamic> _schema;
  List<ValidationIssue> validate(Map<String, dynamic> document) {
    var count = 0;
    ValidationIssue? invalid;
    void preflight(dynamic x, int depth) {
      if (invalid != null) return;
      if (depth > 64 || ++count > 1000000) {
        invalid = const ValidationIssue('structural', 'DOCUMENT_LIMIT', '');
        return;
      }
      if (x is Map) {
        for (final e in x.entries) {
          if (e.key is! String) {
            invalid = const ValidationIssue('structural', 'INVALID_JSON', '');
            return;
          }
          preflight(e.value, depth + 1);
          if (invalid != null) return;
        }
      } else if (x is List) {
        for (final v in x) {
          preflight(v, depth + 1);
          if (invalid != null) return;
        }
      } else if (!(x == null ||
          x is String ||
          x is bool ||
          (x is num && x.isFinite))) {
        invalid = const ValidationIssue('structural', 'INVALID_JSON', '');
      }
    }

    preflight(document, 0);
    if (invalid != null) return [invalid!];
    final structural = _check(_schema, document, '');
    if (structural.isNotEmpty) return structural;
    final issues = <ValidationIssue>[];
    void issue(String code, String path) =>
        issues.add(ValidationIssue('semantic', code, path));
    // Enumerate declared entities, NEVER recursively interpret opaque extension,
    // provider parameter or source-reference objects as entity definitions.
    final ids = <String>{document['projectId'] as String};
    void entity(Map value, String path) {
      if (!ids.add(value['id'] as String)) issue('DUPLICATE_ID', path);
    }

    for (final name in _entityTables) {
      for (final value in document[name] as List) {
        entity(value as Map, '/$name');
      }
    }
    for (final sequence in document['sequences']) {
      for (final track in sequence['tracks']) {
        entity(track as Map, '/sequences/tracks');
        for (final item in track['items']) {
          entity(item as Map, '/sequences/tracks/items');
        }
      }
    }
    for (final asset in document['assets']) {
      for (final stream in asset['streams']) {
        entity(stream as Map, '/assets/streams');
      }
    }
    for (final effect in document['effects']) {
      for (final key in effect['keyframes']) {
        entity(key as Map, '/effects/keyframes');
      }
    }
    for (final image in document['imageDocuments']) {
      for (final layer in image['layers']) {
        entity(layer as Map, '/imageDocuments/layers');
      }
    }
    void checkTimes(dynamic x, String path) {
      if (x is Map) {
        if (x.length == 2 &&
            x.containsKey('n') &&
            x.containsKey('d') &&
            x['n'] is String) {
          try {
            Q.fromJson(Map<String, dynamic>.from(x));
          } on StudioException catch (e) {
            issue(e.code, path);
          }
        }
        for (final e in x.entries) {
          if (e.key != 'extensions' && e.key != 'parameters') {
            checkTimes(e.value, '$path/${e.key}');
          }
        }
      } else if (x is List) {
        for (var i = 0; i < x.length; i++) {
          checkTimes(x[i], '$path/$i');
        }
      }
    }

    // Extensions are opaque data: never interpret an extension's n/d or ID.
    for (final e in document.entries.where((e) => e.key != 'extensions')) {
      checkTimes(e.value, '/${e.key}');
    }
    void checkU64(dynamic x, String path) {
      if (x is Map) {
        for (final e in x.entries) {
          if ((e.key == 'revision' || e.key == 'version') &&
              e.value is String &&
              RegExp(r'^[0-9]+$').hasMatch(e.value as String) &&
              BigInt.parse(e.value as String) > maxI64) {
            issue('TIME_OVERFLOW', '$path/${e.key}');
          }
          if (e.key != 'extensions' && e.key != 'parameters') {
            checkU64(e.value, '$path/${e.key}');
          }
        }
      } else if (x is List) {
        for (var i = 0; i < x.length; i++) {
          checkU64(x[i], '$path/$i');
        }
      }
    }

    checkU64(document, '');
    final sequences = document['sequences'] as List;
    final buses = {for (final b in document['audioBuses'] as List) b['id']: b};
    if (!sequences.any((s) => s['id'] == document['rootSequenceId'])) {
      issue('REF_NOT_FOUND', '/rootSequenceId');
    }
    // Project graphs are not JSON nesting: a valid bounded document can have
    // thousands of routes. Avoid host-stack recursion on untrusted project data.
    final visited = <String>{};
    for (final root in buses.keys.cast<String>()) {
      if (visited.contains(root)) continue;
      final path = <String>{};
      String? current = root;
      while (current != null) {
        if (path.contains(current)) {
          issue('REFERENCE_CYCLE', '/audioBuses/$current');
          break;
        }
        if (visited.contains(current)) break;
        path.add(current);
        final bus = buses[current];
        if (bus == null) {
          issue('REF_NOT_FOUND', '/audioBuses/$current');
          break;
        }
        current = bus['outputBusId'] as String?;
      }
      visited.addAll(path);
    }
    for (var si = 0; si < sequences.length; si++) {
      final s = sequences[si];
      final sp = '/sequences/$si';
      if (!buses.containsKey(s['masterBusId'])) {
        issue('REF_NOT_FOUND', '$sp/masterBusId');
      }
      final order = <int>{};
      var maxEnd = Q.of(0);
      try {
        if (Q.fromJson(s['canvas']['pixelAspect']) <= Q.of(0)) {
          issue('INVALID_RANGE', '$sp/canvas/pixelAspect');
        }
        final fps = FrameRate(
          s['frameRate']['n'] as int,
          s['frameRate']['d'] as int,
        );
        for (final t in s['tracks']) {
          if (t['sequenceId'] != s['id']) {
            issue('PARENT_MISMATCH', '$sp/tracks');
          }
          if (!order.add(t['order'] as int)) {
            issue('DUPLICATE_ORDER', '$sp/tracks');
          }
          if (t['busId'] != null && !buses.containsKey(t['busId'])) {
            issue('REF_NOT_FOUND', '$sp/tracks/busId');
          }
          if (t['kind'] == 'caption' && (t['items'] as List).isNotEmpty) {
            issue('CAPTION_TRACK_ITEMS', '$sp/tracks');
          }
          var previous = Q.of(0);
          for (final item in t['items']) {
            if (item['trackId'] != t['id']) {
              issue('PARENT_MISMATCH', '$sp/tracks/items');
            }
            final r = item['timelineRange'];
            final range = TimeRange(
              Q.fromJson(r['start']),
              Q.fromJson(r['duration']),
            );
            if (range.start < Q.of(0)) {
              issue('INVALID_RANGE', '$sp/tracks/items');
            }
            if (range.start < previous) issue('COLLISION', '$sp/tracks/items');
            if (range.start > previous) {
              issue('IMPLICIT_GAP', '$sp/tracks/items');
            }
            if (t['kind'] == 'video' &&
                (fps.quantize(range.start, Rounding.tiesToEven) !=
                        range.start ||
                    fps.quantize(range.end, Rounding.tiesToEven) !=
                        range.end)) {
              issue('OFF_FRAME_GRID', '$sp/tracks/items');
            }
            if (t['kind'] == 'audio' &&
                (Q(
                          sampleIndex(range.start, 48000, Rounding.tiesToEven),
                          BigInt.from(48000),
                        ) !=
                        range.start ||
                    Q(
                          sampleIndex(range.end, 48000, Rounding.tiesToEven),
                          BigInt.from(48000),
                        ) !=
                        range.end)) {
              issue('OFF_SAMPLE_GRID', '$sp/tracks/items');
            }
            previous = range.end;
            if (range.end > maxEnd) maxEnd = range.end;
          }
        }
        for (final c in document['captions'] as List) {
          if ((s['tracks'] as List).any((t) => t['id'] == c['trackId'])) {
            final r = c['timelineRange'];
            final end = Q.fromJson(r['start']) + Q.fromJson(r['duration']);
            if (end > maxEnd) maxEnd = end;
          }
        }
        if (Q.fromJson(s['duration']) != maxEnd) {
          issue('DURATION_MISMATCH', '$sp/duration');
        }
      } on StudioException catch (e) {
        issue(e.code, sp);
      }
    }
    if (issues.isEmpty) {
      try {
        _projectSemantics(document, issue);
      } on StudioException catch (e) {
        issue(e.code, '/');
      }
    }
    return issues;
  }

  List<ValidationIssue> _check(
    dynamic schema,
    dynamic v,
    String path, [
    int depth = 0,
  ]) {
    final issues = <ValidationIssue>[];
    void fail(String code) =>
        issues.add(ValidationIssue('structural', code, path));
    if (depth > 64) {
      fail('SCHEMA_DEPTH');
      return issues;
    }
    if (schema is bool) {
      if (!schema) fail('SCHEMA_FALSE');
      return issues;
    }
    final s = schema as Map;
    if (s.containsKey(r'$ref')) {
      final ref = s[r'$ref'] as String;
      if (!ref.startsWith(r'#/$defs/')) {
        fail('UNSUPPORTED_SCHEMA_REF');
        return issues;
      }
      return _check(
        (_schema[r'$defs'] as Map)[ref.substring(8)],
        v,
        path,
        depth + 1,
      );
    }
    bool equal(dynamic a, dynamic b) => canonicalize(a) == canonicalize(b);
    if (s.containsKey('const') && !equal(v, s['const'])) fail('SCHEMA_CONST');
    if (s['enum'] is List && !(s['enum'] as List).any((x) => equal(x, v))) {
      fail('SCHEMA_ENUM');
    }
    for (final union in ['anyOf', 'oneOf']) {
      if (s[union] is List) {
        final matches = (s[union] as List)
            .where((x) => _check(x, v, path, depth + 1).isEmpty)
            .length;
        if (matches == 0 || (union == 'oneOf' && matches != 1)) {
          fail('SCHEMA_UNION');
        }
      }
    }
    final type = s['type'];
    final typeOk = switch (type) {
      null => true,
      'object' => v is Map<String, dynamic>,
      'array' => v is List,
      'string' => v is String,
      'integer' => v is num && v.isFinite && v == v.roundToDouble(),
      'number' => v is num && v.isFinite,
      'boolean' => v is bool,
      'null' => v == null,
      _ => false,
    };
    if (!typeOk) {
      fail('SCHEMA_TYPE');
      return issues;
    }
    if (v is Map<String, dynamic>) {
      final props = s['properties'] as Map? ?? {};
      for (final name in s['required'] as List? ?? []) {
        if (!v.containsKey(name)) {
          issues.add(
            ValidationIssue('structural', 'SCHEMA_REQUIRED', '$path/$name'),
          );
        }
      }
      if (s['maxProperties'] != null &&
          v.length > (s['maxProperties'] as int)) {
        fail('SCHEMA_SIZE');
      }
      for (final e in v.entries) {
        final p = '$path/${e.key.replaceAll('~', '~0').replaceAll('/', '~1')}';
        if (s['propertyNames'] != null) {
          issues.addAll(_check(s['propertyNames'], e.key, p, depth + 1));
        }
        if (props.containsKey(e.key)) {
          issues.addAll(_check(props[e.key], e.value, p, depth + 1));
        } else if (s['additionalProperties'] == false) {
          issues.add(ValidationIssue('structural', 'SCHEMA_UNKNOWN_FIELD', p));
        }
      }
    }
    if (v is List) {
      if ((s['minItems'] != null && v.length < (s['minItems'] as int)) ||
          (s['maxItems'] != null && v.length > (s['maxItems'] as int))) {
        fail('SCHEMA_SIZE');
      }
      if (s['items'] != null) {
        for (var i = 0; i < v.length; i++) {
          issues.addAll(_check(s['items'], v[i], '$path/$i', depth + 1));
        }
      }
    }
    if (v is String) {
      final length = v.runes.length;
      if ((s['minLength'] != null && length < (s['minLength'] as int)) ||
          (s['maxLength'] != null && length > (s['maxLength'] as int))) {
        fail('SCHEMA_SIZE');
      }
      if (s['pattern'] != null && !RegExp(s['pattern'] as String).hasMatch(v)) {
        fail('SCHEMA_PATTERN');
      }
      if (s['format'] == 'date-time' &&
          (DateTime.tryParse(v) == null ||
              !RegExp(r'(Z|[+-][0-9]{2}:[0-9]{2})$').hasMatch(v))) {
        fail('SCHEMA_FORMAT');
      }
    }
    if (v is num) {
      if ((s['minimum'] != null && v < (s['minimum'] as num)) ||
          (s['maximum'] != null && v > (s['maximum'] as num)) ||
          (s['exclusiveMinimum'] != null &&
              v <= (s['exclusiveMinimum'] as num)) ||
          (s['multipleOf'] != null && v % (s['multipleOf'] as num) != 0)) {
        fail('SCHEMA_RANGE');
      }
    }
    return issues;
  }
}
