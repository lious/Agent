import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:studio_assets/craft/signed_import/sodium_verifier.dart';
import 'package:test/test.dart';

List<int> hex(String x) => [
  for (var i = 0; i < x.length; i += 2)
    int.parse(x.substring(i, i + 2), radix: 16),
];
SodiumVerifier backend() {
  final lock = jsonDecode(
    File('third_party/sodium/backend-lock.json').readAsStringSync(),
  ) as Map;
  return SodiumVerifier.loadTrusted(
    Platform.environment['STUDIO_SODIUM_LIBRARY'] ??
        lock['devBinary'] as String,
    lock['devBinarySha256'] as String,
  );
}

const vectors = [
  [
    'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
    '',
    'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
  ],
  [
    '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
    '72',
    '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
  ],
  [
    'fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025',
    'af82',
    '6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a',
  ],
];

void main() {
  final verifier = backend();
  for (var i = 0; i < vectors.length; i++) {
    test('RFC 8032 section 7.1 vector ${i + 1} and altered message', () {
      final v = vectors[i], pk = hex(v[0]), sig = hex(v[2]);
      expect(verifier.verify(Uint8List.fromList(hex(v[1])), sig, pk), isTrue);
      expect(
        verifier.verify(Uint8List.fromList([...hex(v[1]), 0]), sig, pk),
        isFalse,
      );
    });
  }
  test('reject S >= L and S+L malleability', () {
    final v = vectors.first, sig = hex(v[2]);
    final l =
        (BigInt.one << 252) +
        BigInt.parse('27742317777372353535851937790883648493');
    BigInt little(List<int> a) =>
        a.reversed.fold(BigInt.zero, (v, b) => (v << 8) | BigInt.from(b));
    List<int> bytes(BigInt n) => [
      for (var i = 0; i < 32; i++) ((n >> (i * 8)) & BigInt.from(255)).toInt(),
    ];
    for (final s in [
      l,
      little(sig.sublist(32)) + l,
      (BigInt.one << 256) - BigInt.one,
    ]) {
      expect(
        verifier.verify(Uint8List(0), [
          ...sig.take(32),
          ...bytes(s),
        ], hex(v[0])),
        isFalse,
      );
    }
  });
  test(
    'reject identity/zero/noncanonical/invalid public keys and R points',
    () {
      final bad = [
        List<int>.filled(32, 0),
        [1, ...List<int>.filled(31, 0)],
        List<int>.filled(32, 255),
        [237, ...List<int>.filled(30, 255), 127],
      ];
      for (final p in bad) {
        expect(verifier.validPublicKey(p), isFalse);
        expect(
          verifier.verify(Uint8List(0), [
            ...p,
            ...List<int>.filled(32, 0),
          ], hex(vectors.first[0])),
          isFalse,
        );
        expect(
          verifier.verify(Uint8List(0), [1, ...List<int>.filled(63, 0)], p),
          isFalse,
        );
      }
    },
  );
  test('length guards, altered signature, wrong binary pin fail closed', () {
    final v = vectors.first, sig = hex(v[2])..[0] ^= 1;
    expect(verifier.verify(Uint8List(0), sig, hex(v[0])), isFalse);
    expect(verifier.verify(Uint8List(0), [], hex(v[0])), isFalse);
    expect(verifier.verify(Uint8List(0), hex(v[2]), []), isFalse);
    expect(
      () => SodiumVerifier.loadTrusted(
        '/workspace/toolchains/sodium-1.0.22/lib/libsodium.so.26.4.0',
        '0' * 64,
      ),
      throwsA(anything),
    );
  });
  test('pinned C2SP Wycheproof Ed25519 corpus (all cases)', () {
    final bytes = File('test/skills/signed_import/vectors/ed25519_test.json')
        .readAsBytesSync();
    expect(
      sha256.convert(bytes).toString(),
      'ea80ffebac085e21cb9d3e903e7fa2b448d96702da5b31f061d0b83b430b74b3',
    );
    final corpus = jsonDecode(utf8.decode(bytes)) as Map;
    var count = 0;
    for (final group in corpus['testGroups'] as List) {
      final pk = hex(group['publicKey']['pk'] as String);
      for (final item in group['tests'] as List) {
        final ok = verifier.verify(
          Uint8List.fromList(hex(item['msg'] as String)),
          hex(item['sig'] as String),
          pk,
        );
        expect(
          ok,
          item['result'] == 'valid',
          reason: 'Wycheproof tcId=${item['tcId']} ${item['flags']}',
        );
        count++;
      }
    }
    expect(count, corpus['numberOfTests']);
  });
}
