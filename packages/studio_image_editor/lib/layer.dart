import 'package:studio_contracts/studio_contracts.dart';

enum LayerKind { image, graphic, text, mask, decoration }

final class LayerTransform {
  const LayerTransform({
    this.tx = 0,
    this.ty = 0,
    this.sx = 1,
    this.sy = 1,
    this.rotation = 0,
  });

  final num tx, ty, sx, sy, rotation;

  Map<String, Object?> toJson() => {
    'tx': tx,
    'ty': ty,
    'sx': sx,
    'sy': sy,
    'rotation': rotation,
  };

  factory LayerTransform.fromJson(Map<String, Object?> json) => LayerTransform(
    tx: json['tx'] as num? ?? 0,
    ty: json['ty'] as num? ?? 0,
    sx: json['sx'] as num? ?? 1,
    sy: json['sy'] as num? ?? 1,
    rotation: json['rotation'] as num? ?? 0,
  );
}

/// Non-destructive reference grade. Inferred colors are never stored as
/// original-image facts.
final class ColorGrade {
  const ColorGrade({
    this.exposure = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.inferred = false,
  });

  final num exposure, contrast, saturation;
  final bool inferred;

  ColorGrade add(ColorGrade other) => ColorGrade(
    exposure: exposure + other.exposure,
    contrast: contrast + other.contrast,
    saturation: saturation + other.saturation,
    inferred: inferred || other.inferred,
  );

  Map<String, Object?> toJson() => {
    'exposure': exposure,
    'contrast': contrast,
    'saturation': saturation,
    'inferred': inferred,
  };

  factory ColorGrade.fromJson(Map<String, Object?> json) => ColorGrade(
    exposure: json['exposure'] as num? ?? 0,
    contrast: json['contrast'] as num? ?? 0,
    saturation: json['saturation'] as num? ?? 0,
    inferred: json['inferred'] as bool? ?? false,
  );
}

final class ImageLayer {
  ImageLayer({
    required this.id,
    required this.kind,
    this.name = '',
    this.text,
    this.fontId,
    this.effectId,
    this.sourceHash,
    this.locked = false,
    this.transform = const LayerTransform(),
    this.grade = const ColorGrade(),
    this.maskLayerId,
  }) {
    requireId(id);
    if (fontId != null) requireId(fontId!);
    if (effectId != null) requireId(effectId!);
    if (sourceHash != null && !RegExp(r'^[a-f0-9]{64}$').hasMatch(sourceHash!)) {
      throw const StudioException('INVALID_ID', 'sourceHash');
    }
    if (maskLayerId != null) requireId(maskLayerId!);
  }

  final String id;
  final LayerKind kind;
  final String name;
  String? text;
  final String? fontId;
  final String? effectId;
  final String? sourceHash;
  bool locked;
  LayerTransform transform;
  ColorGrade grade;
  final String? maskLayerId;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'name': name,
    'text': text,
    'fontId': fontId,
    'effectId': effectId,
    'sourceHash': sourceHash,
    'locked': locked,
    'transform': transform.toJson(),
    'grade': grade.toJson(),
    'maskLayerId': maskLayerId,
  };

  factory ImageLayer.fromJson(Map<String, Object?> json) => ImageLayer(
    id: json['id'] as String,
    kind: LayerKind.values.byName(json['kind'] as String),
    name: json['name'] as String? ?? '',
    text: json['text'] as String?,
    fontId: json['fontId'] as String?,
    effectId: json['effectId'] as String?,
    sourceHash: json['sourceHash'] as String?,
    locked: json['locked'] as bool? ?? false,
    transform: LayerTransform.fromJson(
      Map<String, Object?>.from(json['transform'] as Map? ?? const {}),
    ),
    grade: ColorGrade.fromJson(
      Map<String, Object?>.from(json['grade'] as Map? ?? const {}),
    ),
    maskLayerId: json['maskLayerId'] as String?,
  );
}
