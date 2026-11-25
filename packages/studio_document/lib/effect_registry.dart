import 'package:studio_contracts/studio_contracts.dart';

/// One actually consumed node, not the full EffectRegistry/keyframe contract.
/// Rec.709 opaque source -> linear premultiplied opacity over black. q16 is the
/// versioned CPU recipe quantization; unknown techniques remain unsupported.
int clipOpacityQ16(Map<String, dynamic> project, Map clip) {
  final ids = clip['effectIds'] as List;
  if (ids.isEmpty) return 65536;
  if (ids.length != 1) {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  final matches = (project['effects'] as List).where(
    (e) => e['id'] == ids.single,
  );
  if (matches.length != 1) throw const StudioException('REF_NOT_FOUND');
  final e = matches.single;
  if (e['type'] != 'opacity' ||
      e['pluginVersion'] != '1.0.0' ||
      e['owner']['kind'] != 'clip' ||
      e['owner']['id'] != clip['id'] ||
      (e['keyframes'] as List).isNotEmpty ||
      (e['extensions'] as Map).isNotEmpty) {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
  }
  final value = (e['parameters']['value'] as num).toDouble();
  if (!value.isFinite || value < 0 || value > 1) {
    throw const StudioException('OPACITY_RANGE');
  }
  return e['enabled'] == false ? 65536 : (value * 65536).round();
}
