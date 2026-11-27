import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:studio_contracts/studio_contracts.dart';

import 'image_codes.dart';
import 'layer.dart';

final class ImageDocument {
  ImageDocument({
    required this.id,
    required this.namespace,
    required this.width,
    required this.height,
    required List<ImageLayer> layers,
    this.schemaVersion = '1.0.0',
    this.version = 1,
    this.templateInstanceId,
    Map<String, String>? originalSourceHashes,
  }) : layers = List<ImageLayer>.from(layers),
       originalSourceHashes = Map<String, String>.from(
         originalSourceHashes ?? const {},
       ) {
    requireId(id);
    if (width < 2 || width > 8192 || height < 2 || height > 8192) {
      throw const StudioException('INVALID_ID', 'canvas');
    }
    final ids = <String>{};
    for (final layer in this.layers) {
      if (!ids.add(layer.id)) {
        throw StudioException('INVALID_ID', layer.id);
      }
      final hash = layer.sourceHash;
      if (hash != null) {
        this.originalSourceHashes.putIfAbsent(layer.id, () => hash);
      }
    }
  }

  final String id, schemaVersion;
  final Namespace namespace;
  final int width, height, version;
  final String? templateInstanceId;
  final List<ImageLayer> layers;
  final Map<String, String> originalSourceHashes;

  ImageLayer layer(String id) =>
      layers.firstWhere((l) => l.id == id, orElse: () {
        throw StudioException('INVALID_ID', id);
      });

  /// Canonical digest of the structured document, including every layer.
  /// Flattening would change this hash; a faithful round-trip must not.
  String structureHash() {
    final body = jsonEncode({
      'schemaVersion': schemaVersion,
      'id': id,
      'namespace': namespace.toJson(),
      'width': width,
      'height': height,
      'version': version,
      'templateInstanceId': templateInstanceId,
      'layers': [for (final l in layers) l.toJson()],
      'originalSourceHashes': originalSourceHashes,
    });
    return sha256.convert(utf8.encode(body)).toString();
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'namespace': namespace.toJson(),
    'width': width,
    'height': height,
    'version': version,
    'templateInstanceId': templateInstanceId,
    'layers': [for (final l in layers) l.toJson()],
    'originalSourceHashes': originalSourceHashes,
  };

  factory ImageDocument.fromJson(Map<String, Object?> json) {
    final ns = json['namespace'] as Map;
    return ImageDocument(
      id: json['id'] as String,
      namespace: Namespace(
        ns['appId'] as String,
        ns['tenantId'] as String,
        ns['workspaceId'] as String,
      ),
      width: json['width'] as int,
      height: json['height'] as int,
      version: json['version'] as int? ?? 1,
      schemaVersion: json['schemaVersion'] as String? ?? '1.0.0',
      templateInstanceId: json['templateInstanceId'] as String?,
      layers: [
        for (final row in json['layers'] as List)
          ImageLayer.fromJson(Map<String, Object?>.from(row as Map)),
      ],
      originalSourceHashes: {
        for (final e in (json['originalSourceHashes'] as Map? ?? const {}).entries)
          e.key as String: e.value as String,
      },
    );
  }

  /// Flattening a layered document into one raster layer is refused.
  ImageDocument flatten() {
    throw const StudioException(flattenForbidden);
  }

  /// Original source hashes recorded at first attach never change when a
  /// later grade, lock, or preview is produced.
  String originalHash(String layerId) {
    final hash = originalSourceHashes[layerId];
    if (hash == null) throw StudioException('INVALID_ID', layerId);
    return hash;
  }
}
