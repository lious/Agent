import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_vertical/studio_vertical.dart';
import 'package:test/test.dart';

/// Increment 2.48 official I-038 leftover s8m change-dependency and
/// locked-field invalidation bound. This file does not invent
/// IntentReducer or DependencyIndex as a product surface, does not
/// start quote/apply, paid generation, or SQL vertical.v1, does not
/// invent motion capture or new child-related surfaces, does not
/// invent a PlanGraph manual-lock API, does not mark I-037 or I-038
/// complete, and does not rewrite the Increment 2.42–2.47 suites or
/// the frozen I-036 fts5Enabled==false assertions.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

const appearanceA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const appearanceB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const factA =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const factB =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const analysisS1 =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const promptS2 =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const candidateS2 =
    '1111111111111111111111111111111111111111111111111111111111111111';
const promptS4 =
    '2222222222222222222222222222222222222222222222222222222222222222';
const candidateS4 =
    '3333333333333333333333333333333333333333333333333333333333333333';

ShotNode s1Desktop() => ShotNode(
  id: 's1',
  clipId: 'clip-s1',
  analysisHash: analysisS1,
  timelineDuration: 4,
);

ShotNode s2Proof({bool handmade = true}) => ShotNode(
  id: 's2',
  clipId: 'clip-s2',
  appearanceHash: appearanceA,
  promptHash: promptS2,
  candidateHash: candidateS2,
  acceptedHandmade: handmade,
  timelineDuration: 7,
  generatedDuration: 8,
  sourceIn: 0.5,
  sourceOut: 7.0,
);

ShotNode s3Cta() =>
    ShotNode(id: 's3', clipId: 'clip-s3', factHash: factA, timelineDuration: 4);

ShotNode storyShot({
  required String id,
  required double duration,
  String? promptHash,
  String? candidateHash,
  String? causalRole,
  bool handmade = false,
  double? sourceIn,
  double? sourceOut,
  double? generatedDuration,
}) => ShotNode(
  id: id,
  clipId: 'clip-$id',
  promptHash: promptHash,
  candidateHash: candidateHash,
  acceptedHandmade: handmade,
  timelineDuration: duration,
  generatedDuration: generatedDuration,
  sourceIn: sourceIn,
  sourceOut: sourceOut,
  causalRole: causalRole,
);

ChangeDependencyRequest caseA({
  int? readSetRevision,
  String confirmedPrice = '69',
  String? lockedCaption,
  bool durationProposalConfirmed = true,
  bool deleteOldGap = true,
  bool stretchLockedAudio = false,
  double? lockedMusicDuration,
  bool explicitMusicTrim = false,
  double? explicitDeliveryRange,
  double? replacementSourceDuration,
  bool reuseCacheWithDeletedSku = false,
}) => ChangeDependencyRequest(
  shots: [s1Desktop(), s2Proof(), s3Cta()],
  currentRevision: 32,
  readSetRevision: readSetRevision,
  fromSku: 'sku-A@1',
  toSku: 'sku-B@1',
  fromAppearanceHash: appearanceA,
  toAppearanceHash: appearanceB,
  fromFactHash: factA,
  toFactHash: factB,
  confirmedPrice: confirmedPrice,
  fromDuration: 15,
  toDuration: 12,
  locks: [
    if (lockedCaption != null)
      LockedField(
        kind: LockedFieldKind.caption,
        targetId: 's2',
        text: lockedCaption,
      ),
    LockedField(
      kind: LockedFieldKind.sourceRange,
      targetId: 's2',
      start: 0.5,
      end: 7.0,
    ),
    LockedField(kind: LockedFieldKind.title, targetId: 'sequence'),
    LockedField(kind: LockedFieldKind.overlayFact, targetId: 's3', text: '79'),
  ],
  durationProposalConfirmed: durationProposalConfirmed,
  proposedDurations: const {'s1': 2.5, 's2': 6.5, 's3': 3},
  gapDuration: 0.5,
  deleteOldGap: deleteOldGap,
  lockedMusicDuration: lockedMusicDuration,
  explicitMusicTrim: explicitMusicTrim,
  explicitDeliveryRange: explicitDeliveryRange,
  stretchLockedAudio: stretchLockedAudio,
  replacementSourceDuration: replacementSourceDuration,
  reuseCacheWithDeletedSku: reuseCacheWithDeletedSku,
);

