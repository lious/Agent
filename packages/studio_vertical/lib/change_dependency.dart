import 'package:studio_contracts/studio_contracts.dart';

import 'vertical_brief.dart';

/// Official s8m locked fields. Title, caption, source range, music
/// keyframes, and overlay facts each have a field lock. This is not
/// a PlanGraph manual-lock API and not a product scheduler.
enum LockedFieldKind { title, caption, sourceRange, musicKeyframe, overlayFact }

/// Candidate invalidation is not the same as deleting accepted
/// handmade work. Manual fields are never auto-deleted because a
/// workpiece is stale.
enum StaleKind { candidateStale, handmadeAvailableForRedo }

/// Unplace a shot is not delete source and not delete message.
enum ShotDeleteIntent { unplaceShot, deleteSource, deleteMessage }

/// A locked deterministic field on a shot or the sequence.
final class LockedField {
  LockedField({
    required this.kind,
    required this.targetId,
    this.text,
    this.start,
    this.end,
  }) {
    requireId(targetId);
  }

  final LockedFieldKind kind;
  final String targetId;
  final String? text;
  final double? start, end;
}

/// One shot in the current intent. Hashes are declared content
/// identities for this compiler slice; this is not a DependencyIndex
/// product surface.
final class ShotNode {
  ShotNode({
    required this.id,
    required this.clipId,
    this.appearanceHash,
    this.factHash,
    this.analysisHash,
    this.promptHash,
    this.candidateHash,
    this.placed = true,
    this.acceptedHandmade = false,
    this.timelineDuration = 0,
    this.generatedDuration,
    this.sourceIn,
    this.sourceOut,
    this.causalRole,
  }) {
    requireId(id);
    requireId(clipId);
    for (final hash in [
      appearanceHash,
      factHash,
      analysisHash,
      promptHash,
      candidateHash,
    ]) {
      if (hash != null) requireHash(hash);
    }
  }

  final String id, clipId;
  final String? appearanceHash,
      factHash,
      analysisHash,
      promptHash,
      candidateHash;
  final bool placed, acceptedHandmade;
  final double timelineDuration;
  final double? generatedDuration, sourceIn, sourceOut;
  final String? causalRole;
}

/// DEV-PURE s8m change-dependency request. Compile does not submit,
/// start quote/apply, write SQL vertical.v1, or launch paid
/// generation, and does not invent IntentReducer as a product
/// surface.
final class ChangeDependencyRequest {
  ChangeDependencyRequest({
    required this.shots,
    this.currentRevision = 32,
    this.readSetRevision,
    this.fromSku,
    this.toSku,
    this.fromAppearanceHash,
    this.toAppearanceHash,
    this.fromFactHash,
    this.toFactHash,
    this.confirmedPrice,
    this.fromDuration,
    this.toDuration,
    this.locks = const [],
    this.unplaceShotIds = const [],
    this.redoShotIds = const [],
    this.durationProposalConfirmed = false,
    this.proposedDurations = const {},
    this.gapDuration = 0,
    this.deleteOldGap = false,
    this.lockedMusicDuration,
    this.explicitMusicTrim = false,
    this.explicitDeliveryRange,
    this.stretchLockedAudio = false,
    this.replacementSourceDuration,
    this.pinnedCharacterRevision,
    this.laterPublishedCharacterRevision,
    this.reuseCacheWithDeletedSku = false,
    this.pretendMissingActionInDialogue = false,
    this.voiceMode = VoiceMode.captions,
  }) {
    if (shots.isEmpty || shots.length > 16) {
      throw const StudioException(slotCount, 'shots');
    }
    for (final hash in [
      fromAppearanceHash,
      toAppearanceHash,
      fromFactHash,
      toFactHash,
    ]) {
      if (hash != null) requireHash(hash);
    }
    for (final id in [...unplaceShotIds, ...redoShotIds]) {
      requireId(id);
    }
    if (pinnedCharacterRevision != null) requireId(pinnedCharacterRevision!);
    if (laterPublishedCharacterRevision != null) {
      requireId(laterPublishedCharacterRevision!);
    }
  }

