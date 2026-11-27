import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

import 'character_pack_validator.dart';
import 'character_repository.dart';
import 'portrait_rights.dart';

/// Scope for [ProjectCharacterResolver.resolve]. This is not a generation
/// request and does not call a paid or remote API.
final class CharacterResolveScope {
  const CharacterResolveScope({
    required this.operation,
    required this.provider,
    required this.region,
    required this.now,
    this.projectId,
    this.shotId,
  });

  final String operation;
  final String provider;
  final String region;
  final DateTime now;
  final String? projectId;
  final String? shotId;
}

final class CharacterEntityRef {
  const CharacterEntityRef({required this.id, required this.version});

  final String id;
  final String version;

  Map<String, Object?> toJson() => {'id': id, 'version': version};
}

final class CharacterDependencyRef {
  const CharacterDependencyRef({
    required this.artifactId,
    required this.artifactVersion,
    required this.selector,
    required this.selectedValueHash,
    required this.sourceUseGrantId,
  });

  final String artifactId;
  final String artifactVersion;
  final String selector;
  final String selectedValueHash;
  final String sourceUseGrantId;

  Map<String, Object?> toJson() => {
    'artifactId': artifactId,
    'artifactVersion': artifactVersion,
    'selector': selector,
    'selectedValueHash': selectedValueHash,
    'sourceUseGrantId': sourceUseGrantId,
  };
}

/// Resolved pin of a project character against live rights.
///
/// [selectedReferenceRefs] are library-side reference ids with the pinned
/// pack version. They are not project Asset ids and are not auto-attached.
final class ResolvedCharacter {
  const ResolvedCharacter({
    required this.assetId,
    required this.pinnedVersion,
    required this.packHash,
    required this.lookId,
    required this.effectiveTraitHash,
    required this.effectiveAppearanceText,
    required this.selectedReferenceRefs,
    required this.voicePlanRef,
    required this.appliedBindingId,
    required this.rightsDecisionRef,
    required this.dependencySelectors,
    required this.name,
    required this.constraints,
    required this.rightsId,
  });

  final String assetId;
  final String pinnedVersion;
  final String packHash;
  final String lookId;
  final String effectiveTraitHash;
  final String effectiveAppearanceText;
  final List<CharacterEntityRef> selectedReferenceRefs;
  final String? voicePlanRef;
  final String? appliedBindingId;
  final String rightsDecisionRef;
  final List<CharacterDependencyRef> dependencySelectors;

  /// Materialize helpers: pack name and this-look anti-drift constraints.
  final String name;
  final List<String> constraints;
  final String rightsId;

  Map<String, Object?> toJson() => {
    'assetId': assetId,
    'pinnedVersion': pinnedVersion,
    'packHash': packHash,
    'lookId': lookId,
    'effectiveTraitHash': effectiveTraitHash,
    'effectiveAppearanceText': effectiveAppearanceText,
    'selectedReferenceRefs': [
      for (final ref in selectedReferenceRefs) ref.toJson(),
    ],
    'voicePlanRef': voicePlanRef,
    'appliedBindingId': appliedBindingId,
    'rightsDecisionRef': rightsDecisionRef,
    'dependencySelectors': [
      for (final selector in dependencySelectors) selector.toJson(),
    ],
    'name': name,
    'constraints': List<String>.from(constraints),
    'rightsId': rightsId,
  };
}

/// Official 8E resolver: pin content + live permission, not a later library head.
final class ProjectCharacterResolver {
  const ProjectCharacterResolver(this.repository);

  final CharacterRepository repository;

