import 'package:studio_contracts/studio_contracts.dart';

/// s4 RenderGraph order: decode/color → source crop/mask → transform
/// → clip effects → track composite → caption/text → sequence output
/// transform.
const officialEffectOrder = [
  'decodeColor',
  'sourceCropMask',
  'transform',
  'clipEffects',
  'trackComposite',
  'captionText',
  'sequenceOutputTransform',
];

final class PreviewExportConsistencyRequest {
  const PreviewExportConsistencyRequest({
    required this.effectOrder,
    this.proxyUsed = false,
    this.proxyReplacesEffectSemantics = false,
    this.previewDroppedSizeOrDisplayFrames = false,
    this.colorFormulaChanged = false,
  });

  final List<String> effectOrder;
  final bool proxyUsed,
      proxyReplacesEffectSemantics,
      previewDroppedSizeOrDisplayFrames,
      colorFormulaChanged;
}

final class PreviewExportConsistencyReceipt {
  const PreviewExportConsistencyReceipt({
    required this.effectOrderFixed,
    required this.proxySampleSourceOnly,
    required this.colorFormulaUnchanged,
    required this.previewDroppedSizeOrDisplayFrames,
  });

  final bool effectOrderFixed,
      proxySampleSourceOnly,
      colorFormulaUnchanged,
      previewDroppedSizeOrDisplayFrames;
}

/// DEV-PURE I-022 / s4 admission: preview and export share a fixed
/// RenderGraph order; a proxy replaces only the sample source, not
/// effect semantics; preview may drop size or display frames but must
/// not change the color formula.
///
/// This is not a V-003 measurement, not a re-qualification of
/// Increment 2.90 RenderRecipeAdmission, ADR 0023/0024 CPU consumers,
/// or PREVIEW_SCREENSHOT_NOT_EXPORT, and not a FrameLease or muxer.
final class PreviewExportConsistencyAdmission {
  bool v003Claimed = false;
  bool frameLeaseInvented = false;
  bool renderRecipeRequalified = false;
  bool iccFirstRequalified = false;
  bool rotationOnceRequalified = false;
  bool colorPipelineRequalified = false;
  bool i024Rewritten = false;
  bool muxerInvented = false;
  bool previewScreenshotAsExport = false;
  bool adr0023Requalified = false;
  bool adr0024Requalified = false;
  bool paidApiCalled = false;

  PreviewExportConsistencyReceipt admit(
    PreviewExportConsistencyRequest request,
  ) {
    for (final stage in request.effectOrder) {
      if (!officialEffectOrder.contains(stage)) {
        throw const StudioException('EFFECT_ORDER_UNKNOWN', 'graph');
      }
    }
    if (request.effectOrder.length != officialEffectOrder.length ||
        !_sameOrder(request.effectOrder, officialEffectOrder)) {
      throw const StudioException('EFFECT_ORDER_INVALID', 'graph');
    }
    if (request.proxyUsed && request.proxyReplacesEffectSemantics) {
      throw const StudioException('PROXY_REPLACES_EFFECT_SEMANTICS', 'graph');
    }
    if (request.colorFormulaChanged) {
      throw const StudioException('COLOR_FORMULA_CHANGED', 'graph');
    }
    return PreviewExportConsistencyReceipt(
      effectOrderFixed: true,
      proxySampleSourceOnly: !request.proxyReplacesEffectSemantics,
      colorFormulaUnchanged: true,
      previewDroppedSizeOrDisplayFrames:
          request.previewDroppedSizeOrDisplayFrames,
    );
  }
}

bool _sameOrder(List<String> actual, List<String> expected) {
  for (var i = 0; i < expected.length; i++) {
    if (actual[i] != expected[i]) return false;
  }
  return true;
}
