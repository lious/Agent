import 'dart:convert';

import 'manifest_metaschema.dart';

import 'package:studio_contracts/studio_contracts.dart';

import 'strict_json.dart';

/// Evaluator for exactly the bundled FilmSkill vocabulary and the documented
/// bounded manifest subset. No remote resolution or format hooks.
final class _SchemaWork {
  int visits = 0;
  void tick() {
    if (++visits > 200000) importFailure('LIMIT', 'schemaWork');
  }
}

void checkSchema(
  Object? schema,
  Object? data,
  Map<String, dynamic> root, [
  int depth = 0,
]) => _evaluate(schema, data, root, _SchemaWork(), depth);
void _evaluate(
  Object? schema,
  Object? data,
  Map<String, dynamic> root,
  _SchemaWork work,
  int depth,
) {
  work.tick();
  if (depth > 256) importFailure('LIMIT', 'schemaDepth');
  if (schema is bool) {
    requireThat(schema);
    return;
  }
  final s = object(schema);
  if (s.containsKey(r'$ref')) {
    final ref = s[r'$ref'];
    requireThat(ref is String && ref.startsWith(r'#/$defs/'));
    final defs = object(root[r'$defs']);
    final name = (ref as String).substring(8);
    requireThat(defs.containsKey(name));
    _evaluate(defs[name], data, root, work, depth + 1);
  }
  for (final kind in ['anyOf', 'oneOf']) {
    if (s.containsKey(kind)) {
      var count = 0;
      for (final alt in s[kind] as List) {
        try {
          _evaluate(alt, data, root, work, depth + 1);
          count++;
        } on StudioException catch (e) {
          if (e.code != 'SKILL_IMPORT_SCHEMA') rethrow;
        }
      }
      requireThat(kind == 'oneOf' ? count == 1 : count > 0);
    }
  }
  if (s.containsKey('const')) requireThat(sameJson(s['const'], data));
  if (s.containsKey('enum')) {
    requireThat((s['enum'] as List).any((x) => sameJson(x, data)));
  }
  if (s.containsKey('type')) {
    final valid = switch (s['type']) {
      'object' => data is Map,
      'array' => data is List,
      'string' => data is String,
      'integer' =>
        data is int ||
            (data is double &&
                data.isFinite &&
                data == data.truncateToDouble()),
      'number' => data is num && data.isFinite,
      'boolean' => data is bool,
      'null' => data == null,
      _ => false,
    };
    requireThat(valid);
  }
  if (data is Map) {
    final props = s['properties'] as Map? ?? {};
    for (final k in s['required'] as List? ?? []) {
      requireThat(data.containsKey(k));
    }
    for (final e in data.entries) {
      if (props.containsKey(e.key)) {
        _evaluate(props[e.key], e.value, root, work, depth + 1);
      } else if (s['additionalProperties'] == false) {
        importFailure('SCHEMA', 'extraField');
      } else if (s['additionalProperties'] is Map) {
        _evaluate(s['additionalProperties'], e.value, root, work, depth + 1);
      }
    }
  }
  if (data is List) {
    if (s['minItems'] != null) {
      requireThat(data.length >= (s['minItems'] as num));
    }
    if (s['maxItems'] != null) {
      requireThat(data.length <= (s['maxItems'] as num));
    }
    if (s.containsKey('items')) {
      for (final v in data) {
        _evaluate(s['items'], v, root, work, depth + 1);
      }
    }
  }
  if (data is String) {
    final length = data.runes.length;
    if (s['minLength'] != null) requireThat(length >= (s['minLength'] as num));
    if (s['maxLength'] != null) requireThat(length <= (s['maxLength'] as num));
    if (s['pattern'] != null) {
      requireThat(RegExp(s['pattern'] as String).hasMatch(data));
    }
  }
  if (data is num) {
    if (s['minimum'] != null) {
      requireThat(compareJsonNumbers(data, s['minimum'] as num) >= 0);
    }
    if (s['maximum'] != null) {
      requireThat(compareJsonNumbers(data, s['maximum'] as num) <= 0);
    }
  }
}

