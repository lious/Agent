import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:studio_contracts/studio_contracts.dart';

import 'image_codes.dart';

const graphicKinds = {
  'sticker',
  'background',
  'frame',
  'texture',
  'illustration',
};

/// Library pin of an immutable graphic or template version.
final class GraphicPin {
  GraphicPin({
    required this.id,
    required this.version,
    required this.hash,
    this.kind = 'graphic',
  }) {
    requireId(id);
    if (version < 1) {
      throw const StudioException('INVALID_ID', 'version');
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const StudioException('INVALID_ID', 'hash');
    }
  }

  final String id, hash, kind;
  final int version;

  Map<String, Object?> toJson() => {
    'id': id,
    'version': version,
    'hash': hash,
    'kind': kind,
  };
}

final class GraphicPage {
  GraphicPage({required List<GraphicPin> items, this.nextCursor})
    : items = List.unmodifiable(items);
  final List<GraphicPin> items;
  final String? nextCursor;
}

/// A reusable graphic asset. User works remain ImageDocuments; this is not
/// a sticker product.
final class GraphicAsset {
  GraphicAsset({
    required this.id,
    required this.version,
    required this.namespace,
    required String name,
    required this.kind,
    required this.sourceAssetRef,
    required this.sourceGeometryHash,
    required this.previewBlobHash,
    required this.thumbnailBlobHash,
    required this.width,
    required this.height,
    required this.colorPolicyRef,
    required this.rightsId,
    required List<String> tags,
    this.schemaVersion = '1.0.0',
    this.maskArtifactHash,
    this.editableDocumentRef,
    this.alpha = 'straight',
    List<String>? dependencyBlobHashes,
  }) : name = name.trim(),
       tags = _normalizeTags(tags),
       dependencyBlobHashes = List.unmodifiable(dependencyBlobHashes ?? const []) {
    requireId(id);
    requireId(sourceAssetRef);
    requireId(colorPolicyRef);
    requireId(rightsId);
    if (version < 1) {
      throw const StudioException('INVALID_ID', 'version');
    }
    requireGraphicName(name);
    if (!graphicKinds.contains(kind)) {
      throw StudioException('INVALID_ID', kind);
    }
    if (width < 1 || width > 32768 || height < 1 || height > 32768) {
      throw const StudioException('INVALID_ID', 'size');
    }
    if (alpha != 'none' && alpha != 'straight') {
      throw const StudioException('INVALID_ID', 'alpha');
    }
    _requireHash(sourceGeometryHash, 'sourceGeometryHash');
    _requireHash(previewBlobHash, 'previewBlobHash');
    _requireHash(thumbnailBlobHash, 'thumbnailBlobHash');
    if (maskArtifactHash != null) {
      _requireHash(maskArtifactHash!, 'maskArtifactHash');
    }
  }

  final String id, name, kind, schemaVersion, sourceAssetRef;
  final String sourceGeometryHash, previewBlobHash, thumbnailBlobHash;
  final String colorPolicyRef, rightsId, alpha;
  final String? maskArtifactHash, editableDocumentRef;
  final int version, width, height;
  final Namespace namespace;
  final List<String> tags;
  final List<String> dependencyBlobHashes;

  String bodyHash() {
    return sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'version': version,
    'namespace': namespace.toJson(),
    'name': name,
    'kind': kind,
    'sourceAssetRef': sourceAssetRef,
    'sourceGeometryHash': sourceGeometryHash,
    'maskArtifactHash': maskArtifactHash,
    'editableDocumentRef': editableDocumentRef,
    'previewBlobHash': previewBlobHash,
    'thumbnailBlobHash': thumbnailBlobHash,
    'width': width,
    'height': height,
    'colorPolicyRef': colorPolicyRef,
    'alpha': alpha,
    'tags': tags,
    'rightsId': rightsId,
    'dependencyBlobHashes': dependencyBlobHashes,
  };

  factory GraphicAsset.fromJson(Map<String, Object?> json) {
    final ns = Map<String, Object?>.from(json['namespace'] as Map);
    return GraphicAsset(
      id: json['id'] as String,
      version: json['version'] as int,
      namespace: Namespace(
        ns['appId'] as String,
        ns['tenantId'] as String,
        ns['workspaceId'] as String,
      ),
      name: json['name'] as String,
      kind: json['kind'] as String,
      sourceAssetRef: json['sourceAssetRef'] as String,
      sourceGeometryHash: json['sourceGeometryHash'] as String,
      previewBlobHash: json['previewBlobHash'] as String,
      thumbnailBlobHash: json['thumbnailBlobHash'] as String,
      width: json['width'] as int,
      height: json['height'] as int,
      colorPolicyRef: json['colorPolicyRef'] as String,
      rightsId: json['rightsId'] as String,
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      maskArtifactHash: json['maskArtifactHash'] as String?,
      editableDocumentRef: json['editableDocumentRef'] as String?,
      alpha: json['alpha'] as String? ?? 'straight',
      dependencyBlobHashes:
          (json['dependencyBlobHashes'] as List?)?.cast<String>(),
    );
  }

  GraphicAsset copyWith({
    int? version,
    String? name,
    List<String>? tags,
  }) {
    return GraphicAsset(
      id: id,
      version: version ?? this.version,
      namespace: namespace,
      name: name ?? this.name,
      kind: kind,
      sourceAssetRef: sourceAssetRef,
      sourceGeometryHash: sourceGeometryHash,
      previewBlobHash: previewBlobHash,
      thumbnailBlobHash: thumbnailBlobHash,
      width: width,
      height: height,
      colorPolicyRef: colorPolicyRef,
      rightsId: rightsId,
      tags: tags ?? this.tags,
      maskArtifactHash: maskArtifactHash,
      editableDocumentRef: editableDocumentRef,
      alpha: alpha,
      dependencyBlobHashes: dependencyBlobHashes,
    );
  }
}

void _requireHash(String value, String label) {
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    throw StudioException('INVALID_ID', label);
  }
}


List<String> _normalizeTags(List<String> raw) {
  if (raw.length > 128) {
    throw const StudioException('INVALID_ID', 'tags');
  }
  final seen = <String>{};
  final out = <String>[];
  for (final tag in raw) {
    final folded = tag.trim().toLowerCase();
    if (folded.isEmpty || folded.length > 128) {
      throw const StudioException('INVALID_ID', 'tag');
    }
    if (seen.add(folded)) out.add(folded);
  }
  return List.unmodifiable(out);
}

void requireGraphicName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty || trimmed.length > 256) {
    throw const StudioException(nameRejected);
  }
}
