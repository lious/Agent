import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_vertical/studio_vertical.dart';
import 'package:test/test.dart';

/// Increment 2.62 official first I-039 slice: AnimaticBuilder 15s
/// four-shot duration, dependency invalidation, 2.5D degradation, and
/// no fake TTS. This file does not invent a WorkflowCoordinator, a
/// real TTS engine, or paid generation, does not start quote/apply or
/// SQL vertical.v1, does not invent IntentReducer or DependencyIndex
/// as a product surface, does not rewrite I-038 compilers or
/// change_dependency tests, does not start I-035 or claim a V-020
/// narrative-qa / precision-recall achievement, does not re-qualify
/// I-052, I-040, I-033, I-057, I-037, I-056, I-054, or I-029, and
/// does not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046,
/// I-041, I-040, I-053, I-056, I-057, or I-052 complete. InversePatch
/// kind stays restoreSnapshot. Project user_version stays 9.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('the official 15-second four-shot animatic has exact frame ranges and does not submit paid generation before confirmation', () {
    final builder = AnimaticBuilder();
    final built = builder.build(officialFifteenSecondShots());
    expect(built.totalDurationFrames, 360);
    expect(built.totalDurationSeconds, 15);
    expect(built.shots.map((s) => [s.id, s.startFrame, s.endFrame]), [
      ['S1', 0, 72],
      ['S2', 72, 168],
      ['S3', 168, 264],
      ['S4', 264, 360],
    ]);
    expect(built.shots[0].strategy, ShotStrategy.panZoom2d);
    expect(built.shots[0].strategy, isNot(ShotStrategy.layered25d));
    expect(built.shots[1].dialogueSamples, 105600);
    expect(built.shots[3].dialogueSamples, 67200);
    expect(builder.submitted, isFalse);
    expect(builder.paidGeneration, isFalse);
    expect(builder.documentWrites, 0);
    expect(builder.ttsEngineInvented, isFalse);
    expect(builder.workflowCoordinatorInvented, isFalse);
    expect(builder.v020NarrativeQaClaimed, isFalse);
  });

  test('changing the lead or deleting a shot invalidates only dependents; sources and paid jobs are kept; a library upgrade does not replace the frozen pin', () {
    final builder = AnimaticBuilder();
    final shots = officialFifteenSecondShots();
    final lead = builder.invalidate(shots, newLeadId: 'qinghe');
    expect(lead.staleShotIds, ['S2', 'S3']);
    expect(lead.staleShotIds, isNot(contains('S1')));
    expect(lead.staleShotIds, isNot(contains('S4')));
    expect(lead.sourceDeleted, isFalse);
    expect(lead.paidJobWithdrawn, isFalse);

    final removed = builder.invalidate(
      shots,
      removedShotId: 'S4',
      targetTotalFrames: 288,
    );
    expect(removed.shots.map((s) => s.id), ['S1', 'S2', 'S3']);
    expect(removed.totalDurationFrames, 288);
    expect(removed.holdLastFrameProposed, isTrue);
    expect(removed.fpsUnchanged, isTrue);
    expect(removed.sourceDeleted, isFalse);
    expect(removed.paidJobWithdrawn, isFalse);
    expect(removed.shots[1].lockedCaption, isTrue);

    final dialogue = builder.invalidate(shots, changedDialogueShotId: 'S2');
    expect(dialogue.staleShotIds, ['S2']);
    expect(dialogue.shots[2].id, 'S3');
    expect(dialogue.shots[0].id, 'S1');

    final upgraded = builder.invalidate(shots, libraryCharacterVersion: 'v4');
    expect(upgraded.characterPinVersion, 'v3');
    expect(builder.submitted, isFalse);
    expect(builder.paidGeneration, isFalse);
  });

  test('missing 2.5D assets are not disguised as 2.5D; unselected TTS is an unvoiced preview; overflow is not sped up', () {
    final builder = AnimaticBuilder();
    final incomplete = officialFifteenSecondShots(s2LayeredAssets: false);
    final blocked = builder.build(incomplete);
    expect(blocked.fallbackProposals, ['S2']);
    expect(blocked.shots[1].layeredAssetsComplete, isFalse);
    expect(
      () => builder.build(incomplete, forceClaim25d: true),
      code('BLOCKED_LAYER_ASSETS'),
    );
    expect(
      () => builder.build(officialFifteenSecondShots(), silentDegrade: true),
      code('STRATEGY_PREREQUISITE_MISSING'),
    );

    final silent = builder.build(officialFifteenSecondShots());
    expect(silent.voiced, isFalse);
    expect(silent.label, '未配音预演');
    expect(silent.requiresVoicedStageSelection, isTrue);
    expect(silent.voicedApproved, isFalse);
    expect(
      () => builder.build(
        officialFifteenSecondShots(),
        treatSilentAsVoicedApproval: true,
      ),
      code('ANIMATIC_APPROVAL_STALE'),
    );

    final voiced = builder.build(
      officialFifteenSecondShots(),
      ttsSelected: true,
      userConfirmed: true,
    );
    expect(voiced.voiced, isTrue);
    expect(voiced.voicedApproved, isTrue);
    expect(builder.ttsEngineInvented, isFalse);

    expect(
      () =>
          builder.build(officialFifteenSecondShots(s2DialogueSamples: 200000)),
      code('DIALOGUE_OVERFLOW'),
    );
    expect(builder.speedChanged, isFalse);
    expect(
      () => builder.build(
        officialFifteenSecondShots(s2DialogueSamples: 200000),
        speedUpOverflow: true,
      ),
      code('FRAME_CONSTRAINT_UNSUPPORTED'),
    );
    expect(
      () => builder.build(officialFifteenSecondShots(), changeFpsToFit: true),
      code('FRAME_CONSTRAINT_UNSUPPORTED'),
    );
  });
}
