import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:studio_contracts/studio_contracts.dart';

Never importFailure(String part, [String path = '']) =>
    throw StudioException('SKILL_IMPORT_$part', path);

String digest(List<int> bytes) => 'sha256:${sha256.convert(bytes)}';
// Exact decimal components for accepted finite host numbers. No exponentiation,
// arbitrary-precision arithmetic or expansion of attacker-chosen exponents.
(String, String, int) _decimal(String token) {
  final m = RegExp(r'^(-?)([0-9]+)(?:\.([0-9]+))?(?:[eE]([+-]?[0-9]+))?$')
      .firstMatch(token)!;
  final fraction = m.group(3) ?? '';
  var digits = '${m.group(2)}$fraction'.replaceFirst(RegExp(r'^0+'), '');
  if (digits.isEmpty) return ('', '0', 0);
  final exp = int.tryParse(m.group(4) ?? '0');
  if (exp == null) importFailure('ENCODING', 'numberPrecision');
  var end = digits.length;
  while (end > 0 && digits.codeUnitAt(end - 1) == 48) {
    end--;
  }
  final scale = exp - fraction.length + digits.length - end;
  digits = digits.substring(0, end);
  return (m.group(1)!, digits, scale);
}

int compareJsonNumbers(num a, num b) {
  final x = _decimal(a.toString()), y = _decimal(b.toString());
  if (x == y) return 0;
  final negative = x.$1 == '-';
  if (negative != (y.$1 == '-')) return negative ? -1 : 1;
  int result;
  if (x.$2 == '0' || y.$2 == '0') {
    result = x.$2 == '0' ? -1 : 1;
  } else {
    result = (x.$2.length + x.$3).compareTo(y.$2.length + y.$3);
    if (result == 0) {
      final size = x.$2.length > y.$2.length ? x.$2.length : y.$2.length;
      result = x.$2.padRight(size, '0').compareTo(y.$2.padRight(size, '0'));
    }
  }
  return negative ? -result : result;
}

bool sameJson(Object? a, Object? b) {
  if (a is num && b is num) return compareJsonNumbers(a, b) == 0;
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && sameJson(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => sameJson(a[i], b[i]));
  }
  return a == b;
}

Object? freezeJson(Object? x) {
  if (x is Map) {
    return Map<String, Object?>.unmodifiable(
      x.map((k, v) => MapEntry(k as String, freezeJson(v))),
    );
  }
  if (x is List) return List<Object?>.unmodifiable(x.map(freezeJson));
  return x;
}

Map<String, dynamic> object(Object? x, [Set<String>? fields]) {
  if (x is! Map<String, dynamic> ||
      (fields != null &&
          (x.length != fields.length || !fields.every(x.containsKey)))) {
    importFailure('SCHEMA');
  }
  return x;
}

List<dynamic> array(Object? x, int max, [int min = 0]) {
  if (x is! List || x.length < min || x.length > max) importFailure('SCHEMA');
  return x;
}

void requireThat(bool value, [String code = 'SCHEMA', String path = '']) {
  if (!value) importFailure(code, path);
}

bool safeInt(Object? x, [int min = 0, int max = 9007199254740991]) =>
    x is int && x >= min && x <= max;
final idPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:@-]{0,127}$');
final hashPattern = RegExp(r'^sha256:[a-f0-9]{64}$');
bool isId(Object? x) => x is String && fullMatch(idPattern, x);
bool isHash(Object? x) => x is String && fullMatch(hashPattern, x);
bool fullMatch(RegExp pattern, String x) {
  final m = pattern.firstMatch(x);
  return m != null && m.start == 0 && m.end == x.length;
}

Uint8List strictBase64(Object? value, int max) {
  if (value is! String) importFailure('ENCODING', 'base64');
  if (value.length > ((max + 2) ~/ 3) * 4) {
    importFailure('LIMIT', 'base64Bytes');
  }
  if (!fullMatch(RegExp(r'[A-Za-z0-9+/_-]*={0,2}'), value) ||
      ((value.contains('+') || value.contains('/')) &&
          (value.contains('-') || value.contains('_')))) {
    importFailure('ENCODING', 'base64');
  }
  try {
    final normalized = value.replaceAll('-', '+').replaceAll('_', '/');
    if (normalized.length % 4 == 1 ||
        (normalized.contains('=') && normalized.length % 4 != 0)) {
      importFailure('ENCODING');
    }
    final padded = normalized.padRight((normalized.length + 3) ~/ 4 * 4, '=');
    final result = base64.decode(padded);
    if (result.length > max) importFailure('LIMIT', 'base64Bytes');
    if (base64.encode(result) != padded) {
      importFailure('ENCODING');
    }
    return result;
  } on FormatException {
    importFailure('ENCODING', 'base64');
  }
}