void main() {
  test('SKU and duration change invalidates S2 appearance and S3 fact overlay, keeps the handmade S2 range and clip, and does not stale S1 or submit', () {
    final compiler = ChangeDependencyCompiler();
    final program = compiler.compile(caseA(lockedCaption: '轻装也从容'));
    expect(program.submitted, isFalse);
    expect(program.documentWrites, 0);
    expect(program.paidGenerationStarted, isFalse);
    expect(program.quoteOrApplyStarted, isFalse);
    expect(program.lateArrivalAutoApplied, isFalse);
    expect(program.manualFieldsAutoDeleted, isFalse);
    expect(program.needsDurationConfirmation, isFalse);
    expect(program.gapDeleted, isTrue);
    expect(program.totalDuration, 12);

    final s1 = program.shots.singleWhere((s) => s.shotId == 's1');
    final s2 = program.shots.singleWhere((s) => s.shotId == 's2');
    final s3 = program.shots.singleWhere((s) => s.shotId == 's3');
    expect(s1.promptStale, isFalse);
    expect(s1.candidateStale, isFalse);
    expect(s1.analysisStale, isFalse);
    expect(s1.timelineDuration, 2.5);
    expect(s2.promptStale, isTrue);
    expect(s2.candidateStale, isTrue);
    expect(s2.kind, StaleKind.handmadeAvailableForRedo);
    expect(s2.clipId, 'clip-s2');
    expect(s2.clipObjectReplaced, isFalse);
    expect(s2.keptSourceIn, 0.5);
    expect(s2.keptSourceOut, 7.0);
    expect(s2.generatedDuration, 8);
    expect(s2.timelineDuration, 6.5);
    expect(s2.keptCaption, '轻装也从容');
    expect(s3.factOverlayStale, isTrue);
    expect(s3.promptStale, isFalse);
    expect(s3.timelineDuration, 3);

    final waiting = compiler.compile(caseA(durationProposalConfirmed: false));
    expect(waiting.needsDurationConfirmation, isTrue);
    expect(waiting.gapDeleted, isFalse);
    expect(waiting.totalDuration, 15);
    expect(
      waiting.shots.singleWhere((s) => s.shotId == 's1').timelineDuration,
      4,
    );
    expect(waiting.submitted, isFalse);
    expect(compiler.documentWrites, 0);
  });

  test('a locked caption price conflict, a locked music tail, a short replacement source, a CAS mismatch, stretching locked audio, and a resurrected cache entry are refused and do not submit', () {
    final compiler = ChangeDependencyCompiler();
    expect(
      () => compiler.compile(caseA(lockedCaption: '轻装也从容 79元')),
      code(factBindingConflict),
    );
    expect(
      () => compiler.compile(caseA(lockedMusicDuration: 16)),
      code(fieldLocked),
    );
    final delivery = compiler.compile(
      caseA(lockedMusicDuration: 16, explicitDeliveryRange: 12),
    );
    expect(delivery.musicLockUnchanged, isTrue);
    expect(delivery.deliveryRange, 12);
    expect(delivery.submitted, isFalse);
    expect(
      () => compiler.compile(caseA(replacementSourceDuration: 6.0)),
      code(parameterRange),
    );
    expect(
      () => compiler.compile(caseA(readSetRevision: 31)),
      code(revisionConflict),
    );
    expect(
      () => compiler.compile(caseA(stretchLockedAudio: true)),
      code(fieldLocked),
    );
    expect(
      () => compiler.compile(caseA(reuseCacheWithDeletedSku: true)),
      code(factSkuMismatch),
    );
    expect(compiler.documentWrites, 0);
  });

  test('unplacing S2 is not delete source; a local S4 redo does not regenerate other shots; a missing causal shot is not rewritten into dialogue; a later character publish does not upgrade the pin', () {
    final compiler = ChangeDependencyCompiler();
    final program = compiler.compile(
      ChangeDependencyRequest(
        shots: [
          storyShot(id: 's1', duration: 3),
          storyShot(id: 's2', duration: 4),
          storyShot(id: 's3', duration: 4, causalRole: 'pickup'),
          storyShot(
            id: 's4',
            duration: 5,
            promptHash: promptS4,
            candidateHash: candidateS4,
            handmade: true,
            sourceIn: 0,
            sourceOut: 5,
            generatedDuration: 6,
          ),
        ],
        fromDuration: 16,
        toDuration: 12,
        unplaceShotIds: const ['s2'],
        redoShotIds: const ['s4'],
        durationProposalConfirmed: true,
        proposedDurations: const {'s1': 3, 's3': 4, 's4': 5},
        locks: [
          LockedField(
            kind: LockedFieldKind.caption,
            targetId: 's4',
            text: '是你的吗？',
          ),
          LockedField(
            kind: LockedFieldKind.sourceRange,
            targetId: 's4',
            start: 0,
            end: 5,
          ),
        ],
        pinnedCharacterRevision: 'lan@1',
        laterPublishedCharacterRevision: 'lan@2',
        voiceMode: VoiceMode.captions,
      ),
    );
    expect(program.submitted, isFalse);
    expect(program.paidGenerationStarted, isFalse);
    expect(program.ttsLaunched, isFalse);
    expect(program.characterPinUpgraded, isFalse);
    expect(program.pinnedCharacterRevision, 'lan@1');
    expect(program.deletedConstraintResurrected, isFalse);
    expect(program.totalDuration, 12);
    expect(program.missingCausalShot, isFalse);

    final s2 = program.shots.singleWhere((s) => s.shotId == 's2');
    expect(s2.placed, isFalse);
    expect(s2.deleteIntent, ShotDeleteIntent.unplaceShot);
    expect(s2.sourceRecoverable, isTrue);
    expect(s2.regenerateProposed, isFalse);

    final s1 = program.shots.singleWhere((s) => s.shotId == 's1');
    final s3 = program.shots.singleWhere((s) => s.shotId == 's3');
    final s4 = program.shots.singleWhere((s) => s.shotId == 's4');
    expect(s1.promptStale, isFalse);
    expect(s1.regenerateProposed, isFalse);
    expect(s3.promptStale, isFalse);
    expect(s3.placed, isTrue);
    expect(s4.promptStale, isTrue);
    expect(s4.candidateStale, isTrue);
    expect(s4.kind, StaleKind.handmadeAvailableForRedo);
    expect(s4.clipObjectReplaced, isFalse);
    expect(s4.keptCaption, '是你的吗？');
    expect(s4.keptSourceIn, 0);
    expect(s4.keptSourceOut, 5);
    expect(s4.generatedDuration, 6);

    expect(
      () => compiler.compile(
        ChangeDependencyRequest(
          shots: [
            storyShot(id: 's1', duration: 3),
            storyShot(id: 's3', duration: 4, causalRole: 'pickup'),
            storyShot(id: 's4', duration: 5, handmade: true),
          ],
          unplaceShotIds: const ['s3'],
          pretendMissingActionInDialogue: true,
        ),
      ),
      code(unsupportedEditTechnique),
    );
    final warned = compiler.compile(
      ChangeDependencyRequest(
        shots: [
          storyShot(id: 's1', duration: 3),
          storyShot(id: 's3', duration: 4, causalRole: 'pickup'),
          storyShot(id: 's4', duration: 5, handmade: true),
        ],
        unplaceShotIds: const ['s3'],
        fromDuration: 12,
        toDuration: 8,
        durationProposalConfirmed: true,
        proposedDurations: const {'s1': 3, 's4': 5},
      ),
    );
    expect(warned.missingCausalShot, isTrue);
    expect(warned.submitted, isFalse);
    expect(compiler.documentWrites, 0);
  });
}
