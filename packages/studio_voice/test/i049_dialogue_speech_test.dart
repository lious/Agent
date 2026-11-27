import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_voice/studio_voice.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

DialoguePlan twoSentences() {
  return DialoguePlan(
    id: 'plan-1',
    sentences: [
      DialogueSentence(
        id: 's1',
        text: 'hello',
        startMs: 0,
        durationMs: 100,
        voiceProfileId: 'voice-ada',
      ),
      DialogueSentence(
        id: 's2',
        text: 'world',
        startMs: 100,
        durationMs: 50,
        dependsOnTempoOf: 's1',
        voiceProfileId: 'voice-ada',
      ),
      DialogueSentence(
        id: 's3',
        text: 'end',
        startMs: 150,
        durationMs: 40,
        voiceProfileId: 'voice-ada',
      ),
    ],
  );
}

void main() {
  test('unknown phonemes can be corrected and then transcribe', () {
    final lexicon = PhonemeLexicon({'h': 'HH', 'e': 'EH', 'l': 'L', 'o': 'OW'});
    expect(() => lexicon.transcribe('hello!'), code(phonemeUnknown));
    lexicon.correct('!', 'EXCL');
    expect(lexicon.transcribe('hello!'), ['HH', 'EH', 'L', 'L', 'OW', 'EXCL']);
  });

  test('spliced PCM duration and sample count match the plan at 24 kHz', () {
    final job = SpeechJob(
      id: 'job-1',
      plan: twoSentences(),
      backend: FakeSpeechBackend(),
    );
    final pcm = job.splice();
    final expected = twoSentences().sentences.fold<int>(0, (n, s) => n + s.sampleCount);
    expect(pcm.sampleRate, speechTargetHz);
    expect(pcm.samples.length, expected);
    expect(pcm.durationMs, 190);
    expect(expected, (190 * speechTargetHz) ~/ 1000);
  });

  test('changing one sentence only invalidates it and tempo dependents', () {
    final job = SpeechJob(
      id: 'job-1',
      plan: twoSentences(),
      backend: FakeSpeechBackend(),
    );
    job.splice();
    expect(job.cache.isFresh('s1'), isTrue);
    expect(job.cache.isFresh('s2'), isTrue);
    expect(job.cache.isFresh('s3'), isTrue);
    final s3 = job.cache.sentencePcm['s3']!;
    job.selectedAudioId = 'audio-take-1';
    job.updateSentenceText('s1', 'HELLO');
    expect(job.cache.isFresh('s1'), isFalse);
    expect(job.cache.isFresh('s2'), isFalse);
    expect(job.cache.isFresh('s3'), isTrue);
    expect(identical(job.cache.sentencePcm['s3'], s3), isTrue);
    expect(job.selectedAudioId, 'audio-take-1');
    final after = job.splice();
    expect(after.samples.length, (190 * speechTargetHz) ~/ 1000);
    expect(job.selectedAudioId, 'audio-take-1');
  });

  test('hand-tuned caption and clip locks are preserved', () {
    final job = SpeechJob(
      id: 'job-lock',
      plan: twoSentences(),
      backend: FakeSpeechBackend(),
      captionLocks: {const CaptionLock(sentenceId: 's1', revision: 3)},
      clipLocks: {const ClipLock(clipId: 'clip-hand', revision: 2)},
    );
    expect(() => job.updateSentenceText('s1', 'nope'), code(lockedCaption));
    expect(() => job.requireClipUnlocked('clip-hand'), code(lockedClip));
    expect(job.plan.sentence('s1').text, 'hello');
  });

  test('16 kHz backend output is resampled to 24 kHz', () {
    final sentence = DialogueSentence(
      id: 's1',
      text: 'hello',
      startMs: 0,
      durationMs: 1000,
    );
    final job = SpeechJob(
      id: 'job-resample',
      plan: DialoguePlan(id: 'plan-r', sentences: [sentence]),
      backend: FakeSpeechBackend(nativeSampleRate: 16000),
    );
    final pcm = job.renderSentence(sentence);
    expect(pcm.sampleRate, speechTargetHz);
    expect(pcm.samples.length, speechTargetHz);
  });

  test('TTS is not accepted as singing', () {
    expect(
      () => SpeechJob(
        id: 'job-sing',
        plan: twoSentences(),
        backend: FakeSpeechBackend(),
        mode: 'sing',
      ),
      code(ttsIsNotSinging),
    );
  });
}
