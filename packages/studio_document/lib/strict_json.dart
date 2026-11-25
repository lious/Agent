import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';

/// Bounded RFC8259 reader; unlike jsonDecode, duplicate object keys are errors.
Object? readStrictJson(List<int> bytes, {int maxBytes = 32 * 1024 * 1024}) {
  if (bytes.length > maxBytes) throw const StudioException('DOCUMENT_LIMIT');
  String text;
  try {
    text = utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    throw const StudioException('JSON_UTF8');
  }
  return _Reader(text).read();
}

final class _Reader {
  _Reader(this.text);
  final String text;
  int i = 0, count = 0;
  Never fail([String code = 'JSON_SYNTAX']) =>
      throw StudioException(code, 'byte-or-codeunit:$i');
  void ws() {
    while (i < text.length && [32, 9, 10, 13].contains(text.codeUnitAt(i))) {
      i++;
    }
  }

  bool take(String s) {
    ws();
    if (text.startsWith(s, i)) {
      i += s.length;
      return true;
    }
    return false;
  }

  Object? read() {
    final v = value(0);
    ws();
    if (i != text.length) fail();
    return v;
  }

  Object? value(int depth) {
    ws();
    if (depth > 64 || ++count > 1000000) fail('DOCUMENT_LIMIT');
    if (i >= text.length) fail();
    if (text[i] == '"') return string();
    if (take('{')) {
      final map = <String, Object?>{};
      if (take('}')) return map;
      do {
        ws();
        if (i >= text.length || text[i] != '"') fail();
        final key = string();
        if (map.containsKey(key)) fail('JSON_DUPLICATE_KEY');
        if (!take(':')) fail();
        map[key] = value(depth + 1);
        if (take('}')) return map;
      } while (take(','));
      fail();
    }
    if (take('[')) {
      final list = <Object?>[];
      if (take(']')) return list;
      do {
        list.add(value(depth + 1));
        if (take(']')) return list;
      } while (take(','));
      fail();
    }
    for (final entry in {'true': true, 'false': false, 'null': null}.entries) {
      if (take(entry.key)) return entry.value;
    }
    final m = RegExp(r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?')
        .matchAsPrefix(text, i);
    if (m == null) fail();
    i = m.end;
    final n = num.tryParse(m.group(0)!);
    if (n == null || !n.isFinite) fail('INVALID_JSON');
    return n;
  }

  String string() {
    final start = i++;
    var escaped = false;
    while (i < text.length) {
      final c = text.codeUnitAt(i++);
      if (!escaped && c == 34) {
        try {
          return jsonDecode(text.substring(start, i)) as String;
        } on FormatException {
          fail();
        }
      }
      if (!escaped && c < 32) fail();
      if (!escaped && c == 92) {
        escaped = true;
      } else {
        escaped = false;
      }
    }
    fail();
  }
}
