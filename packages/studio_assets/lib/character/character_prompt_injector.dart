import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

import 'character_pack_validator.dart';
import 'character_repository.dart';
import 'character_resolver.dart';

/// Provider slot / reference capability used by [CharacterPromptInjector].
///
/// This slice does not call the provider and does not download adapters.
final class ProviderCapability {
  const ProviderCapability({
    required this.firstFrameSlots,
    this.supportsMultiReference = false,
    this.textOnly = false,
    this.profileId,
    this.baseModelFamily,
    this.baseModelFingerprint,
  });

  final int firstFrameSlots;
  final bool supportsMultiReference;
  final bool textOnly;
  final String? profileId;
  final String? baseModelFamily;
  final String? baseModelFingerprint;
}

/// Shot fields the injector is allowed to read. Unused encyclopedia fields
/// are not accepted here.
final class CharacterShotInput {
  const CharacterShotInput({
    required this.shotId,
    this.action = '',
    this.purposeBeat = '',
    this.hasProductFirstFrame = false,
    this.productFirstFrameRef,
  });

  final String shotId;
  final String action;
  final String purposeBeat;
  final bool hasProductFirstFrame;
  final Map<String, Object?>? productFirstFrameRef;
}

/// Compiled binding for one shot. Identity consistency is always a soft
/// constraint; this object never marks a pixel lock.
final class CharacterBindingPlan {
  const CharacterBindingPlan({
    required this.promptSections,
    required this.providerImageInputs,
    required this.adapterLoadRefs,
    required this.warnings,
    required this.bindingHash,
  });

  static const identitySoftConstraint = 'IDENTITY_SOFT_CONSTRAINT';

  final List<String> promptSections;
  final List<Map<String, Object?>> providerImageInputs;
  final List<String> adapterLoadRefs;
  final List<String> warnings;
  final String bindingHash;

  String get identityConsistency => identitySoftConstraint;

  bool get pixelLocked => false;

  Map<String, Object?> toJson() => {
    'promptSections': List<String>.from(promptSections),
    'providerImageInputs': [
      for (final input in providerImageInputs) cloneJson(input),
    ],
    'adapterLoadRefs': List<String>.from(adapterLoadRefs),
    'warnings': List<String>.from(warnings),
    'bindingHash': bindingHash,
    'identityConsistency': identityConsistency,
    'pixelLocked': pixelLocked,
  };
}

/// Official 8E prompt injector: this shot only, fail closed on slot conflict.
final class CharacterPromptInjector {
  const CharacterPromptInjector(this.repository);

  final CharacterRepository repository;

  CharacterBindingPlan compile(
    ResolvedCharacter resolvedCharacter,
    CharacterShotInput shot,
    ProviderCapability providerCapability,
  ) {
    requireId(shot.shotId);
    if (resolvedCharacter.voicePlanRef != null) {
      // Voice cloning is I-049 / I-050 and is not opened in this slice.
      throw const StudioException('UNSUPPORTED', 'voicePlanRef');
    }
    final pack = repository.loadPublished(
      resolvedCharacter.assetId,
      resolvedCharacter.pinnedVersion,
    );
    if (packHashOf(pack) != resolvedCharacter.packHash) {
      throw const StudioException('BINDING_MISMATCH', 'packHash');
    }
    final look = _lookOf(pack, resolvedCharacter.lookId);
    final references = [
      for (final item in pack['references'] as List)
        Map<String, Object?>.from(item as Map),
    ];
    final selectedIds = {
      for (final ref in resolvedCharacter.selectedReferenceRefs) ref.id,
    };
    final selectedReferences = [
      for (final reference in references)
        if (selectedIds.contains(reference['id'])) reference,
    ];
    final wantsCharacterImage =
        !providerCapability.textOnly && selectedReferences.isNotEmpty;
    if (wantsCharacterImage &&
        shot.hasProductFirstFrame &&
        !_canPlaceBoth(providerCapability)) {
      throw const StudioException('REFERENCE_SLOT_CONFLICT');
    }
    final imageInputs = <Map<String, Object?>>[];
    if (wantsCharacterImage) {
      for (final reference in selectedReferences) {
        imageInputs.add({
          'referenceId': reference['id'],
          'lookId': reference['lookId'],
          'role': reference['role'],
          'blobHash': reference['blobHash'],
          'source': 'libraryPack',
        });
      }
    }
    if (shot.hasProductFirstFrame && shot.productFirstFrameRef != null) {
      // The product first-frame is recorded, never silently dropped.
      imageInputs.add({
        'role': 'productFirstFrame',
        'source': 'shot',
        ...cloneJson(shot.productFirstFrameRef),
      });
    }

    final sections = <String>[
      'appearance: ${resolvedCharacter.effectiveAppearanceText}',
    ];
    final wardrobe = _wardrobeOf(look, resolvedCharacter);
    if (wardrobe != null) {
      sections.add('wardrobe: $wardrobe');
    }
    final action = shot.action.trim();
    if (action.isNotEmpty) {
      sections.add('action: $action');
    }
    if (resolvedCharacter.constraints.isNotEmpty) {
      sections.add('do-not-drift: ${resolvedCharacter.constraints.join('; ')}');
    }
    sections.add(CharacterBindingPlan.identitySoftConstraint);

    final warnings = <String>[CharacterBindingPlan.identitySoftConstraint];
    if (providerCapability.textOnly && selectedReferences.isNotEmpty) {
      warnings.add('TEXT_ONLY_NO_REFERENCE_IMAGES');
    }

    final adapterLoadRefs = _adapterRefs(
      pack: pack,
      bindingId: resolvedCharacter.appliedBindingId,
      capability: providerCapability,
    );
    final plan = {
      'promptSections': sections,
      'providerImageInputs': imageInputs,
      'adapterLoadRefs': adapterLoadRefs,
      'warnings': warnings,
      'identityConsistency': CharacterBindingPlan.identitySoftConstraint,
      'pixelLocked': false,
    };
    return CharacterBindingPlan(
      promptSections: sections,
      providerImageInputs: imageInputs,
      adapterLoadRefs: adapterLoadRefs,
      warnings: warnings,
      bindingHash: contentHash(plan),
    );
  }

