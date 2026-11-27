import 'dart:typed_data';

import 'package:studio_contracts/studio_contracts.dart';

import 'dialogue_plan.dart';
import 'voice_codes.dart';
import 'voice_consent.dart';

/// Tiny synthetic PCM helper. This is not a TTS model.
final class PcmBuffer {
  PcmBuffer(this.sampleRate, this.samples);

  final int sampleRate;
  final Int16List samples;

  int get durationMs => (samples.length * 1000) ~/ sampleRate;
}

abstract interface class SpeechBackend {
  /// Synthesize one sentence. Official tests use deterministic PCM derived
  /// from a text hash, not a neural voice.
  PcmBuffer synthesize(DialogueSentence sentence, {required int sampleRate});
}

final class CaptionLock {
  const CaptionLock({required this.sentenceId, required this.revision});
  final String sentenceId;
  final int revision;
}

final class ClipLock {
  const ClipLock({required this.clipId, required this.revision});
  final String clipId;
  final int revision;
}

final class SpeechCache {
  final Map<String, PcmBuffer> sentencePcm = {};
  final Set<String> stale = {};

  bool isFresh(String sentenceId) =>
      sentencePcm.containsKey(sentenceId) && !stale.contains(sentenceId);
}

/// Plans and splices sentence audio. Changing one sentence only invalidates
/// that sentence and tempo dependents. Hand-tuned caption and clip locks
/// are preserved. An already-selected audio id is never overwritten.
final class SpeechJob {
  SpeechJob({
    required this.id,
    required this.plan,
    required this.backend,
    this.consent,
    this.mode = 'speech',
    Set<CaptionLock>? captionLocks,
    Set<ClipLock>? clipLocks,
  }) : captionLocks = {...?captionLocks},
       clipLocks = {...?clipLocks} {
    requireId(id);
    if (mode == 'sing') {
      throw const StudioException(ttsIsNotSinging);
    }
  }

  final String id, mode;
  DialoguePlan plan;
  final SpeechBackend backend;
  final VoiceConsentLedger? consent;
  final Set<CaptionLock> captionLocks;
  final Set<ClipLock> clipLocks;
  final SpeechCache cache = SpeechCache();
  String? selectedAudioId;

  void _requireVoice(DialogueSentence sentence) {
    final voice = sentence.voiceProfileId;
    if (voice == null) return;
    if (consent != null && consent!.isRevoked(voice)) {
      throw StudioException(voicePinRevoked, voice);
    }
  }

  PcmBuffer renderSentence(DialogueSentence sentence) {
    _requireVoice(sentence);
    final pcm = backend.synthesize(sentence, sampleRate: speechTargetHz);
    final resolved = pcm.sampleRate == speechTargetHz
        ? pcm
        : resampleLinear(pcm, speechTargetHz);
    cache.sentencePcm[sentence.id] = resolved;
    cache.stale.remove(sentence.id);
    return resolved;
  }

  /// Concatenate sentence PCM in plan order. Total samples equal the sum
  /// of planned sentence sample counts after a full 24 kHz render.
  PcmBuffer splice() {
    final parts = <int>[];
    for (final sentence in plan.sentences) {
      final pcm = cache.isFresh(sentence.id)
          ? cache.sentencePcm[sentence.id]!
          : renderSentence(sentence);
      parts.addAll(pcm.samples);
    }
    return PcmBuffer(speechTargetHz, Int16List.fromList(parts));
  }

  /// Rewrite one sentence. Locked captions/clips are left untouched.
  /// Tempo dependents are marked stale; unrelated cached sentences stay.
  void updateSentenceText(String sentenceId, String text) {
    if (captionLocks.any((l) => l.sentenceId == sentenceId)) {
      throw StudioException(lockedCaption, sentenceId);
    }
    final next = <DialogueSentence>[];
    var found = false;
    for (final s in plan.sentences) {
      if (s.id == sentenceId) {
        found = true;
        next.add(
          DialogueSentence(
            id: s.id,
            text: text,
            startMs: s.startMs,
            durationMs: s.durationMs,
            phonemes: s.phonemes,
            speed: s.speed,
            voiceProfileId: s.voiceProfileId,
            dependsOnTempoOf: s.dependsOnTempoOf,
          ),
        );
        cache.stale.add(s.id);
        cache.sentencePcm.remove(s.id);
      } else {
        next.add(s);
        if (s.dependsOnTempoOf == sentenceId) {
          cache.stale.add(s.id);
        }
      }
    }
    if (!found) throw StudioException(sentenceInvalid, sentenceId);
    plan = DialoguePlan(id: plan.id, sentences: next);
    // Dialogue changes must not overwrite an already-selected audio clip.
  }

  void requireClipUnlocked(String clipId) {
    if (clipLocks.any((l) => l.clipId == clipId)) {
      throw StudioException(lockedClip, clipId);
    }
  }
}

PcmBuffer resampleLinear(PcmBuffer input, int targetHz) {
  if (input.sampleRate == targetHz) return input;
  final outLen = (input.samples.length * targetHz) ~/ input.sampleRate;
  final out = Int16List(outLen);
  for (var i = 0; i < outLen; i++) {
    final src = i * input.sampleRate / targetHz;
    final i0 = src.floor().clamp(0, input.samples.length - 1);
    final i1 = (i0 + 1).clamp(0, input.samples.length - 1);
    final frac = src - i0;
    final s0 = input.samples[i0];
    final s1 = input.samples[i1];
    out[i] = (s0 + (s1 - s0) * frac).round().clamp(-32768, 32767);
  }
  return PcmBuffer(targetHz, out);
}
