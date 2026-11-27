import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_proxy_seek_probe/studio_proxy_seek_probe.dart';
import 'package:test/test.dart';

/// Increment 2.88 official I-021 / s4 leftover: final render selects the
/// original source frame by the same proxy-frame→source-PTS map as
/// preview, and must not seek the original by proxy frame number. This
/// file does not rewrite source_preview_test or frame_proxy_test, does
/// not re-qualify I-021 20-point seek / VFR / nonzero-PTS / cache
/// leftovers or Increment 2.84 VFR audio-duration admission, and does
/// not invent a demuxer, retimer, or claim a 1-frame measurement.
/// InversePatch kind stays restoreSnapshot. Project user_version stays
/// 9. I-021 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('final render uses the proxy-frame to source-PTS map; seeking the original by proxy frame number is refused', () {
    final admission = ProxySourceSeekAdmission();
    // A provided map entry: proxy frame 2 → source 100 ms at 1 kHz ticks.
    final receipt = admission.admit(
      const ProxySourceSeekRequest(
        proxyFrameIndex: 2,
        sourcePtsTicks: 100,
        sourceDurationTicks: 133,
      ),
    );
    expect(receipt.sourcePtsTicks, 100);
    expect(
      () => admission.admit(
        const ProxySourceSeekRequest(
          proxyFrameIndex: 2,
          sourcePtsTicks: 100,
          sourceDurationTicks: 133,
          seekOriginalByProxyFrameIndex: true,
        ),
      ),
      code('PROXY_FRAME_SEEK_FORBIDDEN'),
    );
  });

  test('preview and final must use the same map rule; the last source frame must not go past the source', () {
    final admission = ProxySourceSeekAdmission();
    expect(
      () => admission.admit(
        const ProxySourceSeekRequest(
          proxyFrameIndex: 2,
          sourcePtsTicks: 100,
          sourceDurationTicks: 133,
          finalUsesMap: false,
        ),
      ),
      code('SOURCE_SELECTION_RULE_MISMATCH'),
    );
    expect(
      () => admission.admit(
        const ProxySourceSeekRequest(
          proxyFrameIndex: 3,
          sourcePtsTicks: 133,
          sourceDurationTicks: 133,
        ),
      ),
      code('SOURCE_FRAME_OUT_OF_RANGE'),
    );
  });

  test('I-021 seek/VFR/PTS suites, Increment 2.84 audio duration, and a 1-frame measurement stay closed', () {
    final admission = ProxySourceSeekAdmission();
    expect(admission.i021SeekRequalified, isFalse);
    expect(admission.vfrAudioRequalified, isFalse);
    expect(admission.retimerInvented, isFalse);
    expect(admission.demuxerInvented, isFalse);
    expect(admission.oneFrameClaimed, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
