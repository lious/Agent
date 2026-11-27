import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_voice/studio_voice.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

void main() {
  test('Latin and CJK punctuation split into contiguous timed sentences', () {
    final plan = const SentenceSplitter().split(
      id: 'plan-split-1',
      text: 'Hello world. How are you? 你好。世界！',
      speed: 1.0,
    );
    expect([for (final s in plan.sentences) s.text], [
      'Hello world.',
      'How are you?',
      '你好。',
      '世界！',
    ]);
    expect(plan.sentences.first.startMs, 0);
    for (var i = 1; i < plan.sentences.length; i++) {
      final prev = plan.sentences[i - 1];
      expect(plan.sentences[i].startMs, prev.startMs + prev.durationMs);
    }
    expect(plan.sentences.every((s) => s.durationMs >= 80), isTrue);
  });

  test('empty text is refused and speed must be positive', () {
    const splitter = SentenceSplitter();
    expect(() => splitter.split(id: 'plan-x', text: '   '), code(sentenceInvalid));
    expect(
      () => splitter.split(id: 'plan-x', text: 'Hello.', speed: 0),
      code(sentenceInvalid),
    );
  });

  test('speed scales duration and a re-split keeps unchanged earlier sentence ids', () {
    const splitter = SentenceSplitter();
    final first = splitter.split(
      id: 'plan-split-2',
      text: 'First sentence. Second sentence.',
    );
    final faster = splitter.split(
      id: 'plan-split-2',
      text: 'First sentence. Second sentence.',
      speed: 2.0,
    );
    expect(faster.sentences[0].durationMs, first.sentences[0].durationMs ~/ 2);
    final edited = splitter.split(
      id: 'plan-split-2',
      text: 'First sentence. Second sentence changed.',
    );
    expect(edited.sentences[0].id, first.sentences[0].id);
    expect(edited.sentences[0].text, 'First sentence.');
    expect(edited.sentences[1].text, 'Second sentence changed.');
    expect(edited.sentences[1].id, isNot(first.sentences[1].id));
  });

  test('a split plan splices at 24 kHz with sample counts equal to the planned sum', () {
    final plan = const SentenceSplitter().split(
      id: 'plan-split-3',
      text: 'One. Two.',
    );
    final job = SpeechJob(
      id: 'job-split',
      plan: plan,
      backend: FakeSpeechBackend(),
    );
    final pcm = job.splice();
    final expected = plan.sentences.fold<int>(0, (n, s) => n + s.sampleCount);
    expect(pcm.sampleRate, speechTargetHz);
    expect(pcm.samples.length, expected);
  });
}
