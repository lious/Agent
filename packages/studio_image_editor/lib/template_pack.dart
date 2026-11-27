import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:studio_contracts/studio_contracts.dart';

import 'image_codes.dart';
import 'layer.dart';

enum SlotKind { image, graphic, text }

final class TemplateSlot {
  TemplateSlot({
    required this.id,
    required this.layerId,
    required this.kind,
    required this.required,
    required List<num> safeRect,
    this.defaultText,
    this.fit = 'contain',
  }) : safeRect = List.unmodifiable(safeRect) {
    requireId(id);
    requireId(layerId);
    if (safeRect.length != 4) {
      throw const StudioException('INVALID_ID', 'safeRect');
    }
  }

  final String id, layerId, fit;
  final SlotKind kind;
  final bool required;
  final List<num> safeRect;
  final String? defaultText;

  Map<String, Object?> toJson() => {
    'id': id,
    'layerId': layerId,
    'kind': kind.name,
    'required': required,
    'fit': fit,
    'safeRect': safeRect,
    'defaultText': defaultText,
  };

  factory TemplateSlot.fromJson(Map<String, Object?> json) => TemplateSlot(
    id: json['id'] as String,
    layerId: json['layerId'] as String,
    kind: SlotKind.values.byName(json['kind'] as String),
    required: json['required'] as bool,
    fit: json['fit'] as String? ?? 'contain',
    safeRect: (json['safeRect'] as List).cast<num>(),
    defaultText: json['defaultText'] as String?,
  );
}

final class TemplatePack {
  TemplatePack({
    required this.id,
    required this.name,
    required this.family,
    required this.width,
    required this.height,
    required List<ImageLayer> layers,
    required List<TemplateSlot> slots,
    this.schemaVersion = '1.0.0',
    this.version = '1.0.0',
  }) : layers = List.unmodifiable(layers),
       slots = List.unmodifiable(slots) {
    requireId(id);
    if (name.trim().isEmpty || name.length > 256) {
      throw const StudioException('INVALID_ID', 'name');
    }
    final layerIds = {for (final l in this.layers) l.id};
    final slotIds = <String>{};
    for (final slot in this.slots) {
      if (!slotIds.add(slot.id)) {
        throw StudioException(slotType, slot.id);
      }
      if (!layerIds.contains(slot.layerId)) {
        throw StudioException(slotType, slot.layerId);
      }
      final layer = this.layers.firstWhere((l) => l.id == slot.layerId);
      if (!_compatible(slot.kind, layer.kind)) {
        throw StudioException(slotType, slot.id);
      }
    }
  }

  final String id, name, family, schemaVersion, version;
  final int width, height;
  final List<ImageLayer> layers;
  final List<TemplateSlot> slots;

  String packHash() {
    final body = jsonEncode({
      'id': id,
      'version': version,
      'name': name,
      'family': family,
      'width': width,
      'height': height,
      'layers': [for (final l in layers) l.toJson()],
      'slots': [for (final s in slots) s.toJson()],
    });
    return sha256.convert(utf8.encode(body)).toString();
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'version': version,
    'name': name,
    'family': family,
    'width': width,
    'height': height,
    'layers': [for (final l in layers) l.toJson()],
    'slots': [for (final s in slots) s.toJson()],
    'packHash': packHash(),
  };

  factory TemplatePack.fromJson(Map<String, Object?> json) => TemplatePack(
    id: json['id'] as String,
    name: json['name'] as String,
    family: json['family'] as String,
    width: json['width'] as int,
    height: json['height'] as int,
    version: json['version'] as String? ?? '1.0.0',
    schemaVersion: json['schemaVersion'] as String? ?? '1.0.0',
    layers: [
      for (final row in json['layers'] as List)
        ImageLayer.fromJson(Map<String, Object?>.from(row as Map)),
    ],
    slots: [
      for (final row in json['slots'] as List)
        TemplateSlot.fromJson(Map<String, Object?>.from(row as Map)),
    ],
  );

  static bool _compatible(SlotKind slot, LayerKind layer) {
    return switch (slot) {
      SlotKind.image => layer == LayerKind.image,
      SlotKind.graphic => layer == LayerKind.graphic || layer == LayerKind.decoration,
      SlotKind.text => layer == LayerKind.text,
    };
  }
}

final class TemplateBinding {
  const TemplateBinding({
    required this.slotId,
    this.assetHash,
    this.text,
  });

  final String slotId;
  final String? assetHash;
  final String? text;
}

final class TemplateInstance {
  TemplateInstance({
    required this.id,
    required this.templateId,
    required this.templateVersion,
    required this.templateHash,
    required this.imageDocumentId,
    required List<String> generatedLayerIds,
    required List<TemplateBinding> bindings,
  }) : generatedLayerIds = List.unmodifiable(generatedLayerIds),
       bindings = List.unmodifiable(bindings) {
    requireId(id);
  }

  final String id, templateId, templateVersion, templateHash, imageDocumentId;
  final List<String> generatedLayerIds;
  final List<TemplateBinding> bindings;

  Map<String, Object?> toJson() => {
    'id': id,
    'templateId': templateId,
    'templateVersion': templateVersion,
    'templateHash': templateHash,
    'imageDocumentId': imageDocumentId,
    'generatedLayerIds': generatedLayerIds,
    'bindings': [
      for (final b in bindings)
        {'slotId': b.slotId, 'assetHash': b.assetHash, 'text': b.text},
    ],
  };

  factory TemplateInstance.fromJson(Map<String, Object?> json) =>
      TemplateInstance(
        id: json['id'] as String,
        templateId: json['templateId'] as String,
        templateVersion: json['templateVersion'] as String,
        templateHash: json['templateHash'] as String,
        imageDocumentId: json['imageDocumentId'] as String,
        generatedLayerIds: (json['generatedLayerIds'] as List).cast<String>(),
        bindings: [
          for (final row in json['bindings'] as List)
            TemplateBinding(
              slotId: row['slotId'] as String,
              assetHash: row['assetHash'] as String?,
              text: row['text'] as String?,
            ),
        ],
      );
}
