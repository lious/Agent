import 'dart:convert';

/// 64-hex fingerprint over all input bytes. This is an identity helper
/// for official Linux tests, not a cryptographic claim.
String fingerprint(List<int> bytes) {
  int fnv(int seed) {
    var n = seed;
    for (final b in bytes) {
      n ^= b & 0xff;
      n = (n * 16777619) & 0xffffffff;
    }
    n ^= bytes.length;
    return n & 0xffffffff;
  }

  final out = StringBuffer();
  var seed = 2166136261;
  while (out.length < 64) {
    final n = fnv(seed);
    out.write(n.toRadixString(16).padLeft(8, '0'));
    seed = (seed * 33 + n) & 0xffffffff;
  }
  return out.toString().substring(0, 64);
}

String fingerprintString(String text) => fingerprint(utf8.encode(text));

String fingerprintJson(Map<String, Object?> json) =>
    fingerprintString(jsonEncode(json));
