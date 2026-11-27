import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_proxy_delivery_probe/studio_proxy_delivery_probe.dart';
import 'package:test/test.dart';

/// Increment 2.86 official I-004 / s4 leftover: a proxy is enough to
/// edit, but a default export without the original is refused; only an
/// explicit proxy-delivery confirmation produces a marked degraded
/// export record. This file does not rewrite audio_export_test,
/// local_video_test, ExportService, or files_test, does not invent a
/// muxer or packMode=proxyOnly, and does not re-qualify Increments
/// 2.72, 2.80, 2.84, or 2.85. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9. I-004 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test(
    'a proxy without the original is editable; a default export is refused',
    () {
      final admission = ProxyDeliveryAdmission();
      final edit = admission.admit(
        const ProxyDeliveryRequest(
          originalPresent: false,
          proxyPresent: true,
          exportRequested: false,
        ),
      );
      expect(edit.canEdit, isTrue);
      expect(edit.exported, isFalse);
      expect(
        () => admission.admit(
          const ProxyDeliveryRequest(
            originalPresent: false,
            proxyPresent: true,
            exportRequested: true,
          ),
        ),
        code('MISSING_ORIGINAL_EXPORT'),
      );
      final withOriginal = admission.admit(
        const ProxyDeliveryRequest(
          originalPresent: true,
          proxyPresent: true,
          exportRequested: true,
        ),
      );
      expect(withOriginal.exported, isTrue);
      expect(withOriginal.degraded, isFalse);
    },
  );

  test('explicit proxy delivery produces a marked degraded export; unmarked or missing proxy is refused', () {
    final admission = ProxyDeliveryAdmission();
    final degraded = admission.admit(
      const ProxyDeliveryRequest(
        originalPresent: false,
        proxyPresent: true,
        exportRequested: true,
        explicitProxyDelivery: true,
        degradedMarked: true,
      ),
    );
    expect(degraded.exported, isTrue);
    expect(degraded.degraded, isTrue);
    expect(
      () => admission.admit(
        const ProxyDeliveryRequest(
          originalPresent: false,
          proxyPresent: true,
          exportRequested: true,
          explicitProxyDelivery: true,
        ),
      ),
      code('DEGRADED_EXPORT_UNMARKED'),
    );
    expect(
      () => admission.admit(
        const ProxyDeliveryRequest(
          originalPresent: false,
          proxyPresent: false,
          exportRequested: true,
          explicitProxyDelivery: true,
          degradedMarked: true,
        ),
      ),
      code('PROXY_UNAVAILABLE'),
    );
  });

  test('I-024 export suites, I-013 packMode, muxer, and V-003 leftovers stay closed', () {
    final admission = ProxyDeliveryAdmission();
    expect(admission.i024Requalified, isFalse);
    expect(admission.i013Requalified, isFalse);
    expect(admission.filesTestRequalified, isFalse);
    expect(admission.muxerInvented, isFalse);
    expect(admission.v003Claimed, isFalse);
    expect(admission.packModeProxyOnlyInvented, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
