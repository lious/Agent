import 'package:studio_contracts/studio_contracts.dart';

/// Official s8v shot execution strategies. Ken Burns is 2D, not 2.5D.
enum ShotStrategy { still, panZoom2d, layered25d, i2vMicro, fullMotion }

/// One shot in an animatic / shot-execution plan. This is not an
/// I-038 Prompt compiler and not a DependencyIndex product surface.
final class AnimaticShot {
  AnimaticShot({
    required this.id,
    required this.startFrame,
    required this.durationFrames,
    required this.strategy,
    this.characterIds = const [],
    this.dialogueText,
    this.dialogueSamples,
    this.lipSyncEnabled = false,
    this.hasMask = false,
    this.hasDepthOrPlanes = false,
    this.hasBackgroundFill = false,
    this.hasRegisteredRenderer = false,
    this.lockedCaption = false,
    this.characterPinVersion,
  }) {
    requireId(id);
    for (final characterId in characterIds) {
      requireId(characterId);
    }
  }

  final String id;
  final int startFrame, durationFrames;
  final ShotStrategy strategy;
  final List<String> characterIds;
  final String? dialogueText;
  final int? dialogueSamples;
  final bool lipSyncEnabled,
      hasMask,
      hasDepthOrPlanes,
      hasBackgroundFill,
      hasRegisteredRenderer,
      lockedCaption;
  final String? characterPinVersion;

  int get endFrame => startFrame + durationFrames;

  bool get layeredAssetsComplete =>
      hasMask && hasDepthOrPlanes && hasBackgroundFill && hasRegisteredRenderer;
}

final class AnimaticBuild {
  AnimaticBuild({
    required this.totalDurationFrames,
    required this.shots,
    required this.voiced,
    required this.label,
    required this.requiresVoicedStageSelection,
    required this.voicedApproved,
    required this.fallbackProposals,
    required this.staleShotIds,
    required this.sourceDeleted,
    required this.paidJobWithdrawn,
    required this.holdLastFrameProposed,
    required this.fpsUnchanged,
    required this.characterPinVersion,
  });

  final int totalDurationFrames;
  final List<AnimaticShot> shots;
  final bool voiced,
      requiresVoicedStageSelection,
      voicedApproved,
      sourceDeleted,
      paidJobWithdrawn,
      holdLastFrameProposed,
      fpsUnchanged;
  final String label;
  final List<String> fallbackProposals;
  final List<String> staleShotIds;
  final String? characterPinVersion;

  int get totalDurationSeconds => totalDurationFrames ~/ 24;
}

/// DEV-PURE I-039 AnimaticBuilder / ShotStrategyPlanner. Does not invent
/// a WorkflowCoordinator, a real TTS engine, or paid generation.
final class AnimaticBuilder {
  static const frameRate = 24;
  static const sampleRate = 48000;
  static const officialTotalFrames = 360;

  int documentWrites = 0;
  bool submitted = false;
  bool paidGeneration = false;
  bool ttsEngineInvented = false;
  bool workflowCoordinatorInvented = false;
  bool v020NarrativeQaClaimed = false;
  bool speedChanged = false;

  AnimaticBuild build(
    List<AnimaticShot> shots, {
    bool ttsSelected = false,
    bool recordingSelected = false,
    bool userConfirmed = false,
    bool treatSilentAsVoicedApproval = false,
    bool forceClaim25d = false,
    bool silentDegrade = false,
    bool speedUpOverflow = false,
    bool changeFpsToFit = false,
  }) {
    if (shots.isEmpty) {
      throw const StudioException('STRATEGY_PREREQUISITE_MISSING', 'shots');
    }
    _assertContiguous(shots);
    final fallbacks = <String>[];
    for (final shot in shots) {
      if (shot.strategy == ShotStrategy.layered25d &&
          !shot.layeredAssetsComplete) {
        if (forceClaim25d) {
          throw const StudioException('BLOCKED_LAYER_ASSETS', 'layered25d');
        }
        fallbacks.add(shot.id);
      }
      if (shot.strategy == ShotStrategy.i2vMicro && silentDegrade) {
        throw const StudioException(
          'STRATEGY_PREREQUISITE_MISSING',
          'silentDegrade',
        );
      }
      if (shot.dialogueSamples != null) {
        final capacity = shot.durationFrames * sampleRate ~/ frameRate;
        if (shot.dialogueSamples! > capacity) {
          if (speedUpOverflow || changeFpsToFit) {
            throw const StudioException(
              'FRAME_CONSTRAINT_UNSUPPORTED',
              'speed',
            );
          }
          throw const StudioException('DIALOGUE_OVERFLOW', 'dialogue');
        }
      }
    }
    final voiced = ttsSelected || recordingSelected;
    if (treatSilentAsVoicedApproval && !voiced) {
      throw const StudioException('ANIMATIC_APPROVAL_STALE', 'silentPreview');
    }
    if (changeFpsToFit) {
      throw const StudioException('FRAME_CONSTRAINT_UNSUPPORTED', 'fps');
    }
    documentWrites = 0;
    submitted = false;
    paidGeneration = false;
    return AnimaticBuild(
      totalDurationFrames: shots.last.endFrame,
      shots: shots,
      voiced: voiced,
      label: voiced ? '有声预演' : '未配音预演',
      requiresVoicedStageSelection: !voiced,
      voicedApproved: voiced && userConfirmed,
      fallbackProposals: fallbacks,
      staleShotIds: const [],
      sourceDeleted: false,
      paidJobWithdrawn: false,
      holdLastFrameProposed: false,
      fpsUnchanged: true,
      characterPinVersion: _pinVersion(shots),
    );
  }

