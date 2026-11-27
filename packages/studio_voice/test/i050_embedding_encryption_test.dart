import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_voice/studio_voice.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

void main() {
  test('embeddings are encrypted at rest and decrypt back to the plaintext', () {
    const token = 'SECRET_EMBED_TOKEN';
    final key = List<int>.generate(32, (i) => i + 1);
    final store = VoiceStore(cipher: EmbeddingCipher(key));
    store.putEmbedding(
      VoiceEmbedding(
        embeddingId: 'emb-1',
        voiceProfileId: 'voice-ada',
        traceId: 'trace-1',
        bytes: token.codeUnits,
      ),
    );
    final sealed = store.sealedBytes('emb-1');
    expect(sealed, isNot(equals(token.codeUnits)));
    expect(String.fromCharCodes(sealed), isNot(contains(token)));
    final opened = store.readSealed('emb-1');
    expect(opened.bytes, token.codeUnits);
    expect(opened.traceId, 'trace-1');
    store.assertNoEmbeddingLeak(token.codeUnits);
  });

  test('the wrong key cannot open a sealed embedding', () {
    const token = 'SECRET_EMBED_TOKEN';
    final store = VoiceStore(
      cipher: EmbeddingCipher(List<int>.generate(32, (i) => i + 1)),
    );
    store.putEmbedding(
      VoiceEmbedding(
        embeddingId: 'emb-1',
        voiceProfileId: 'voice-ada',
        traceId: 'trace-1',
        bytes: token.codeUnits,
      ),
    );
    final other = VoiceStore(
      cipher: EmbeddingCipher(List<int>.generate(32, (i) => 32 - i)),
    );
    // Transplant ciphertext into a store with a different key.
    other.putEmbedding(
      VoiceEmbedding(
        embeddingId: 'emb-x',
        voiceProfileId: 'voice-ada',
        traceId: 'trace-1',
        bytes: const [1],
      ),
    );
    expect(
      () => EmbeddingCipher(List<int>.generate(32, (i) => 32 - i))
          .open(store.sealedBytes('emb-1')),
      code(embeddingMacMismatch),
    );
  });

  test('plaintext and ciphertext stay out of archive and log exports', () {
    const token = 'SECRET_EMBED_TOKEN';
    final store = VoiceStore();
    store.putEmbedding(
      VoiceEmbedding(
        embeddingId: 'emb-2',
        voiceProfileId: 'voice-ada',
        traceId: 'trace-2',
        bytes: token.codeUnits,
      ),
    );
    store.assertNoEmbeddingLeak(token.codeUnits);
    final archive = store.archiveProject(projectId: 'proj-1');
    expect(archive.items.toString(), isNot(contains(token)));
    expect(store.exportLog().any((l) => l.contains(token)), isFalse);
    expect(archive.items.first.containsKey('bytes'), isFalse);
  });
}
