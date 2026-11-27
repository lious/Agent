import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_generation/studio_generation.dart';
import 'package:test/test.dart';

/// Increment 2.56 official first I-041 slice: MusicProvider profile
/// refusals, BeatGrid snap, and duck proposals. This file does not run
/// real ACE/YuE inference, does not call a paid API, does not invent a
/// limiter, does not claim V-016/V-017/V-018, does not re-qualify I-009
/// bus/gain leftovers or I-033 reconciler leftovers, does not start
/// I-035, does not invent I-013 job archival or an I-014 RestoreService
/// commit path, and does not mark I-037, I-038, V-007, V-020, I-054,
/// I-051, or I-046 complete. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

MusicProviderCompiler compiler() => MusicProviderCompiler(
  profiles: {
    'ace-turbo': MusicProfile(
      id: 'ace-turbo',
      runtime: MusicRuntime.aceService,
      installed: true,
      baseOnlyTasks: {MusicTask.extract, MusicTask.lego, MusicTask.complete},
    ),
    'yue2': MusicProfile(
      id: 'yue2',
      runtime: MusicRuntime.yuePythonWorker,
      installed: false,
      stemSupportNative: false,
    ),
    'sa-small': MusicProfile(
      id: 'sa-small',
      runtime: MusicRuntime.liteRtLocal,
      installed: true,
    ),
  },
);

void main() {
  test('ACE can be planned without YuE2; unsupported Turbo tasks, YuE stems, voice clone, ABC scripts, fractional BPM, and unsupported meters are refused', () {
    final music = compiler();
    expect(music.isEnabled('ace-turbo'), isTrue);
    expect(music.isEnabled('yue2'), isFalse);
    final plan = music.plan(
      MusicSpec(profileId: 'ace-turbo', bpm: 120, meter: '4/4'),
    );
    expect(plan.profileId, 'ace-turbo');
    expect(plan.licenseGranted, isFalse);
    expect(plan.licenseWarning, isTrue);
    expect(plan.paidApiCalled, isFalse);
    expect(plan.submitted, isFalse);
    expect(plan.v016Claimed, isFalse);
    expect(plan.v018Claimed, isFalse);
    expect(plan.documentWrites, 0);

    expect(
      () => music.plan(
        MusicSpec(profileId: 'ace-turbo', task: MusicTask.extract),
      ),
      code('CAPABILITY_UNSATISFIED'),
    );
    expect(
      () => music.plan(MusicSpec(profileId: 'yue2', requestNativeStems: true)),
      code('MODEL_UNAVAILABLE'),
    );
    final withYue = MusicProviderCompiler(
      profiles: {
        ...music.profiles,
        'yue2': MusicProfile(
          id: 'yue2',
          runtime: MusicRuntime.yuePythonWorker,
          installed: true,
          stemSupportNative: false,
        ),
      },
    );
    expect(
      () =>
          withYue.plan(MusicSpec(profileId: 'yue2', requestNativeStems: true)),
      code('STEM_CAPABILITY_UNAVAILABLE'),
    );
    expect(
      () =>
          withYue.plan(MusicSpec(profileId: 'yue2', characterVoiceClone: true)),
      code('TOOL_NOT_ALLOWED'),
    );
    expect(
      () => music.plan(MusicSpec(profileId: 'ace-turbo', abcLoadsUrl: true)),
      code('TOOL_NOT_ALLOWED'),
    );
    expect(
      () => music.plan(MusicSpec(profileId: 'ace-turbo', bpm: 120.5)),
      code('BPM_INTEGER_REQUIRED'),
    );
    expect(
      () => music.plan(MusicSpec(profileId: 'ace-turbo', meter: '5/4')),
      code('CAPABILITY_UNSATISFIED'),
    );
    expect(
      () => music.plan(
        MusicSpec(
          profileId: 'ace-turbo',
          requestTranscription: true,
          transcriberInstalled: false,
        ),
      ),
      code('TRANSCRIBER_UNAVAILABLE'),
    );
  });

  test('beat snap stays within 1 sample of a declared integer grid; duck proposals do not rewrite manual gain or invent a limiter; locked tracks are refused', () {
    final music = compiler();
    final grid = BeatGrid(events: const [0, 24000, 48000, 72000]);
    expect(music.snapToGrid(sample: 24000, grid: grid), 24000);
    expect(music.snapToGrid(sample: 24001, grid: grid), 24000);
    expect(
      (music.snapToGrid(sample: 23999, grid: grid) - 24000).abs(),
      lessThanOrEqualTo(1),
    );
    expect(
      () => music.snapToGrid(
        sample: 100,
        grid: BeatGrid(events: const [0], uncertain: true),
      ),
      code('CAPABILITY_UNSATISFIED'),
    );

    const manual = [(sample: 192000, gainDb: -3.0)];
    final duck = music.proposeDuck(
      trackLocked: false,
      gainLocked: false,
      manualGainPoints: manual,
      speechRanges: const [(startSample: 48000, endSample: 96000)],
    );
    expect(duck.preservedManualGainPoints, manual);
    expect(duck.manualGainRewritten, isFalse);
    expect(duck.autoApplied, isFalse);
    expect(duck.limiterInvented, isFalse);
    expect(duck.voOrCaptionOverwritten, isFalse);
    expect(duck.documentWrites, 0);
    expect(
      () => music.proposeDuck(
        trackLocked: true,
        gainLocked: false,
        manualGainPoints: manual,
      ),
      code('TRACK_LOCKED'),
    );
    expect(
      () => music.proposeDuck(
        trackLocked: false,
        gainLocked: true,
        manualGainPoints: manual,
      ),
      code('MANUAL_LOCKED'),
    );
    expect(music.documentWrites, 0);
  });

  test('a late cancel accounts the fee and isolates the candidate without hanging it on the timeline or calling a paid API; unapproved paid generation is refused', () {
    final music = compiler();
    final report = music.lateCancel(settledFeeMicros: 40);
    expect(report.feeAccountedMicros, 40);
    expect(report.quarantined, isTrue);
    expect(report.hungOnTimeline, isFalse);
    expect(report.refundPromised, isFalse);
    expect(report.paidApiCalled, isFalse);
    expect(() => music.submitPaid(approved: false), code('APPROVAL_REQUIRED'));
    expect(music.documentWrites, 0);
  });
}