  final List<ShotNode> shots;
  final int currentRevision;
  final int? readSetRevision;
  final String? fromSku, toSku;
  final String? fromAppearanceHash, toAppearanceHash;
  final String? fromFactHash, toFactHash, confirmedPrice;
  final double? fromDuration, toDuration, lockedMusicDuration;
  final List<LockedField> locks;
  final List<String> unplaceShotIds, redoShotIds;
  final bool durationProposalConfirmed, deleteOldGap;
  final Map<String, double> proposedDurations;
  final double gapDuration;
  final bool explicitMusicTrim;
  final double? explicitDeliveryRange;
  final bool stretchLockedAudio;
  final double? replacementSourceDuration;
  final String? pinnedCharacterRevision, laterPublishedCharacterRevision;
  final bool reuseCacheWithDeletedSku, pretendMissingActionInDialogue;
  final VoiceMode voiceMode;
}

/// Per-shot invalidation. Accepted handmade work stays recoverable
/// for redo; the clip object is not replaced.
final class ShotInvalidation {
  ShotInvalidation({
    required this.shotId,
    required this.clipId,
    required this.kind,
    this.placed = true,
    this.promptStale = false,
    this.candidateStale = false,
    this.factOverlayStale = false,
    this.analysisStale = false,
    this.regenerateProposed = false,
    this.clipObjectReplaced = false,
    this.sourceRecoverable = false,
    this.deleteIntent,
    this.keptSourceIn,
    this.keptSourceOut,
    this.keptCaption,
    this.timelineDuration,
    this.generatedDuration,
  });

  final String shotId, clipId;
  final StaleKind? kind;
  final bool placed,
      promptStale,
      candidateStale,
      factOverlayStale,
      analysisStale,
      regenerateProposed,
      clipObjectReplaced,
      sourceRecoverable;
  final ShotDeleteIntent? deleteIntent;
  final double? keptSourceIn,
      keptSourceOut,
      timelineDuration,
      generatedDuration;
  final String? keptCaption;
}

/// s8m change-dependency result. Compile does not submit or write a
/// project.
final class ChangeDependencyProgram {
  ChangeDependencyProgram({
    required this.shots,
    this.totalDuration,
    this.gapDeleted = false,
    this.needsDurationConfirmation = false,
    this.missingCausalShot = false,
    this.musicLockUnchanged = true,
    this.deliveryRange,
    this.pinnedCharacterRevision,
  });

  final List<ShotInvalidation> shots;
  final double? totalDuration, deliveryRange;
  final bool gapDeleted, needsDurationConfirmation, missingCausalShot;
  final bool musicLockUnchanged;
  final String? pinnedCharacterRevision;

  int get documentWrites => 0;
  bool get submitted => false;
  bool get lateArrivalAutoApplied => false;
  bool get characterPinUpgraded => false;
  bool get paidGenerationStarted => false;
  bool get quoteOrApplyStarted => false;
  bool get ttsLaunched => false;
  bool get manualFieldsAutoDeleted => false;
  bool get deletedConstraintResurrected => false;
}

/// Official s8m leftover compiler for change dependency and locked
/// field invalidation. This is not IntentReducer, DependencyIndex,
/// a WorkflowCoordinator, or a paid generation path.
final class ChangeDependencyCompiler {
  int documentWrites = 0;