/// Rejects malformed/unsupported schema syntax even when fixtures are empty.
/// The shape rules below implement the closed bundled subset metaschema; keyword
/// validation never executes user regexes, external references or custom hooks.
void checkManifestSchema(Object? schema) {
  final meta = jsonDecode(manifestMetaschemaJson) as Map<String, dynamic>;
  final root = schema is Map<String, dynamic> ? schema : <String, dynamic>{};
  final active = <String>{};
  final work = _SchemaWork();
  _evaluate(meta, schema, meta, work, 0);
  void walk(Object? node, int depth) {
    work.tick();
    if (depth > 32) importFailure('LIMIT', 'manifestSchemaDepth');
    if (node is bool) return;
    final s = object(node);
    const keywords = {
      'type',
      'properties',
      'required',
      'additionalProperties',
      'items',
      'enum',
      'const',
      'minimum',
      'maximum',
      'minItems',
      'maxItems',
      'minLength',
      'maxLength',
      r'$defs',
      r'$ref',
    };
    requireThat(s.keys.every(keywords.contains));
    if (s.containsKey('type')) {
      requireThat(
        {
          'object',
          'array',
          'string',
          'integer',
          'number',
          'boolean',
          'null',
        }.contains(s['type']),
      );
    }
    if (s.containsKey('enum')) {
      final vals = array(s['enum'], 1048576, 1);
      for (var i = 0; i < vals.length; i++) {
        requireThat(
          !vals.take(i).any((v) {
            work.tick();
            return sameJson(v, vals[i]);
          }),
        );
      }
    }
    for (final pair in [
      ['minItems', 'maxItems'],
      ['minLength', 'maxLength'],
      ['minimum', 'maximum'],
    ]) {
      for (final k in pair) {
        if (s.containsKey(k)) {
          requireThat(
            k == 'minimum' || k == 'maximum'
                ? s[k] is num && (s[k] as num).isFinite
                : safeInt(s[k]),
          );
        }
      }
      if (s.containsKey(pair[0]) && s.containsKey(pair[1])) {
        requireThat(
          compareJsonNumbers(s[pair[0]] as num, s[pair[1]] as num) <= 0,
        );
      }
    }
    if (s.containsKey('properties') ||
        s.containsKey('required') ||
        s['type'] == 'object') {
      requireThat(s['additionalProperties'] == false);
      final props = s.containsKey('properties')
          ? object(s['properties'])
          : <String, dynamic>{};
      final required = s.containsKey('required')
          ? array(s['required'], 1048576)
          : [];
      requireThat(
        required.every((x) => x is String && props.containsKey(x)) &&
            required.toSet().length == required.length,
      );
      for (final v in props.values) {
        walk(v, depth + 1);
      }
    }
    if (s['type'] != null) {
      if (s.containsKey('properties') ||
          s.containsKey('required') ||
          s.containsKey('additionalProperties')) {
        requireThat(s['type'] == 'object');
      }
      if (s.containsKey('items') ||
          s.containsKey('minItems') ||
          s.containsKey('maxItems')) {
        requireThat(s['type'] == 'array');
      }
      if (s.containsKey('minLength') || s.containsKey('maxLength')) {
        requireThat(s['type'] == 'string');
      }
      if (s.containsKey('minimum') || s.containsKey('maximum')) {
        requireThat(s['type'] == 'number' || s['type'] == 'integer');
      }
    }
    if (s.containsKey('additionalProperties')) {
      requireThat(s['additionalProperties'] == false);
    }
    if (s.containsKey('items')) walk(s['items'], depth + 1);
    if (s.containsKey(r'$defs')) {
      for (final e in object(s[r'$defs']).entries) {
        requireThat(fullMatch(RegExp(r'[A-Za-z][A-Za-z0-9_]{0,63}'), e.key));
        walk(e.value, depth + 1);
      }
    }
    if (s.containsKey(r'$ref')) {
      final ref = s[r'$ref'];
      requireThat(
        ref is String &&
            fullMatch(RegExp(r'#/\$defs/[A-Za-z][A-Za-z0-9_]{0,63}'), ref),
      );
      final defs = object(root[r'$defs']), name = (ref as String).substring(8);
      requireThat(defs.containsKey(name) && active.add(name));
      requireThat(
        defs[name] is! Map || !(defs[name] as Map).containsKey(r'$ref'),
      );
      walk(defs[name], depth + 1);
      active.remove(name);
    }
  }

  walk(schema, 0);
}
