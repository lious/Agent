import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_voice/studio_voice.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

void main() {
  test('no consent and post-revoke new executions stay at zero', () {
    final ledger = VoiceConsentLedger();
    final store = VoiceStore();
    final job = CloneJob(
      id: 'clone-1',
      voiceProfileId: 'voice-ada',
      traceId: 'trace-1',
      ledger: ledger,
      store: store,
      backend: FakeCloneBackend(),
    );
    expect(
      () => job.execute(referencePcm: const [1, 2, 3]),
      code(consentRequired),
    );
    expect(ledger.executionCount('voice-ada'), 0);
    ledger.grant(
      VoiceConsent(
        consentId: 'consent-1',
        subjectPersonId: 'ada',
        voiceProfileId: 'voice-ada',
        uses: {'voiceClone'},
        grantedAt: DateTime.utc(2026, 11, 27),
      ),
    );
    expect(
      () => job.execute(referencePcm: const [1, 2, 3]),
      code(cloneInferenceUnavailable),
    );
    expect(ledger.executionCount('voice-ada'), 0);
    ledger.revoke('voice-ada', at: DateTime.utc(2026, 11, 27, 12));
    expect(
      () => job.execute(referencePcm: const [1, 2, 3]),
      code(consentRevoked),
    );
    expect(ledger.executionCount('voice-ada'), 0);
  });

  test('third-party impersonation without consent is refused, not a blanket ban', () {
    final ledger = VoiceConsentLedger();
    final job = CloneJob(
      id: 'clone-2',
      voiceProfileId: 'voice-other',
      traceId: 'trace-2',
      ledger: ledger,
      store: VoiceStore(),
      backend: FakeCloneBackend(),
      subjectIsOwner: false,
    );
    expect(
      () => job.execute(referencePcm: const [0]),
      code(consentRequired),
    );
    ledger.grant(
      VoiceConsent(
        consentId: 'consent-other',
        subjectPersonId: 'other',
        voiceProfileId: 'voice-other',
        uses: {'voiceClone'},
        grantedAt: DateTime.utc(2026, 11, 27),
      ),
    );
    // Consent is sufficient to pass the gate; inference is still unavailable.
    expect(
      () => job.execute(referencePcm: const [0]),
      code(cloneInferenceUnavailable),
    );
  });

  test('embeddings never enter ordinary archive or log; refs stay traceable', () {
    final store = VoiceStore();
    const token = 'SECRET_EMBED_TOKEN';
    store.putEmbedding(
      VoiceEmbedding(
        embeddingId: 'emb-1',
        voiceProfileId: 'voice-ada',
        traceId: 'trace-1',
        bytes: token.codeUnits,
      ),
    );
    store.assertNoEmbeddingLeak(token.codeUnits);
    final archive = store.archiveProject(projectId: 'proj-1');
    final refs = (archive.items.first['voiceRefs'] as List).cast<Map>();
    expect(refs.single['traceId'], 'trace-1');
    expect(refs.single['embeddingId'], 'emb-1');
    expect(store.traces['emb-1'], 'trace-1');
    expect(archive.containsKey('bytes'), isFalse);
    expect(store.exportLog().any((l) => l.contains(token)), isFalse);
  });

  test('revoked voice pin blocks new speech render', () {
    final ledger = VoiceConsentLedger();
    ledger.grant(
      VoiceConsent(
        consentId: 'consent-1',
        subjectPersonId: 'ada',
        voiceProfileId: 'voice-ada',
        uses: {'voiceClone', 'speech'},
        grantedAt: DateTime.utc(2026, 11, 27),
      ),
    );
    ledger.revoke('voice-ada', at: DateTime.utc(2026, 11, 27, 13));
    final job = SpeechJob(
      id: 'job-revoked',
      plan: DialoguePlan(
        id: 'plan-r',
        sentences: [
          DialogueSentence(
            id: 's1',
            text: 'hello',
            startMs: 0,
            durationMs: 80,
            voiceProfileId: 'voice-ada',
          ),
        ],
      ),
      backend: FakeSpeechBackend(),
      consent: ledger,
    );
    expect(() => job.splice(), code(voicePinRevoked));
  });
}
