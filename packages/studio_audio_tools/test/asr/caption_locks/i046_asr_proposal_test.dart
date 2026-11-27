import 'package:studio_audio_tools/studio_audio_tools.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

/// Increment 2.55 official first I-046 slice: ASR CaptionProposal
/// refusals. This file does not invent a real ASR engine, does not
/// claim on-device inference or V-009 qualification, does not start
/// cloud ASR, does not default to diarization or stem separation, does
/// not rewrite I-010 caption-table leftovers, does not invent a
/// TrimPlanner, does not re-qualify I-051, I-054, or I-029, does not
/// start I-035, and does not mark I-037, I-038, V-007, V-020, I-054,
/// or I-051 complete. InversePatch kind stays restoreSnapshot. Project
/// user_version stays 9.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('silence or music suspected hallucinations are not auto-accepted; noAudio does not invent a transcript; diarization and cloud ASR are refused; inference is not claimed', () {
    final job = TranscriptionJob();
    final silence = job.transcribe(
      AsrSpec(
        sourceRef: 'audio-1',
        windows: [
          AsrWindow(
            startSample: 0,
            endSample: asrWindowSamples,
            kind: AsrWindowKind.silence,
            text: 'invented-line',
          ),
          AsrWindow(
            startSample: asrHopSamples,
            endSample: asrHopSamples + asrWindowSamples,
            kind: AsrWindowKind.music,
            text: 'la-la-la',
            repetitive: true,
          ),
        ],
      ),
    );
    expect(silence.autoAccepted, isFalse);
    expect(silence.realInferenceClaimed, isFalse);
    expect(silence.diarizationEnabled, isFalse);
    expect(silence.cloudAsrStarted, isFalse);
    expect(silence.submitted, isFalse);
    expect(silence.cues.every((c) => c.suspectedHallucination), isTrue);
    expect(silence.cues.every((c) => c.text.isEmpty), isTrue);
    expect(silence.cues.every((c) => c.speakerId == null), isTrue);
    expect(
      () => job.accept(
        proposal: silence,
        expectedRevision: 1,
        autoAcceptHallucinations: true,
      ),
      code('HALLUCINATION_NOT_AUTO_ACCEPTED'),
    );

    final empty = job.transcribe(AsrSpec(sourceRef: 'audio-2', noAudio: true));
    expect(empty.cues, isEmpty);
    expect(empty.autoAccepted, isFalse);
    expect(
      () => job.transcribe(
        AsrSpec(sourceRef: 'audio-3', requestDiarization: true),
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () =>
          job.transcribe(AsrSpec(sourceRef: 'audio-4', requestCloudAsr: true)),
      code('TOOL_NOT_ALLOWED'),
    );
    expect(job.documentWrites, 0);
  });

  test(
    'locked or hand-edited cues are not overwritten on transcribe or accept',
    () {
      final job = TranscriptionJob();
      final proposal = job.transcribe(
        AsrSpec(
          sourceRef: 'audio-5',
          lockedCues: [
            LockedCue(
              id: 'cue-locked',
              text: 'hand-edited line',
              startSample: 0,
              endSample: asrSampleRate * 2,
            ),
          ],
          windows: [
            AsrWindow(
              startSample: 0,
              endSample: asrWindowSamples,
              kind: AsrWindowKind.speech,
              text: 'model would overwrite this',
            ),
          ],
        ),
      );
      expect(proposal.cues, isEmpty);
      expect(proposal.documentWrites, 0);
      expect(proposal.submitted, isFalse);

      final unlocked = job.transcribe(
        AsrSpec(
          sourceRef: 'audio-6',
          windows: [
            AsrWindow(
              startSample: 0,
              endSample: asrWindowSamples,
              kind: AsrWindowKind.speech,
              text: 'new line',
            ),
          ],
        ),
      );
      expect(unlocked.cues, hasLength(1));
      expect(unlocked.cues.single.text, 'new line');
      expect(
        () => job.accept(
          proposal: unlocked,
          expectedRevision: 3,
          lockedCueIds: [unlocked.cues.single.id],
        ),
        code('FIELD_LOCKED'),
      );
      job.accept(proposal: unlocked, expectedRevision: 3);
      expect(job.plannedRevision, 4);
      expect(job.documentWrites, 0);
    },
  );

  test('overlapping 30s/29s windows dedup identical time and text, keep conflicting evidence without inventing a sentence, and a deleted source or late cancel does not hang a cue', () {
    final job = TranscriptionJob();
    final firstStart = 0;
    final secondStart = asrHopSamples;
    final deduped = job.transcribe(
      AsrSpec(
        sourceRef: 'audio-7',
        windows: [
          AsrWindow(
            startSample: firstStart,
            endSample: firstStart + asrWindowSamples,
            kind: AsrWindowKind.speech,
            text: 'same line',
          ),
          AsrWindow(
            startSample: secondStart,
            endSample: secondStart + asrWindowSamples,
            kind: AsrWindowKind.speech,
            text: 'same line',
          ),
        ],
      ),
    );
    expect(asrWindowSamples - asrHopSamples, asrSampleRate);
    expect(deduped.cues, hasLength(1));
    expect(deduped.cues.single.text, 'same line');

    final conflicted = job.transcribe(
      AsrSpec(
        sourceRef: 'audio-8',
        windows: [
          AsrWindow(
            startSample: firstStart,
            endSample: firstStart + asrWindowSamples,
            kind: AsrWindowKind.speech,
            text: 'first wording',
          ),
          AsrWindow(
            startSample: secondStart,
            endSample: secondStart + asrWindowSamples,
            kind: AsrWindowKind.speech,
            text: 'second wording',
          ),
        ],
      ),
    );
    expect(conflicted.cues, hasLength(2));
    expect(conflicted.cues.last.conflictWithId, conflicted.cues.first.id);
    expect(
      conflicted.cues.map((c) => c.text).toSet(),
      equals({'first wording', 'second wording'}),
    );
    expect(
      conflicted.cues.any((c) => c.text.contains('first wording second')),
      isFalse,
    );

    final deleted = job.transcribe(
      AsrSpec(
        sourceRef: 'audio-9',
        sourceDeleted: true,
        windows: [
          AsrWindow(
            startSample: 0,
            endSample: asrWindowSamples,
            kind: AsrWindowKind.speech,
            text: 'late line',
          ),
        ],
      ),
    );
    expect(deleted.cues, isEmpty);
    expect(deleted.hungCues, 0);
    job.attachLate(deleted);
    expect(job.lateResultAttached, isFalse);
    expect(
      () => job.accept(proposal: deleted, expectedRevision: 1),
      code('SOURCE_DELETED'),
    );

    final cancelled = job.transcribe(
      AsrSpec(
        sourceRef: 'audio-10',
        cancelled: true,
        windows: [
          AsrWindow(
            startSample: 0,
            endSample: asrWindowSamples,
            kind: AsrWindowKind.speech,
            text: 'late line',
          ),
        ],
      ),
    );
    expect(cancelled.cues, isEmpty);
    expect(cancelled.hungCues, 0);
    job.attachLate(cancelled);
    expect(job.lateResultAttached, isFalse);
    expect(
      () => job.accept(proposal: cancelled, expectedRevision: 1),
      code('PROPOSAL_CANCELLED'),
    );
    expect(job.documentWrites, 0);
    expect(job.lateResultAttached, isFalse);
  });
}
