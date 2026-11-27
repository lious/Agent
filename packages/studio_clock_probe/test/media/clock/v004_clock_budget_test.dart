import 'package:studio_clock_probe/studio_clock_probe.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

/// Increment 2.71 official V-004 preview-drop disclosure slice:
/// dropped frames are not hidden as success, unmet drop-rate
/// targets only downgrade the preview proxy and disclose, output
/// time is not changed, and queues stay within the configured
/// bound. This file does not claim a measured 20ms A/V, 5% drop,
/// no-underrun, or 20-minute thermal achievement, does not
/// invent a hardware clock or a limiter, does not rewrite the
/// existing Linux Pulse audio-sink or preview_proxy suites, does
/// not re-qualify I-058, I-049, I-050, I-028, I-042, V-006,
/// I-053, V-007, I-001, I-011, or I-015 leftovers, does not
/// start I-059, I-061, or I-055, and does not mark I-037, I-038,
/// V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053,
/// I-056, I-057, I-052, I-039, V-026, I-043, I-044, I-045,
/// I-047, I-048, V-006, or I-058 complete. InversePatch kind
/// stays restoreSnapshot. Project user_version stays 9. V-003
/// stays unclaimed. V-004 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

ClockBudgetSession session() => ClockBudgetSession();

void main() {
  test('dropped frames are not hidden as success; output time and audio samples stay put', () {
    final clock = session();
    expect(
      () => clock.hideDroppedFramesAsSuccess(),
      code('DROP_HIDDEN_AS_SUCCESS'),
    );
    expect(
      () => clock.changeOutputTimeToHideLoad(),
      code('OUTPUT_TIME_IMMUTABLE'),
    );
    expect(
      () => clock.deleteAudioSamplesToCatchVideo(),
      code('AUDIO_SAMPLES_NOT_DROPPED'),
    );
    expect(
      () => clock.silentlyStretchAudioOnUnderrun(),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(clock.droppedFramesHidden, isFalse);
    expect(clock.outputTimeChanged, isFalse);
    expect(clock.audioSamplesDeletedToCatchVideo, isFalse);
  });

  test('an unmet drop-rate target only downgrades the preview proxy and discloses; success is not claimed', () {
    final clock = session();
    expect(clock.v004Met, isFalse);
    expect(clock.dropRate, greaterThan(clock.dropRateTarget));
    final receipt = clock.preview(queueUsed: 3);
    expect(receipt.proxyDowngraded, isTrue);
    expect(receipt.dropDisclosed, isTrue);
    expect(receipt.claimedSuccess, isFalse);
    expect(receipt.outputTimeUnchanged, isTrue);
    expect(receipt.disposition, LoadDisposition.proxyDowngraded);
    expect(() => clock.claimDropTargetMet(), code('V004_GATE_UNMET'));
    expect(
      () => clock.downgradeProxyWithoutDisclosure(),
      code('PROXY_DOWNGRADE_UNDISCLOSED'),
    );
  });

  test('the queue stays within its bound; 20ms, underrun, and thermal measurements are not claimed', () {
    final clock = session();
    final receipt = clock.preview(queueUsed: 8);
    expect(receipt.queueUsed, 8);
    expect(receipt.queueBound, 8);
    expect(receipt.claimedSuccess, isFalse);
    expect(() => clock.preview(queueUsed: 9), code('QUEUE_BOUND_EXCEEDED'));
    expect(() => clock.claimAvSyncMet(), code('V004_GATE_UNMET'));
    expect(() => clock.claimUnderrunResolved(), code('V004_GATE_UNMET'));
    expect(clock.v004Claimed, isFalse);
    expect(clock.avSyncClaimed, isFalse);
    expect(clock.underrunResolvedClaimed, isFalse);
    expect(clock.thermalLoadClaimed, isFalse);
    expect(clock.hardwareClockInvented, isFalse);
    expect(clock.v003Claimed, isFalse);
    expect(clock.paidApiCalled, isFalse);
  });
}
