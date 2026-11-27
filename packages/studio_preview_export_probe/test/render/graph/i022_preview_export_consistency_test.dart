import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_preview_export_probe/studio_preview_export_probe.dart';
import 'package:test/test.dart';

/// Increment 2.92 official I-022 / s4 leftover: preview and export
/// share a fixed RenderGraph effect order; a proxy replaces only the
/// sample source, not effect semantics; preview may drop size or
/// display frames but must not change the color formula.
///
/// This file does not claim a V-003 measurement, does not invent a
/// FrameLease or muxer, does not rewrite I-024 export suites or
/// ExportService, and does not re-qualify Increment 2.90
/// RenderRecipeAdmission, Increment 2.91 IccFirstAdmission,
/// Increment 2.89 RotationOnceAdmission, Increment 2.69
/// ColorPipelineAdmission, ADR 0023/0024 CPU consumers, or
/// PREVIEW_SCREENSHOT_NOT_EXPORT. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. I-022 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('the official RenderGraph order is admitted; a reversed or truncated order is refused', () {
    final admission = PreviewExportConsistencyAdmission();
    final receipt = admission.admit(
      const PreviewExportConsistencyRequest(effectOrder: officialEffectOrder),
    );
    expect(receipt.effectOrderFixed, isTrue);
    expect(receipt.colorFormulaUnchanged, isTrue);
    expect(
      () => admission.admit(
        PreviewExportConsistencyRequest(
          effectOrder: officialEffectOrder.reversed.toList(),
        ),
      ),
      code('EFFECT_ORDER_INVALID'),
    );
    expect(
      () => admission.admit(
        const PreviewExportConsistencyRequest(
          effectOrder: ['decodeColor', 'transform'],
        ),
      ),
      code('EFFECT_ORDER_INVALID'),
    );
    expect(
      () => admission.admit(
        const PreviewExportConsistencyRequest(
          effectOrder: ['decodeColor', 'unknownStage'],
        ),
      ),
      code('EFFECT_ORDER_UNKNOWN'),
    );
  });

  test('a proxy may replace only the sample source; preview may drop size or frames but not the color formula', () {
    final admission = PreviewExportConsistencyAdmission();
    final receipt = admission.admit(
      const PreviewExportConsistencyRequest(
        effectOrder: officialEffectOrder,
        proxyUsed: true,
        previewDroppedSizeOrDisplayFrames: true,
      ),
    );
    expect(receipt.proxySampleSourceOnly, isTrue);
    expect(receipt.previewDroppedSizeOrDisplayFrames, isTrue);
    expect(receipt.colorFormulaUnchanged, isTrue);
    expect(
      () => admission.admit(
        const PreviewExportConsistencyRequest(
          effectOrder: officialEffectOrder,
          proxyUsed: true,
          proxyReplacesEffectSemantics: true,
        ),
      ),
      code('PROXY_REPLACES_EFFECT_SEMANTICS'),
    );
    expect(
      () => admission.admit(
        const PreviewExportConsistencyRequest(
          effectOrder: officialEffectOrder,
          previewDroppedSizeOrDisplayFrames: true,
          colorFormulaChanged: true,
        ),
      ),
      code('COLOR_FORMULA_CHANGED'),
    );
  });

  test('a V-003 measurement, FrameLease, muxer, and already-official recipe or color admissions stay closed', () {
    final admission = PreviewExportConsistencyAdmission();
    expect(admission.v003Claimed, isFalse);
    expect(admission.frameLeaseInvented, isFalse);
    expect(admission.renderRecipeRequalified, isFalse);
    expect(admission.iccFirstRequalified, isFalse);
    expect(admission.rotationOnceRequalified, isFalse);
    expect(admission.colorPipelineRequalified, isFalse);
    expect(admission.i024Rewritten, isFalse);
    expect(admission.muxerInvented, isFalse);
    expect(admission.previewScreenshotAsExport, isFalse);
    expect(admission.adr0023Requalified, isFalse);
    expect(admission.adr0024Requalified, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
