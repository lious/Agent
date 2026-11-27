import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_delivery_fps/studio_delivery_fps.dart';
import 'package:test/test.dart';

/// Increment 2.79 official s6c delivery-fps PTS admission slice.
/// This file does not invent a retimer, muxer, or optical-flow
/// interpolator, does not re-qualify I-024, I-007, or V-004
/// leftovers, does not re-qualify the Increment 2.78
/// container-demux slice, the Increment 2.76 CodecProbePort
/// slice, V-002 format-reason leftovers, the Increment 2.77
/// ResourceAdmissionController slice, or I-042 pack leases,
/// does not start CompatibilityStore / ModelLease, does not
/// start I-059, I-061, or I-055, and does not mark I-037,
/// I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040,
/// I-053, I-056, I-057, I-052, I-039, V-026, I-043, I-044,
/// I-045, I-047, I-048, V-006, I-058, V-004, I-024, V-005,
/// V-002, or I-042 complete. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. V-002 stays
/// partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('changing delivery fps by rewriting only the header is refused because it would alter playback speed', () {
    final admission = DeliveryFpsAdmission();
    expect(
      () => admission.plan(
        const DeliveryFpsRequest(
          sourceFpsNum: 30,
          sourceFpsDen: 1,
          targetFpsNum: 60,
          targetFpsDen: 1,
          frameCount: 30,
          headerOnly: true,
        ),
      ),
      code('HEADER_FPS_SPEED_CHANGE'),
    );
    expect(
      () => admission.plan(
        const DeliveryFpsRequest(
          sourceFpsNum: 30,
          sourceFpsDen: 1,
          targetFpsNum: 24,
          targetFpsDen: 1,
          frameCount: 30,
          headerOnly: true,
        ),
      ),
      code('HEADER_FPS_SPEED_CHANGE'),
    );
  });

  test('a delivery fps change resamples timeline PTS and preserves duration and playback speed', () {
    final admission = DeliveryFpsAdmission();
    final faster = admission.plan(
      const DeliveryFpsRequest(
        sourceFpsNum: 30,
        sourceFpsDen: 1,
        targetFpsNum: 60,
        targetFpsDen: 1,
        frameCount: 30,
      ),
    );
    expect(faster.ptsResampled, isTrue);
    expect(faster.headerOnly, isFalse);
    expect(faster.playbackSpeedUnchanged, isTrue);
    expect(faster.durationPreserved, isTrue);
    expect(faster.durationTicks, faster.tickRate);
    expect(faster.ptsTicks.length, 30);
    expect(faster.ptsTicks.first, 0);
    expect(faster.ptsTicks[1] * 30, faster.durationTicks);
    expect(
      faster.ptsTicks.last + (faster.durationTicks ~/ 30),
      faster.durationTicks,
    );
    // Header-only 30→60 would last half as long; resampled duration stays 1s.
    expect(faster.durationTicks, isNot(faster.tickRate ~/ 2));

    final slower = admission.plan(
      const DeliveryFpsRequest(
        sourceFpsNum: 30,
        sourceFpsDen: 1,
        targetFpsNum: 24,
        targetFpsDen: 1,
        frameCount: 30,
      ),
    );
    expect(slower.durationTicks, slower.tickRate);
    expect(slower.playbackSpeedUnchanged, isTrue);
    expect(slower.ptsTicks[1] * 30, slower.durationTicks);
  });

  test(
    'a retimer is not invented; I-024, I-007, and V-004 leftovers stay closed',
    () {
      final admission = DeliveryFpsAdmission();
      expect(
        () => admission.plan(
          const DeliveryFpsRequest(
            sourceFpsNum: 30,
            sourceFpsDen: 1,
            targetFpsNum: 60,
            targetFpsDen: 1,
            frameCount: 30,
            inventFrames: true,
          ),
        ),
        code('RETIMER_NOT_INVENTED'),
      );
      expect(admission.retimerInvented, isFalse);
      expect(admission.opticalFlowInvented, isFalse);
      expect(admission.muxerInvented, isFalse);
      expect(admission.i024Requalified, isFalse);
      expect(admission.i007Requalified, isFalse);
      expect(admission.v004Requalified, isFalse);
      expect(admission.containerDemuxRequalified, isFalse);
      expect(admission.paidApiCalled, isFalse);
    },
  );
}