  ChangeDependencyProgram compile(ChangeDependencyRequest request) {
    if (request.readSetRevision != null &&
        request.readSetRevision != request.currentRevision) {
      throw const StudioException(revisionConflict, 'readSet');
    }
    if (request.reuseCacheWithDeletedSku) {
      throw const StudioException(factSkuMismatch, 'cache');
    }
    if (request.stretchLockedAudio) {
      throw const StudioException(fieldLocked, 'audio');
    }
    if (request.pretendMissingActionInDialogue) {
      throw const StudioException(unsupportedEditTechnique, 'dialogue');
    }

    final lockedCaptionByShot = <String, String>{};
    final lockedRangeByShot = <String, LockedField>{};
    for (final lock in request.locks) {
      if (lock.kind == LockedFieldKind.caption && lock.text != null) {
        lockedCaptionByShot[lock.targetId] = lock.text!;
        if (request.confirmedPrice != null &&
            lock.text!.contains(RegExp(r'\d')) &&
            !lock.text!.contains(request.confirmedPrice!)) {
          throw const StudioException(factBindingConflict, 'lockedCaption');
        }
      }
      if (lock.kind == LockedFieldKind.sourceRange) {
        lockedRangeByShot[lock.targetId] = lock;
      }
    }

    if (request.lockedMusicDuration != null &&
        request.toDuration != null &&
        request.lockedMusicDuration! > request.toDuration! &&
        !request.explicitMusicTrim &&
        request.explicitDeliveryRange == null) {
      throw const StudioException(fieldLocked, 'music');
    }

    if (request.replacementSourceDuration != null) {
      for (final shot in request.shots) {
        final range = lockedRangeByShot[shot.id];
        final end = range?.end ?? shot.sourceOut;
        if (end != null && request.replacementSourceDuration! < end) {
          throw const StudioException(parameterRange, 'sourceRange');
        }
      }
    }

    final appearanceChanged =
        request.fromAppearanceHash != null &&
        request.toAppearanceHash != null &&
        request.fromAppearanceHash != request.toAppearanceHash;
    final factChanged =
        request.fromFactHash != null &&
        request.toFactHash != null &&
        request.fromFactHash != request.toFactHash;
    final durationChanging =
        request.fromDuration != null &&
        request.toDuration != null &&
        request.fromDuration != request.toDuration;
    final needsDurationConfirmation =
        durationChanging && !request.durationProposalConfirmed;

    var missingCausalShot = false;
    final results = <ShotInvalidation>[];
    for (final shot in request.shots) {
      final unplaced = request.unplaceShotIds.contains(shot.id);
      if (unplaced && shot.causalRole != null) {
        missingCausalShot = true;
      }
      final appearanceStale =
          appearanceChanged &&
          shot.appearanceHash == request.fromAppearanceHash;
      final factStale = factChanged && shot.factHash == request.fromFactHash;
      final redo = request.redoShotIds.contains(shot.id);
      final promptStale = !unplaced && (appearanceStale || redo);
      final candidateStale = promptStale;
      final analysisStale = false;
      StaleKind? kind;
      if (unplaced) {
        kind = StaleKind.handmadeAvailableForRedo;
      } else if (shot.acceptedHandmade && (candidateStale || factStale)) {
        kind = StaleKind.handmadeAvailableForRedo;
      } else if (candidateStale) {
        kind = StaleKind.candidateStale;
      } else if (factStale) {
        kind = StaleKind.candidateStale;
      }

      double? timeline = shot.timelineDuration;
      if (!needsDurationConfirmation &&
          request.proposedDurations.containsKey(shot.id)) {
        timeline = request.proposedDurations[shot.id];
      }
      if (unplaced) timeline = 0;

      results.add(
        ShotInvalidation(
          shotId: shot.id,
          clipId: shot.clipId,
          kind: kind,
          placed: !unplaced && shot.placed,
          promptStale: promptStale,
          candidateStale: candidateStale,
          factOverlayStale: factStale,
          analysisStale: analysisStale,
          regenerateProposed: promptStale,
          clipObjectReplaced: false,
          sourceRecoverable: unplaced || shot.acceptedHandmade,
          deleteIntent: unplaced ? ShotDeleteIntent.unplaceShot : null,
          keptSourceIn: shot.sourceIn,
          keptSourceOut: shot.sourceOut,
          keptCaption: lockedCaptionByShot[shot.id],
          timelineDuration: timeline,
          generatedDuration: shot.generatedDuration,
        ),
      );
    }

    var total = needsDurationConfirmation
        ? request.fromDuration
        : request.toDuration ?? request.fromDuration;
    if (!needsDurationConfirmation && request.durationProposalConfirmed) {
      total = results
          .where((s) => s.placed)
          .fold<double>(0, (sum, s) => sum + (s.timelineDuration ?? 0));
    }

    documentWrites = 0;
    return ChangeDependencyProgram(
      shots: results,
      totalDuration: total,
      gapDeleted:
          !needsDurationConfirmation &&
          request.deleteOldGap &&
          request.durationProposalConfirmed,
      needsDurationConfirmation: needsDurationConfirmation,
      missingCausalShot: missingCausalShot,
      musicLockUnchanged: !request.explicitMusicTrim,
      deliveryRange: request.explicitDeliveryRange,
      pinnedCharacterRevision: request.pinnedCharacterRevision,
    );
  }
}
