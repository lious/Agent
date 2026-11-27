import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:studio_contracts/studio_contracts.dart';

import 'voice_codes.dart';

/// Hash-based keystream plus HMAC-SHA256 sealed box for embeddings at rest.
/// The key never enters an ordinary archive or log. This is not a hardware
/// HSM and not clone inference.
final class EmbeddingCipher {
  EmbeddingCipher(List<int> key) : key = Uint8List.fromList(key) {
    if (this.key.length != 32) {
      throw const StudioException('INVALID_ID', 'embeddingKey');
    }
  }

  factory EmbeddingCipher.ephemeral() {
    final random = Random.secure();
    return EmbeddingCipher(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  final Uint8List key;

  List<int> seal(List<int> plain) {
    final random = Random.secure();
    final nonce = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    final cipher = _xor(plain, _keystream(nonce, plain.length));
    final mac = Hmac(sha256, key).convert([...nonce, ...cipher]).bytes;
    return [1, ...nonce, ...mac, ...cipher];
  }

  List<int> open(List<int> sealed) {
    if (sealed.isEmpty || sealed.first != 1 || sealed.length < 49) {
      throw const StudioException(embeddingMacMismatch);
    }
    final nonce = sealed.sublist(1, 17);
    final mac = sealed.sublist(17, 49);
    final cipher = sealed.sublist(49);
    final expected = Hmac(sha256, key).convert([...nonce, ...cipher]).bytes;
    if (!_constantEquals(mac, expected)) {
      throw const StudioException(embeddingMacMismatch);
    }
    return _xor(cipher, _keystream(nonce, cipher.length));
  }

  List<int> _keystream(List<int> nonce, int length) {
    final out = <int>[];
    var counter = 0;
    while (out.length < length) {
      final block = Hmac(sha256, key).convert([
        ...nonce,
        counter >> 24 & 0xff,
        counter >> 16 & 0xff,
        counter >> 8 & 0xff,
        counter & 0xff,
      ]).bytes;
      out.addAll(block);
      counter++;
    }
    return out.sublist(0, length);
  }

  static bool _constantEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static List<int> _xor(List<int> data, List<int> stream) => [
    for (var i = 0; i < data.length; i++) data[i] ^ stream[i],
  ];
}

/// Sealed embedding record. These bytes never enter ordinary archives
/// or journals.
final class VoiceEmbedding {
  VoiceEmbedding({
    required this.embeddingId,
    required this.voiceProfileId,
    required this.traceId,
    required this.bytes,
  }) {
    requireId(embeddingId);
    requireId(voiceProfileId);
    requireId(traceId);
  }

  final String embeddingId, voiceProfileId, traceId;
  final List<int> bytes;
}

final class ArchiveManifest {
  ArchiveManifest(List<Map<String, Object?>> items)
    : items = List.unmodifiable(items);
  final List<Map<String, Object?>> items;

  bool containsKey(String key) =>
      items.any((e) => e.keys.contains(key) || e.values.contains(key));
}

/// Voice vault. Embeddings stay in the sealed store, encrypted at rest.
/// Archive and log exports refuse to include plaintext or ciphertext.
final class VoiceStore {
  VoiceStore({EmbeddingCipher? cipher})
    : cipher = cipher ?? EmbeddingCipher.ephemeral();

  final EmbeddingCipher cipher;
  final Map<String, VoiceEmbedding> _vault = {};
  final List<String> _log = [];
  final Map<String, String> traces = {};

  void putEmbedding(VoiceEmbedding embedding) {
    final sealed = VoiceEmbedding(
      embeddingId: embedding.embeddingId,
      voiceProfileId: embedding.voiceProfileId,
      traceId: embedding.traceId,
      bytes: cipher.seal(embedding.bytes),
    );
    _vault[embedding.embeddingId] = sealed;
    traces[embedding.embeddingId] = embedding.traceId;
    _log.add('stored:${embedding.embeddingId}:trace:${embedding.traceId}');
  }

  VoiceEmbedding readSealed(String embeddingId) {
    final row = _vault[embeddingId];
    if (row == null) {
      throw StudioException(voiceProfileMissing, embeddingId);
    }
    return VoiceEmbedding(
      embeddingId: row.embeddingId,
      voiceProfileId: row.voiceProfileId,
      traceId: row.traceId,
      bytes: cipher.open(row.bytes),
    );
  }

  /// Test/inspection helper: ciphertext kept in the vault. Never archived.
  List<int> sealedBytes(String embeddingId) {
    final row = _vault[embeddingId];
    if (row == null) {
      throw StudioException(voiceProfileMissing, embeddingId);
    }
    return List<int>.from(row.bytes);
  }

  ArchiveManifest archiveProject({required String projectId}) {
    requireId(projectId);
    // Only references and traces, never raw embedding bytes or keys.
    return ArchiveManifest([
      {
        'projectId': projectId,
        'voiceRefs': [
          for (final e in _vault.values)
            {
              'embeddingId': e.embeddingId,
              'voiceProfileId': e.voiceProfileId,
              'traceId': e.traceId,
            },
        ],
      },
    ]);
  }

  List<String> exportLog() => List.unmodifiable(_log);

  void assertNoEmbeddingLeak(List<int> embeddingBytes) {
    final archive = archiveProject(projectId: 'proj-1');
    final blob = archive.items.toString() + exportLog().join('\n');
    final token = String.fromCharCodes(embeddingBytes);
    if (blob.contains(token)) {
      throw const StudioException(embeddingNotArchivable);
    }
    for (final item in archive.items) {
      if (item.containsKey('embedding') || item.containsKey('bytes')) {
        throw const StudioException(embeddingNotArchivable);
      }
    }
    for (final row in _vault.values) {
      final sealed = String.fromCharCodes(row.bytes.where((b) => b >= 32 && b < 127));
      if (token.isNotEmpty && sealed.contains(token)) {
        throw const StudioException(embeddingNotArchivable);
      }
    }
  }
}
