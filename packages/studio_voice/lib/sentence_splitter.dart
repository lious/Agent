import 'package:studio_contracts/studio_contracts.dart';

import 'dialogue_plan.dart';
import 'voice_codes.dart';

/// Rule-based dialogue sentence splitter. This is not a linguistic parser
/// and not a TTS model. Unknown phonemes are left for [PhonemeLexicon].
final class SentenceSplitter {
  const SentenceSplitter({
    this.msPerUnit = 80,
    this.minDurationMs = 80,
  });

  final int msPerUnit, minDurationMs;

  static final _boundary = RegExp(r'([。！？.!?]+|\n+)');

  DialoguePlan split({
    required String id,
    required String text,
    double speed = 1.0,
    String? voiceProfileId,
  }) {
    requireId(id);
    if (speed <= 0) {
      throw const StudioException(sentenceInvalid, 'speed');
    }
    final raw = text.trim();
    if (raw.isEmpty) {
      throw const StudioException(sentenceInvalid, 'empty');
    }
    final parts = _parts(raw);
    if (parts.isEmpty) {
      throw const StudioException(sentenceInvalid, 'empty');
    }
    final sentences = <DialogueSentence>[];
    var cursor = 0;
    for (var i = 0; i < parts.length; i++) {
      final body = parts[i];
      final duration = _durationMs(body, speed);
      sentences.add(
        DialogueSentence(
          id: _sentenceId(i, body),
          text: body,
          startMs: cursor,
          durationMs: duration,
          speed: speed,
          voiceProfileId: voiceProfileId,
          dependsOnTempoOf: sentences.isEmpty ? null : sentences.last.id,
        ),
      );
      cursor += duration;
    }
    return DialoguePlan(id: id, sentences: sentences);
  }

  List<String> _parts(String text) {
    final out = <String>[];
    var start = 0;
    for (final match in _boundary.allMatches(text)) {
      final end = match.end;
      final chunk = text.substring(start, end).replaceAll('\n', ' ').trim();
      if (chunk.isNotEmpty && !_onlyPunctuation(chunk)) {
        out.add(chunk);
      }
      start = end;
    }
    final tail = text.substring(start).replaceAll('\n', ' ').trim();
    if (tail.isNotEmpty && !_onlyPunctuation(tail)) {
      out.add(tail);
    }
    return out;
  }

  bool _onlyPunctuation(String value) =>
      RegExp(r'^[。！？.!?]+$').hasMatch(value);

  int _durationMs(String body, double speed) {
    final units = body.runes.length;
    final raw = (msPerUnit * units / speed).round();
    return raw < minDurationMs ? minDurationMs : raw;
  }

  /// Stable for unchanged text at the same index; a rewritten sentence
  /// gets a different id so cached audio for the old text cannot be reused.
  static String _sentenceId(int index, String body) {
    var n = 2166136261;
    for (final cu in body.codeUnits) {
      n ^= cu;
      n = (n * 16777619) & 0xffffffff;
    }
    return 's${index + 1}-${n.toRadixString(16).padLeft(8, '0')}';
  }
}
