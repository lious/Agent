import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';

import 'studio_document.dart';

/// One field (or id-keyed entity) that differs between two document snapshots.
/// [path] is a list of map keys (String) or id selectors (`{'id': ...}`).
/// Version and revision leaves are omitted: they are concurrency clocks, not
/// user-visible fields, and the store reallocates versions on the invert commit.
final class FieldChange {
  FieldChange({
    required this.path,
    required this.before,
    required this.after,
    required this.beforeMissing,
    required this.afterMissing,
  });
  final List<Object> path;
  final Object? before, after;
  final bool beforeMissing, afterMissing;
}

bool _skippedKey(Object? key) => key == 'version' || key == 'revision';

bool _idKeyedList(dynamic value) {
  if (value is! List || value.isEmpty) {
    return value is List && value.isEmpty;
  }
  return value.every((e) => e is Map && e['id'] is String);
}

bool _jsonEq(Object? a, Object? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null) {
    return a == b;
  }
  return contentHash(a) == contentHash(b);
}

Object? _absent = Object();

/// Content-level field changes from [before] to [after], ignoring version/revision.
List<FieldChange> documentFieldChanges(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) {
  final out = <FieldChange>[];
  _walk(before, after, const [], out);
  return List.unmodifiable(out);
}

void _walk(dynamic a, dynamic b, List<Object> path, List<FieldChange> out) {
  if (_jsonEq(_stripClocks(a), _stripClocks(b))) {
    return;
  }
  if (a is Map && b is Map) {
    final keys = <String>{
      for (final k in a.keys)
        if (k is String && !_skippedKey(k)) k,
      for (final k in b.keys)
        if (k is String && !_skippedKey(k)) k,
    };
    for (final key in keys.toList()..sort()) {
      final hasA = a.containsKey(key), hasB = b.containsKey(key);
      _walkPair(
        hasA ? a[key] : _absent,
        hasB ? b[key] : _absent,
        [...path, key],
        !hasA,
        !hasB,
        out,
      );
    }
    return;
  }
  if (a is List && b is List && _idKeyedList(a) && _idKeyedList(b)) {
    final am = {for (final e in a) e['id'] as String: e};
    final bm = {for (final e in b) e['id'] as String: e};
    final ids = {...am.keys, ...bm.keys}.toList()..sort();
    for (final id in ids) {
      _walkPair(
        am[id] ?? _absent,
        bm[id] ?? _absent,
        [
          ...path,
          {'id': id},
        ],
        !am.containsKey(id),
        !bm.containsKey(id),
        out,
      );
    }
    return;
  }
  out.add(
    FieldChange(
      path: path,
      before: identical(a, _absent) ? null : a,
      after: identical(b, _absent) ? null : b,
      beforeMissing: identical(a, _absent),
      afterMissing: identical(b, _absent),
    ),
  );
}

void _walkPair(
  dynamic a,
  dynamic b,
  List<Object> path,
  bool aMissing,
  bool bMissing,
  List<FieldChange> out,
) {
  if (aMissing && bMissing) {
    return;
  }
  if (aMissing || bMissing) {
    out.add(
      FieldChange(
        path: path,
        before: aMissing ? null : a,
        after: bMissing ? null : b,
        beforeMissing: aMissing,
        afterMissing: bMissing,
      ),
    );
    return;
  }
  _walk(a, b, path, out);
}

dynamic _stripClocks(dynamic value) {
  if (value is Map) {
    return {
      for (final e in value.entries)
        if (e.key is! String || !_skippedKey(e.key))
          e.key: _stripClocks(e.value),
    };
  }
  if (value is List) {
    return [for (final e in value) _stripClocks(e)];
  }
  return value;
}

/// True when any recorded after-value no longer matches [current].
bool fieldInvertConflicts(
  Map<String, dynamic> current,
  List<FieldChange> changes,
) {
  for (final change in changes) {
    final present = _exists(current, change.path);
    if (change.afterMissing) {
      if (present) {
        return true;
      }
      continue;
    }
    if (!present) {
      return true;
    }
    if (!_jsonEq(
      _stripClocks(_get(current, change.path)),
      _stripClocks(change.after),
    )) {
      return true;
    }
  }
  return false;
}