/// Duplicate-preserving lexical preflight BEFORE map decoding. Bounded depth,
/// strict strings/numbers and decoded-key uniqueness, including escaped aliases.
Object? strictJson(List<int> bytes, int max) {
  if (bytes.length > max) importFailure('LIMIT', 'jsonBytes');
  if (bytes.length >= 3 &&
      bytes[0] == 0xef &&
      bytes[1] == 0xbb &&
      bytes[2] == 0xbf) {
    importFailure('ENCODING', 'BOM');
  }
  try {
    final source = utf8.decode(bytes, allowMalformed: false);
    final scan = _JsonScan(source);
    scan.value(0);
    scan.space();
    if (scan.i != source.length) importFailure('ENCODING', 'trailing');
    return jsonDecode(source);
  } on FormatException {
    importFailure('ENCODING', 'json');
  }
}

final class _JsonScan {
  _JsonScan(this.s);
  final String s;
  int i = 0;
  void space() {
    while (i < s.length &&
        (s[i] == ' ' || s[i] == '\n' || s[i] == '\r' || s[i] == '\t')) {
      i++;
    }
  }

  void need(String ch) {
    space();
    if (i >= s.length || s[i++] != ch) importFailure('ENCODING');
  }

  String string() {
    space();
    final start = i;
    need('"');
    var escaped = false;
    while (i < s.length) {
      final c = s[i++];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (c == '\\') {
        escaped = true;
        continue;
      }
      if (c == '"') {
        final text = jsonDecode(s.substring(start, i)) as String;
        for (var j = 0; j < text.length; j++) {
          final c = text.codeUnitAt(j);
          if (c >= 0xd800 && c <= 0xdbff) {
            if (++j >= text.length ||
                text.codeUnitAt(j) < 0xdc00 ||
                text.codeUnitAt(j) > 0xdfff) {
              importFailure('ENCODING', 'surrogate');
            }
          } else if (c >= 0xdc00 && c <= 0xdfff) {
            importFailure('ENCODING', 'surrogate');
          }
        }
        return text;
      }
    }
    importFailure('ENCODING', 'string');
  }

  void value(int depth) {
    if (depth > 32) importFailure('LIMIT', 'depth');
    space();
    if (i >= s.length) importFailure('ENCODING');
    if (s[i] == '{') {
      i++;
      space();
      final keys = <String>{};
      if (i < s.length && s[i] == '}') {
        i++;
        return;
      }
      while (true) {
        final key = string();
        if (!keys.add(key)) importFailure('ENCODING', 'duplicateKey');
        need(':');
        value(depth + 1);
        space();
        if (i >= s.length) importFailure('ENCODING');
        if (s[i] == '}') {
          i++;
          return;
        }
        need(',');
      }
    }
    if (s[i] == '[') {
      i++;
      space();
      if (i < s.length && s[i] == ']') {
        i++;
        return;
      }
      while (true) {
        value(depth + 1);
        space();
        if (i >= s.length) importFailure('ENCODING');
        if (s[i] == ']') {
          i++;
          return;
        }
        need(',');
      }
    }
    if (s[i] == '"') {
      string();
      return;
    }
    final start = i;
    while (i < s.length && !' \t\r\n,]}'.contains(s[i])) {
      i++;
    }
    final token = s.substring(start, i);
    if (token == 'true' || token == 'false' || token == 'null') return;
    if (!fullMatch(
          RegExp(r'-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?'),
          token,
        ) ||
        num.tryParse(token)?.isFinite != true) {
      importFailure('ENCODING', 'number');
    }
    if (_decimal(token) != _decimal(num.parse(token).toString())) {
      importFailure('ENCODING', 'numberPrecision');
    }
  }
}
