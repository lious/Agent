import 'package:studio_contracts/studio_contracts.dart';

import 'voice_codes.dart';

const speechTargetHz = 24000;

final class DialogueSentence {
  DialogueSentence({
    required this.id,
    required this.text,
    required this.startMs,
    required this.durationMs,
    this.phonemes = const [],
    this.speed = 1.0,
    this.voiceProfileId,
    this.dependsOnTempoOf,
  }) {
    requireId(id);
    if (durationMs <= 0 || startMs < 0) {
      throw StudioException(sentenceInvalid, id);
    }
    if (speed <= 0) {
      throw StudioException(sentenceInvalid, 'speed');
    }
    if (voiceProfileId != null) requireId(voiceProfileId!);
    if (dependsOnTempoOf != null) requireId(dependsOnTempoOf!);
  }

  final String id, text;
  final int startMs, durationMs;
  final List<String> phonemes;
  final double speed;
  final String? voiceProfileId;
  final String? dependsOnTempoOf;

  int get sampleCount => (durationMs * speechTargetHz) ~/ 1000;
}

final class DialoguePlan {
  DialoguePlan({
    required this.id,
    required List<DialogueSentence> sentences,
    this.targetHz = speechTargetHz,
  }) : sentences = List.unmodifiable(sentences) {
    requireId(id);
    if (targetHz != speechTargetHz) {
      // Plans are always resolved to 24 kHz; other rates are resampled later.
    }
  }

  final String id;
  final List<DialogueSentence> sentences;
  final int targetHz;

  DialogueSentence sentence(String id) =>
      sentences.firstWhere((s) => s.id == id, orElse: () {
        throw StudioException(sentenceInvalid, id);
      });
}

/// Grapheme-to-phoneme lexicon. Unknown symbols can be corrected.
final class PhonemeLexicon {
  PhonemeLexicon([Map<String, String>? seed])
    : _map = {...?seed};

  final Map<String, String> _map;

  void correct(String grapheme, String phoneme) {
    if (grapheme.isEmpty || phoneme.isEmpty) {
      throw const StudioException(phonemeUnknown, 'empty');
    }
    _map[grapheme] = phoneme;
  }

  String lookup(String grapheme) {
    final value = _map[grapheme];
    if (value == null) {
      throw StudioException(phonemeUnknown, grapheme);
    }
    return value;
  }

  List<String> transcribe(String text) {
    final out = <String>[];
    for (final rune in text.runes) {
      final g = String.fromCharCode(rune);
      if (g.trim().isEmpty) continue;
      out.add(lookup(g));
    }
    return out;
  }
}
