import 'package:studio_contracts/studio_contracts.dart';

final class DeliveryFpsRequest {
  const DeliveryFpsRequest({
    required this.sourceFpsNum,
    required this.sourceFpsDen,
    required this.targetFpsNum,
    required this.targetFpsDen,
    required this.frameCount,
    this.headerOnly = false,
    this.inventFrames = false,
  });

  final int sourceFpsNum, sourceFpsDen, targetFpsNum, targetFpsDen, frameCount;
  final bool headerOnly, inventFrames;
}

final class DeliveryFpsPlan {
  DeliveryFpsPlan({
    required this.ptsResampled,
    required this.headerOnly,
    required this.playbackSpeedUnchanged,
    required this.durationPreserved,
    required this.tickRate,
    required this.durationTicks,
    required this.ptsTicks,
  });

  final bool ptsResampled,
      headerOnly,
      playbackSpeedUnchanged,
      durationPreserved;
  final int tickRate, durationTicks;
  final List<int> ptsTicks;
}

/// DEV-PURE s6c delivery-fps admission. A delivery fps change must
/// resample timeline PTS rather than rewrite the header and thereby
/// alter playback speed. This is not a retimer, muxer, or optical-flow
/// interpolator, and it is not a re-qualification of I-024, I-007, or
/// V-004 leftovers.
final class DeliveryFpsAdmission {
  bool retimerInvented = false;
  bool opticalFlowInvented = false;
  bool muxerInvented = false;
  bool i024Requalified = false;
  bool i007Requalified = false;
  bool v004Requalified = false;
  bool containerDemuxRequalified = false;
  bool paidApiCalled = false;

  DeliveryFpsPlan plan(DeliveryFpsRequest request) {
    if (request.inventFrames) {
      throw const StudioException('RETIMER_NOT_INVENTED', 'frames');
    }
    if (request.headerOnly) {
      throw const StudioException('HEADER_FPS_SPEED_CHANGE', 'header');
    }
    if (request.frameCount <= 0 ||
        request.sourceFpsNum <= 0 ||
        request.sourceFpsDen <= 0 ||
        request.targetFpsNum <= 0 ||
        request.targetFpsDen <= 0) {
      throw const StudioException('HEADER_FPS_SPEED_CHANGE', 'rate');
    }

    // duration = frameCount / sourceFps seconds.
    // tickRate = srcNum * srcDen * dstNum * dstDen.
    // durationTicks = frameCount * srcDen^2 * dstNum * dstDen.
    final tickRate =
        request.sourceFpsNum *
        request.sourceFpsDen *
        request.targetFpsNum *
        request.targetFpsDen;
    final step =
        request.sourceFpsDen *
        request.sourceFpsDen *
        request.targetFpsNum *
        request.targetFpsDen;
    final durationTicks = request.frameCount * step;
    final pts = <int>[for (var i = 0; i < request.frameCount; i++) i * step];
    return DeliveryFpsPlan(
      ptsResampled: true,
      headerOnly: false,
      playbackSpeedUnchanged: true,
      durationPreserved: true,
      tickRate: tickRate,
      durationTicks: durationTicks,
      ptsTicks: pts,
    );
  }
}