/// Restore [changes] onto a detached copy of [current]. Caller must admit the
/// result. Conflicts throw [UNDO_CONFLICT] atomically (no partial write).
Map<String, dynamic> applyFieldInvert(
  Map<String, dynamic> current,
  List<FieldChange> changes,
) {
  if (fieldInvertConflicts(current, changes)) {
    throw const StudioException('UNDO_CONFLICT');
  }
  final next = jsonDecode(jsonEncode(current)) as Map<String, dynamic>;
  final pendingGaps = <FieldChange>[];
  for (final change in changes) {
    if (change.beforeMissing) {
      _remove(next, change.path);
    } else if (_isTrackGap(change.path, change.before) &&
        !_exists(next, change.path)) {
      // Restore clip starts first so a mid-span gap can be inserted by time
      // instead of being appended after later remnants.
      pendingGaps.add(change);
    } else {
      _put(next, change.path, change.before);
    }
  }
  for (final change in pendingGaps) {
    _put(next, change.path, change.before);
  }
  return next;
}

bool _exists(dynamic root, List<Object> path) {
  dynamic cur = root;
  for (final segment in path) {
    if (segment is String) {
      if (cur is! Map || !cur.containsKey(segment)) {
        return false;
      }
      cur = cur[segment];
      continue;
    }
    if (segment is Map && segment['id'] is String) {
      if (cur is! List) {
        return false;
      }
      final matches = [
        for (final e in cur)
          if (e is Map && e['id'] == segment['id']) e,
      ];
      if (matches.length != 1) {
        return false;
      }
      cur = matches.single;
      continue;
    }
    return false;
  }
  return true;
}

dynamic _get(dynamic root, List<Object> path) {
  dynamic cur = root;
  for (final segment in path) {
    if (segment is String) {
      cur = (cur as Map)[segment];
      continue;
    }
    final id = (segment as Map)['id'];
    cur = (cur as List).singleWhere((e) => e is Map && e['id'] == id);
  }
  return cur;
}

void _put(dynamic root, List<Object> path, Object? value) {
  if (path.isEmpty) {
    throw const StudioException('UNDO_CONFLICT');
  }
  dynamic cur = root;
  for (var i = 0; i < path.length - 1; i++) {
    cur = _child(cur, path[i], create: true);
  }
  final last = path.last;
  if (last is String) {
    (cur as Map)[last] = value;
    return;
  }
  final id = (last as Map)['id'] as String;
  final list = cur as List;
  final index = list.indexWhere((e) => e is Map && e['id'] == id);
  if (index >= 0) {
    list[index] = value;
  } else if (_isTrackGap(path, value)) {
    // Restoring a track gap must keep list order by start time. Appending
    // would leave a mid-span hole as IMPLICIT_GAP even when the restored
    // starts are otherwise legal. Media clips still append, so invert of a
    // non-trailing leave-gap delete, LiftClips, or mid-span insert paste
    // stays IMPLICIT_GAP.
    list.insert(_gapInsertIndex(list, value as Map), value);
  } else {
    list.add(value);
  }
}

bool _isTrackGap(List<Object> path, Object? value) {
  if (path.length < 2 || path[path.length - 2] != 'items') {
    return false;
  }
  return value is Map &&
      value['source'] == null &&
      value['timelineRange'] is Map;
}

int _gapInsertIndex(List list, Map value) {
  final start = Q.fromJson((value['timelineRange'] as Map)['start']);
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    if (item is Map && item['timelineRange'] is Map) {
      final other = Q.fromJson((item['timelineRange'] as Map)['start']);
      if (other > start) {
        return i;
      }
    }
  }
  return list.length;
}

void _remove(dynamic root, List<Object> path) {
  if (path.isEmpty) {
    throw const StudioException('UNDO_CONFLICT');
  }
  dynamic cur = root;
  for (var i = 0; i < path.length - 1; i++) {
    cur = _child(cur, path[i], create: false);
  }
  final last = path.last;
  if (last is String) {
    (cur as Map).remove(last);
    return;
  }
  final id = (last as Map)['id'] as String;
  (cur as List).removeWhere((e) => e is Map && e['id'] == id);
}

dynamic _child(dynamic cur, Object segment, {required bool create}) {
  if (segment is String) {
    if (cur is! Map) {
      throw const StudioException('UNDO_CONFLICT');
    }
    if (!cur.containsKey(segment)) {
      if (!create) {
        throw const StudioException('UNDO_CONFLICT');
      }
      cur[segment] = <String, dynamic>{};
    }
    return cur[segment];
  }
  final id = (segment as Map)['id'] as String;
  if (cur is! List) {
    throw const StudioException('UNDO_CONFLICT');
  }
  final matches = [
    for (final e in cur)
      if (e is Map && e['id'] == id) e,
  ];
  if (matches.length == 1) {
    return matches.single;
  }
  throw const StudioException('UNDO_CONFLICT');
}
