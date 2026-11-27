import 'package:studio_contracts/studio_contracts.dart';

import 'character_pack_validator.dart';

/// Plan a project pin upgrade. Local overrides may only touch wardrobe / era /
/// stateDescription / hairStyle. Locked hand-edited captions and trims are
/// copied through and never overwritten. Identity traits and rights cannot be
/// patched.
final class CharacterUpgradeProposal {
  const CharacterUpgradeProposal({
    required this.newPin,
    required this.retainedOverrides,
    required this.lockedState,
    required this.staleAppearancePromptDrafts,
  });

  final Map<String, Object?> newPin;
  final Map<String, Object?> retainedOverrides;
  final Map<String, Object?> lockedState;
  final List<String> staleAppearancePromptDrafts;
}

final class CharacterUpgradePlanner {
  const CharacterUpgradePlanner();

  static const allowedOverrideFields = {
    'wardrobe',
    'era',
    'stateDescription',
    'hairStyle',
  };

  CharacterUpgradeProposal plan({
    required Map<String, Object?> oldPin,
    required Map<String, Object?> newPin,
    required Map<String, Object?> localOverrides,
    required Map<String, Object?> lockedPaths,
    List<String> appearancePromptDrafts = const [],
  }) {
    const CharacterPackValidator().validateProjectCharacterRef(oldPin);
    const CharacterPackValidator().validateProjectCharacterRef(newPin);
    for (final key in localOverrides.keys) {
      if (!allowedOverrideFields.contains(key)) {
        throw StudioException('BINDING_MISMATCH', 'overrides.$key');
      }
    }
    if (oldPin['assetId'] != newPin['assetId'] ||
        oldPin['libraryId'] != newPin['libraryId'] ||
        oldPin['projectCharacterId'] != newPin['projectCharacterId']) {
      throw const StudioException('BINDING_MISMATCH', 'projectCharacterRef');
    }
    final retained = <String, Object?>{
      'wardrobe': null,
      'era': null,
      'stateDescription': null,
      'hairStyle': null,
      ...Map<String, Object?>.from(oldPin['overrides'] as Map),
      ...localOverrides,
    };
    for (final key in retained.keys.toList()) {
      if (!allowedOverrideFields.contains(key)) {
        throw StudioException('BINDING_MISMATCH', 'overrides.$key');
      }
    }
    final nextPin = cloneJson(newPin);
    nextPin['overrides'] = cloneJson(retained);
    // locked caption / trim state is returned unchanged; the planner never
    // writes those paths.
    final locked = cloneJson(lockedPaths);
    return CharacterUpgradeProposal(
      newPin: nextPin,
      retainedOverrides: Map<String, Object?>.from(retained),
      lockedState: locked,
      staleAppearancePromptDrafts: List<String>.from(appearancePromptDrafts),
    );
  }

  /// Apply a proposal to a project slice. Only the character pin is replaced.
  /// Locked caption and trim values stay byte-identical.
  Map<String, Object?> apply(
    Map<String, Object?> projectSlice,
    CharacterUpgradeProposal proposal,
  ) {
    final next = cloneJson(projectSlice);
    next['characterPin'] = cloneJson(proposal.newPin);
    next['overrides'] = cloneJson(proposal.retainedOverrides);
    final locked = projectSlice['locked'] ?? projectSlice['lockedState'];
    if (locked != null) {
      next['locked'] = deepClone(locked);
    }
    if (projectSlice.containsKey('captions')) {
      next['captions'] = deepClone(projectSlice['captions']);
    }
    if (projectSlice.containsKey('trim')) {
      next['trim'] = deepClone(projectSlice['trim']);
    }
    for (final entry in proposal.lockedState.entries) {
      next[entry.key] = deepClone(entry.value);
    }
    return next;
  }
}
