import 'package:studio_contracts/studio_contracts.dart';

import 'image_codes.dart';
import 'image_document.dart';
import 'layer.dart';
import 'template_pack.dart';

final class FontRegistry {
  FontRegistry([Set<String>? ids]) : ids = {...?ids};

  final Set<String> ids;

  bool has(String id) => ids.contains(id);
}

final class EffectRegistry {
  EffectRegistry([Set<String>? ids]) : ids = {...?ids};

  final Set<String> ids;

  bool has(String id) => ids.contains(id);
}

final class DegradeReport {
  const DegradeReport({required this.code, required this.path});
  final String code, path;
}

final class Instantiation {
  Instantiation({
    required this.document,
    required this.instance,
    required List<DegradeReport> degrades,
  }) : degrades = List.unmodifiable(degrades);

  final ImageDocument document;
  final TemplateInstance instance;
  final List<DegradeReport> degrades;
}

/// Instantiates a template into a layered ImageDocument. Rebind of a slot
/// keeps other layers, text, and hand-edited transforms. Missing fonts or
/// effects are reported as explicit degrades and are not silently dropped.
final class TemplateService {
  TemplateService({
    FontRegistry? fonts,
    EffectRegistry? effects,
  }) : fonts = fonts ?? FontRegistry({'font-sans', 'font-serif'}),
       effects = effects ?? EffectRegistry({'effect-frame'});

  final FontRegistry fonts;
  final EffectRegistry effects;

  Instantiation instantiate({
    required TemplatePack pack,
    required String instanceId,
    required String documentId,
    required Namespace namespace,
    List<TemplateBinding> bindings = const [],
    bool allowDraft = false,
  }) {
    requireId(instanceId);
    requireId(documentId);
    final bySlot = {for (final b in bindings) b.slotId: b};
    final layers = <ImageLayer>[];
    final generated = <String>[];
    final resolved = <TemplateBinding>[];
    final degrades = <DegradeReport>[];

    for (final layer in pack.layers) {
      final slot = pack.slots.where((s) => s.layerId == layer.id).firstOrNull;
      var text = layer.text;
      var sourceHash = layer.sourceHash;
      if (slot != null) {
        final binding = bySlot[slot.id];
        if (slot.required &&
            !allowDraft &&
            binding == null &&
            slot.kind != SlotKind.text &&
            (sourceHash == null || sourceHash == _zero)) {
          throw StudioException(requiredSlotEmpty, slot.id);
        }
        if (binding != null) {
          if (slot.kind == SlotKind.text) {
            if (binding.assetHash != null) {
              throw StudioException(slotType, slot.id);
            }
            text = binding.text ?? slot.defaultText ?? text;
          } else {
            if (binding.text != null) {
              throw StudioException(slotType, slot.id);
            }
            sourceHash = binding.assetHash ?? sourceHash;
          }
        } else if (slot.kind == SlotKind.text) {
          text = slot.defaultText ?? text;
        }
        resolved.add(
          TemplateBinding(slotId: slot.id, assetHash: sourceHash, text: text),
        );
      }
      final copy = ImageLayer(
        id: '$documentId-${layer.id}',
        kind: layer.kind,
        name: layer.name,
        text: text,
        fontId: layer.fontId,
        effectId: layer.effectId,
        sourceHash: sourceHash,
        locked: layer.locked,
        transform: layer.transform,
        grade: layer.grade,
        maskLayerId: layer.maskLayerId == null
            ? null
            : '$documentId-${layer.maskLayerId}',
      );
      if (copy.fontId != null && !fonts.has(copy.fontId!)) {
        degrades.add(DegradeReport(code: missingFont, path: copy.id));
      }
      if (copy.effectId != null && !effects.has(copy.effectId!)) {
        degrades.add(DegradeReport(code: missingEffect, path: copy.id));
      }
      layers.add(copy);
      generated.add(copy.id);
    }

    final document = ImageDocument(
      id: documentId,
      namespace: namespace,
      width: pack.width,
      height: pack.height,
      layers: layers,
      templateInstanceId: instanceId,
    );
    final instance = TemplateInstance(
      id: instanceId,
      templateId: pack.id,
      templateVersion: pack.version,
      templateHash: pack.packHash(),
      imageDocumentId: documentId,
      generatedLayerIds: generated,
      bindings: resolved,
    );
    return Instantiation(
      document: document,
      instance: instance,
      degrades: degrades,
    );
  }

  /// Rebind one slot. Other layer IDs, text, decorations, and transforms stay.
  void rebind({
    required ImageDocument document,
    required TemplatePack pack,
    required TemplateInstance instance,
    required String slotId,
    String? assetHash,
    String? text,
  }) {
    final slot = pack.slots.where((s) => s.id == slotId).firstOrNull;
    if (slot == null) throw StudioException(slotType, slotId);
    final layerId = '${document.id}-${slot.layerId}';
    final layer = document.layer(layerId);
    if (layer.locked) {
      throw StudioException(lockedField, layerId);
    }
    if (slot.kind == SlotKind.text) {
      if (assetHash != null) throw StudioException(slotType, slotId);
      layer.text = text;
    } else {
      if (text != null) throw StudioException(slotType, slotId);
      // The original source hash recorded at first attach is left unchanged.
      // The current layer source may update to the new binding.
      if (assetHash != null) {
        final next = ImageLayer(
          id: layer.id,
          kind: layer.kind,
          name: layer.name,
          text: layer.text,
          fontId: layer.fontId,
          effectId: layer.effectId,
          sourceHash: assetHash,
          locked: layer.locked,
          transform: layer.transform,
          grade: layer.grade,
          maskLayerId: layer.maskLayerId,
        );
        final index = document.layers.indexWhere((l) => l.id == layer.id);
        document.layers[index] = next;
      }
    }
  }

  Instantiation roundTrip(ImageDocument document, TemplateInstance instance) {
    final jsonDoc = ImageDocument.fromJson(
      Map<String, Object?>.from(document.toJson()),
    );
    final jsonInst = TemplateInstance.fromJson(
      Map<String, Object?>.from(instance.toJson()),
    );
    if (jsonDoc.layers.length != document.layers.length) {
      throw const StudioException(flattenForbidden, 'roundtrip');
    }
    return Instantiation(
      document: jsonDoc,
      instance: jsonInst,
      degrades: const [],
    );
  }

  /// Reversible reference grade. Locked layers are skipped. Inferred color
  /// cannot be written as an original-image fact. Style suggestions may be
  /// refused without mutating the document.
  List<String> applyReferenceGrade(
    ImageDocument document,
    ColorGrade grade, {
    bool refuseSuggestion = false,
  }) {
    if (refuseSuggestion) {
      throw const StudioException(styleSuggestionRefused);
    }
    if (grade.inferred) {
      throw const StudioException(inferredColorNotFact);
    }
    final changed = <String>[];
    for (final layer in document.layers) {
      if (layer.locked) continue;
      layer.grade = layer.grade.add(grade);
      changed.add(layer.id);
    }
    return changed;
  }
}

const _zero =
    '0000000000000000000000000000000000000000000000000000000000000000';