  ResolvedCharacter resolve(
    Map<String, Object?> projectCharacterRef,
    CharacterResolveScope scope,
    Map<String, Object?>? liveRights,
  ) {
    CharacterRepository.validator.validateProjectCharacterRef(
      projectCharacterRef,
    );
    final pack = repository.loadPublished(
      projectCharacterRef['assetId'] as String,
      projectCharacterRef['pinnedVersion'] as String,
    );
    if (packHashOf(pack) != projectCharacterRef['packHash']) {
      throw const StudioException('BINDING_MISMATCH', 'packHash');
    }
    if (pack['libraryId'] != projectCharacterRef['libraryId']) {
      throw const StudioException('BINDING_MISMATCH', 'libraryId');
    }
    final decision = _decide(
      projectCharacterRef: projectCharacterRef,
      pack: pack,
      scope: scope,
      liveRights: liveRights,
    );
    if (!decision.allowed) {
      throw StudioException(decision.code ?? 'RIGHTS_REQUIRED', 'liveRights');
    }
    final lookId = projectCharacterRef['lookId'] as String;
    final look = _lookOf(pack, lookId);
    final overrides = Map<String, Object?>.from(
      projectCharacterRef['overrides'] as Map,
    );
    final asset = Map<String, Object?>.from(pack['asset'] as Map);
    final traits = Map<String, Object?>.from(asset['traits'] as Map);
    final effectiveHair = _firstNonNull([
      overrides['hairStyle'],
      look['hairOverride'],
      traits['hairStyle'],
    ]);
    final effectiveTraits = cloneJson(traits)..['hairStyle'] = effectiveHair;
    final wardrobe = _firstNonNull([overrides['wardrobe'], look['wardrobe']]);
    final era = _firstNonNull([overrides['era'], look['era']]);
    final state = _firstNonNull([
      overrides['stateDescription'],
      look['stateDescription'],
    ]);
    final makeup = look['makeup'];
    final appearance = _appearanceText(
      name: asset['name'] as String,
      hair: effectiveHair,
      hairColor: traits['hairColor'] as String?,
      wardrobe: wardrobe,
      era: era,
      makeup: makeup is String ? makeup : null,
      state: state,
    );
    final lookReferenceIds = (look['referenceIds'] as List).cast<String>();
    final references = [
      for (final item in pack['references'] as List)
        Map<String, Object?>.from(item as Map),
    ];
    final selected = [
      for (final reference in references)
        if (lookReferenceIds.contains(reference['id']) ||
            (lookReferenceIds.isEmpty && reference['lookId'] == lookId))
          CharacterEntityRef(
            id: reference['id'] as String,
            version: projectCharacterRef['pinnedVersion'] as String,
          ),
    ];
    final bindingId = projectCharacterRef['bindingId'] as String?;
    if (bindingId != null) {
      final ids = {
        for (final item in pack['bindings'] as List)
          (item as Map)['id'] as String,
      };
      if (!ids.contains(bindingId)) {
        throw const StudioException('RESOURCE_MISSING', 'bindingId');
      }
    }
    final rightsId = asset['portraitRightsId'] as String;
    final doNotDrift = (traits['doNotDrift'] as List).cast<String>();
    final forbidden = (look['forbiddenChanges'] as List).cast<String>();
    final constraints = [...doNotDrift, ...forbidden];
    final decisionRef = contentHash({
      'allowed': decision.allowed,
      'code': decision.code,
      'rightsId': decision.rightsId,
      'epoch': decision.epoch,
      'existingOutputsPolicy': decision.existingOutputsPolicy,
    });
    final packHash = projectCharacterRef['packHash'] as String;
    final pinnedVersion = projectCharacterRef['pinnedVersion'] as String;
    final assetId = projectCharacterRef['assetId'] as String;
    return ResolvedCharacter(
      assetId: assetId,
      pinnedVersion: pinnedVersion,
      packHash: packHash,
      lookId: lookId,
      effectiveTraitHash: contentHash(effectiveTraits),
      effectiveAppearanceText: appearance,
      selectedReferenceRefs: selected,
      voicePlanRef: null,
      appliedBindingId: bindingId,
      rightsDecisionRef: decisionRef,
      dependencySelectors: [
        CharacterDependencyRef(
          artifactId: assetId,
          artifactVersion: pinnedVersion,
          selector: '/asset',
          selectedValueHash: packHash,
          sourceUseGrantId: rightsId,
        ),
        CharacterDependencyRef(
          artifactId: assetId,
          artifactVersion: pinnedVersion,
          selector: '/looks/$lookId',
          selectedValueHash: contentHash(look),
          sourceUseGrantId: rightsId,
        ),
      ],
      name: asset['name'] as String,
      constraints: constraints,
      rightsId: rightsId,
    );
  }

  RightsDecision _decide({
    required Map<String, Object?> projectCharacterRef,
    required Map<String, Object?> pack,
    required CharacterResolveScope scope,
    required Map<String, Object?>? liveRights,
  }) {
    final storeDecision = repository.evaluate(
      characterRef: projectCharacterRef,
      operation: scope.operation,
      provider: scope.provider,
      region: scope.region,
      now: scope.now,
    );
    if (liveRights == null) {
      return storeDecision;
    }
    final rightsId = (pack['asset'] as Map)['portraitRightsId'] as String;
    final suppliedId = liveRights['rights_id'] ?? liveRights['rightsId'];
    if (suppliedId != rightsId) {
      throw const StudioException('BINDING_MISMATCH', 'liveRights.rightsId');
    }
    final suppliedState = liveRights['state'] as String?;
    // Pin freezes content, not permission. A stale allow cannot bypass a
    // revoked or expired live row already recorded in the store.
    if (!storeDecision.allowed) {
      return storeDecision;
    }
    if (suppliedState == 'revoked') {
      return RightsDecision.deny(
        'RIGHTS_REVOKED',
        rightsId: rightsId,
        epoch: liveRights['epoch'] as String?,
        existingOutputsPolicy: storeDecision.existingOutputsPolicy,
      );
    }
    if (suppliedState == 'expired') {
      return RightsDecision.deny(
        'RIGHTS_EXPIRED',
        rightsId: rightsId,
        epoch: liveRights['epoch'] as String?,
        existingOutputsPolicy: storeDecision.existingOutputsPolicy,
      );
    }
    if (suppliedState == 'unknown' || suppliedState == null) {
      return RightsDecision.deny(
        'RIGHTS_REQUIRED',
        rightsId: rightsId,
        epoch: liveRights['epoch'] as String?,
        existingOutputsPolicy: storeDecision.existingOutputsPolicy,
      );
    }
    return storeDecision;
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

  static String? _firstNonNull(List<Object?> values) {
    for (final value in values) {
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  static String _appearanceText({
    required String name,
    String? hair,
    String? hairColor,
    String? wardrobe,
    String? era,
    String? makeup,
    String? state,
  }) {
    final parts = <String>[name];
    final hairText = [?hair, ?hairColor].join(' ');
    if (hairText.isNotEmpty) parts.add('hair: $hairText');
    if (wardrobe != null) parts.add('wardrobe: $wardrobe');
    if (era != null) parts.add('era: $era');
    if (makeup != null) parts.add('makeup: $makeup');
    if (state != null) parts.add('state: $state');
    return parts.join('; ');
  }
}
