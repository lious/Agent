import 'dart:typed_data';

import 'dialogue_plan.dart';
import 'speech_job.dart';

/// Deterministic non-neural backend. Sample values are a hash of the
/// sentence text so splice tests can detect stale cache hits.
final class FakeSpeechBackend implements SpeechBackend {
  FakeSpeechBackend({this.nativeSampleRate = speechTargetHz});

  final int nativeSampleRate;

  @override
  PcmBuffer synthesize(DialogueSentence sentence, {required int sampleRate}) {
    final rate = nativeSampleRate;
    final count = (sentence.durationMs * rate) ~/ 1000;
    final samples = Int16List(count);
    final seed = _hash(sentence.text);
    for (var i = 0; i < count; i++) {
      // Quiet deterministic tone, amplitude well below clipping.
      final phase = (i * (seed % 97 + 13)) & 0xffff;
      samples[i] = (((phase - 32768) * 8) / 256).round().clamp(-4096, 4096);
    }
    return PcmBuffer(rate, samples);
  }

  static int _hash(String text) {
    var n = 2166136261;
    for (final cu in text.codeUnits) {
      n ^= cu;
      n = (n * 16777619) & 0xffffffff;
    }
    return n;
  }
}