  /// Change the lead character or remove a shot: only dependents go
  /// stale. Unplace is not delete-source and not withdraw a paid job.
  AnimaticBuild invalidate(
    List<AnimaticShot> shots, {
    String? newLeadId,
    String? removedShotId,
    String? changedDialogueShotId,
    String? libraryCharacterVersion,
    int? targetTotalFrames,
  }) {
    if (newLeadId != null) requireId(newLeadId);
    if (removedShotId != null) requireId(removedShotId);
    if (changedDialogueShotId != null) requireId(changedDialogueShotId);

    var remaining = List<AnimaticShot>.from(shots);
    if (removedShotId != null) {
      remaining = remaining.where((shot) => shot.id != removedShotId).toList();
    }

    final stale = <String>[];
    for (final shot in remaining) {
      if (newLeadId != null && shot.characterIds.contains(newLeadId)) {
        stale.add(shot.id);
      }
      if (changedDialogueShotId != null && shot.id == changedDialogueShotId) {
        stale.add(shot.id);
      }
      if (changedDialogueShotId != null &&
          shot.lipSyncEnabled &&
          shot.id == changedDialogueShotId) {
        stale.add(shot.id);
      }
    }

    var holdLastFrame = false;
    if (targetTotalFrames != null && remaining.isNotEmpty) {
      final current = remaining.last.endFrame;
      if (targetTotalFrames > current) {
        holdLastFrame = true;
      }
    }

    documentWrites = 0;
    submitted = false;
    paidGeneration = false;
    // A later library edition must not replace a frozen character pin.
    final pin = _pinVersion(remaining.isEmpty ? shots : remaining);
    if (libraryCharacterVersion != null &&
        pin != null &&
        libraryCharacterVersion != pin) {
      // Keep [pin]; do not adopt [libraryCharacterVersion].
    }
    return AnimaticBuild(
      totalDurationFrames:
          targetTotalFrames ??
          (remaining.isEmpty ? 0 : remaining.last.endFrame),
      shots: remaining,
      voiced: false,
      label: '未配音预演',
      requiresVoicedStageSelection: true,
      voicedApproved: false,
      fallbackProposals: const [],
      staleShotIds: stale.toSet().toList(),
      sourceDeleted: false,
      paidJobWithdrawn: false,
      holdLastFrameProposed: holdLastFrame,
      fpsUnchanged: true,
      characterPinVersion: pin,
    );
  }

  String? _pinVersion(List<AnimaticShot> shots) {
    for (final shot in shots) {
      if (shot.characterPinVersion != null) return shot.characterPinVersion;
    }
    return null;
  }

  void _assertContiguous(List<AnimaticShot> shots) {
    var cursor = 0;
    for (final shot in shots) {
      if (shot.startFrame != cursor || shot.durationFrames <= 0) {
        throw const StudioException('FRAME_CONSTRAINT_UNSUPPORTED', 'range');
      }
      cursor = shot.endFrame;
    }
  }
}

/// Official s8x 15-second, 24 fps, four-shot fixture. Sample counts
/// are test fixtures, not measured TTS quality.
List<AnimaticShot> officialFifteenSecondShots({
  bool s2LayeredAssets = true,
  int? s2DialogueSamples = 105600,
  int? s4DialogueSamples = 67200,
}) {
  return [
    AnimaticShot(
      id: 'S1',
      startFrame: 0,
      durationFrames: 72,
      strategy: ShotStrategy.panZoom2d,
      characterPinVersion: 'v3',
    ),
    AnimaticShot(
      id: 'S2',
      startFrame: 72,
      durationFrames: 96,
      strategy: ShotStrategy.layered25d,
      characterIds: const ['qinghe'],
      dialogueText: '等风停，我就出发。',
      dialogueSamples: s2DialogueSamples,
      hasMask: s2LayeredAssets,
      hasDepthOrPlanes: s2LayeredAssets,
      hasBackgroundFill: s2LayeredAssets,
      hasRegisteredRenderer: s2LayeredAssets,
      lockedCaption: true,
      characterPinVersion: 'v3',
    ),
    AnimaticShot(
      id: 'S3',
      startFrame: 168,
      durationFrames: 96,
      strategy: ShotStrategy.i2vMicro,
      characterIds: const ['qinghe'],
      characterPinVersion: 'v3',
    ),
    AnimaticShot(
      id: 'S4',
      startFrame: 264,
      durationFrames: 96,
      strategy: ShotStrategy.still,
      dialogueText: '这次，不再回头。',
      dialogueSamples: s4DialogueSamples,
    ),
  ];
}