  static bool _canPlaceBoth(ProviderCapability capability) {
    if (capability.textOnly) return false;
    if (capability.supportsMultiReference) return true;
    return capability.firstFrameSlots > 1;
  }

  static Map<String, Object?> _lookOf(
    Map<String, Object?> pack,
    String lookId,
  ) {
    for (final item in pack['looks'] as List) {
      final look = Map<String, Object?>.from(item as Map);
      if (look['id'] == lookId) return look;
    }
    throw const StudioException('RESOURCE_MISSING', 'lookId');
  }

  String? _wardrobeOf(Map<String, Object?> look, ResolvedCharacter resolved) {
    // Wardrobe is already folded into effective appearance text; keep an
    // explicit section only when the appearance string includes it, using
    // the resolved text rather than a stale look.wardrobe.
    final match = RegExp(r'wardrobe: ([^;]+)')
        .firstMatch(resolved.effectiveAppearanceText);
    if (match != null) return match.group(1);
    final wardrobe = look['wardrobe'];
    return wardrobe is String && wardrobe.isNotEmpty ? wardrobe : null;
  }

  List<String> _adapterRefs({
    required Map<String, Object?> pack,
    required String? bindingId,
    required ProviderCapability capability,
  }) {
    if (bindingId == null) return const [];
    Map<String, Object?>? binding;
    for (final item in pack['bindings'] as List) {
      final current = Map<String, Object?>.from(item as Map);
      if (current['id'] == bindingId) {
        binding = current;
        break;
      }
    }
    if (binding == null) {
      throw const StudioException('RESOURCE_MISSING', 'bindingId');
    }
    final kind = binding['kind'] as String;
    // Reference-image bindings are not LoRA loads. Training / download is
    // I-049/I-050 / weight pipeline and is not opened here.
    if (kind == 'referenceImages') return const [];
    if (kind == 'lora' || kind == 'featureEmbedding') {
      final fingerprint = binding['baseModelFingerprint'] as String?;
      if (capability.baseModelFingerprint == null ||
          fingerprint == null ||
          fingerprint != capability.baseModelFingerprint) {
        throw const StudioException('BINDING_MISMATCH', 'baseModelFingerprint');
      }
      final hash = binding['adapterBlobHash'] as String?;
      if (hash == null) {
        throw const StudioException('RESOURCE_MISSING', 'adapterBlobHash');
      }
      if (!repository.store.hasCas(hash)) {
        // Do not invent a download. The hash is not loaded.
        throw const StudioException('RESOURCE_MISSING', 'adapterBlobHash');
      }
      return [hash];
    }
    throw const StudioException('BINDING_MISMATCH', 'binding.kind');
  }
}
