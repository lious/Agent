import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_generation/studio_generation.dart';
import 'package:test/test.dart';

/// Increment 2.57 official first I-040 slice: VideoGenerationProvider
/// async candidates and editable NLE insert. This file does not call a
/// paid API, does not invent a WorkflowCoordinator, does not claim
/// V-019, does not re-qualify I-033 or I-041 leftovers, does not start
/// I-035, does not invent I-013 job archival or an I-014 RestoreService
/// commit path, and does not mark I-037, I-038, V-007, V-020, I-054,
/// I-051, I-046, or I-041 complete. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('duplicate, unknown, late, and cancel paths do not double-bill; unknown is poll-only; late media is sandboxed and not auto-applied', () {
    final provider = VideoGenerationProvider();
    expect(provider.productionEnabled, isFalse);
    expect(provider.v019Claimed, isFalse);
    expect(provider.accountAutoConnected, isFalse);
    final first = provider.submit(
      GenerationRequest(idempotencyKey: 'key-a', mode: GenerationMode.i2v),
    );
    expect(first.state, CandidateState.submitted);
    expect(provider.postCount, 1);
    expect(provider.billCount, 1);
    provider.submit(
      GenerationRequest(idempotencyKey: 'key-a', mode: GenerationMode.i2v),
    );
    expect(provider.postCount, 1);
    expect(provider.billCount, 1);
    expect(
      () => provider.poll('key-a', rePost: true),
      code('UNKNOWN_NO_BLIND_RETRY'),
    );
    expect(provider.poll('key-a', rePost: false), CandidateState.submitted);
    expect(provider.postCount, 1);

    final late = provider.acceptLate('key-a');
    expect(late.state, CandidateState.quarantined);
    expect(late.autoApplied, isFalse);
    expect(provider.billCount, 1);

    final cancelled = provider.cancel('key-b', running: false);
    expect(cancelled.billCount, 1);
    expect(cancelled.hungOnTimeline, isFalse);
    expect(cancelled.refundPromised, isFalse);
    expect(cancelled.paidApiCalled, isFalse);
    expect(
      () => provider.cancel('key-a', running: true),
      code('FEATURE_NOT_IMPLEMENTED'),
    );
    expect(provider.paidApiCalled, isFalse);
    expect(provider.submitted, isFalse);
    expect(provider.documentWrites, 0);
  });

  test('one-shot and multi-shot inserts are editable clips, not a flat MP4; continuation keeps the original clip and audio and inserts only the suffix; uncertain splice and unapproved approx continuation are refused', () {
    final provider = VideoGenerationProvider();
    final one = provider.insertShots(1);
    expect(one.clips, hasLength(1));
    expect(one.clips.single.canTrim, isTrue);
    expect(one.flatMp4Only, isFalse);
    final multi = provider.insertShots(3);
    expect(multi.clips, hasLength(3));
    expect(multi.clips.every((c) => c.canTrim && !c.flatMp4Only), isTrue);

    // Input 3s prefix, duration 12 is the full length; bill 12, insert the new 9s.
    expect(provider.billedDuration(returnedTotalDuration: 12), 12);
    final continued = provider.insertContinuation(
      originalStart: 0,
      originalEnd: 10,
      contextPrefixDuration: 3,
      returnedTotalDuration: 12,
      lockedAudio: false,
    );
    expect(continued.duplicatePrefix, isFalse);
    expect(continued.originalAudioPreserved, isTrue);
    expect(continued.clips, hasLength(2));
    expect(continued.clips.first.id, 'clip-original');
    expect(continued.clips.last.id, 'clip-suffix');
    expect(continued.clips.last.start, 10);
    expect(continued.clips.last.end, 19);
    expect(continued.clips.every((c) => c.canTrim), isTrue);
    expect(
      () => provider.submit(
        GenerationRequest(
          idempotencyKey: 'key-splice',
          mode: GenerationMode.extend,
          autoSpliceUncertain: true,
        ),
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => provider.useApproxContinuation(approved: false),
      code('APPROVAL_REQUIRED'),
    );
    expect(
      () => provider.submit(
        GenerationRequest(
          idempotencyKey: 'key-fl',
          mode: GenerationMode.firstLast,
          profileInstalled: false,
        ),
      ),
      code('CAPABILITY_UNSUPPORTED'),
    );
    expect(
      () => provider.submit(
        GenerationRequest(
          idempotencyKey: 'key-style',
          mode: GenerationMode.restyle,
        ),
      ),
      code('UNVERIFIED_VIDEO_RESTYLE_PROFILE'),
    );
    expect(
      () => provider.submit(
        GenerationRequest(
          idempotencyKey: 'key-audio',
          mode: GenerationMode.i2v,
          inventAudioFalseOnWan27: true,
        ),
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(provider.documentWrites, 0);
  });

  test('locked original audio and hand-edited captions are not overwritten on insert', () {
    final provider = VideoGenerationProvider();
    expect(
      () => provider.insertContinuation(
        originalStart: 0,
        originalEnd: 10,
        contextPrefixDuration: 2,
        returnedTotalDuration: 8,
        lockedAudio: true,
        overwriteLocked: true,
      ),
      code('TRACK_LOCKED'),
    );
    expect(
      () => provider.insertContinuation(
        originalStart: 0,
        originalEnd: 10,
        contextPrefixDuration: 2,
        returnedTotalDuration: 8,
        lockedAudio: false,
        lockedCaptionIds: const ['cue-locked'],
        overwriteLocked: true,
      ),
      code('FIELD_LOCKED'),
    );
    final kept = provider.insertContinuation(
      originalStart: 0,
      originalEnd: 10,
      contextPrefixDuration: 2,
      returnedTotalDuration: 8,
      lockedAudio: true,
      lockedCaptionIds: const ['cue-locked'],
    );
    expect(kept.originalAudioPreserved, isTrue);
    expect(kept.clips.first.start, 0);
    expect(kept.clips.first.end, 10);
    expect(kept.documentWrites, 0);
    expect(provider.submitted, isFalse);
    expect(provider.paidApiCalled, isFalse);
  });
}
