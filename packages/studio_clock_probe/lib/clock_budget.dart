import 'package:studio_contracts/studio_contracts.dart';

enum LoadDisposition { preview, proxyDowngraded, refused }

final class ClockBudgetReceipt {
  ClockBudgetReceipt({
    required this.dropRate,
    required this.dropDisclosed,
    required this.proxyDowngraded,
    required this.outputTimeUnchanged,
    required this.queueBound,
    required this.queueUsed,
    required this.claimedSuccess,
    required this.disposition,
  });

  final double dropRate;
  final int queueBound, queueUsed;
  final bool dropDisclosed,
      proxyDowngraded,
      outputTimeUnchanged,
      claimedSuccess;
  final LoadDisposition disposition;
}

/// DEV-PURE V-004 clock-budget and preview-drop disclosure protocol.
/// This is not a measured 20-minute thermal qualification, not a
/// 20ms A/V or 5% drop achievement, and not a rewrite of the
/// existing Linux Pulse audio-sink work.
final class ClockBudgetSession {
  ClockBudgetSession({
    this.queueBound = 8,
    this.dropRateTarget = 0.05,
    this.v004Met = false,
    this.dropRate = 0.12,
  });

  final int queueBound;
  final double dropRateTarget;
  final bool v004Met;
  double dropRate;

  int queueUsed = 0;
  bool droppedFramesHidden = false;
  bool outputTimeChanged = false;
  bool audioSamplesDeletedToCatchVideo = false;
  bool v004Claimed = false;
  bool avSyncClaimed = false;
  bool underrunResolvedClaimed = false;
  bool thermalLoadClaimed = false;
  bool hardwareClockInvented = false;
  bool v003Claimed = false;
  bool paidApiCalled = false;

  ClockBudgetReceipt preview({required int queueUsed}) {
    if (queueUsed > queueBound) {
      throw const StudioException('QUEUE_BOUND_EXCEEDED', 'queue');
    }
    this.queueUsed = queueUsed;
    final unmet = !v004Met || dropRate > dropRateTarget;
    if (unmet) {
      return ClockBudgetReceipt(
        dropRate: dropRate,
        dropDisclosed: true,
        proxyDowngraded: true,
        outputTimeUnchanged: true,
        queueBound: queueBound,
        queueUsed: queueUsed,
        claimedSuccess: false,
        disposition: LoadDisposition.proxyDowngraded,
      );
    }
    return ClockBudgetReceipt(
      dropRate: dropRate,
      dropDisclosed: dropRate > 0,
      proxyDowngraded: false,
      outputTimeUnchanged: true,
      queueBound: queueBound,
      queueUsed: queueUsed,
      claimedSuccess: false,
      disposition: LoadDisposition.preview,
    );
  }

  void hideDroppedFramesAsSuccess() {
    throw const StudioException('DROP_HIDDEN_AS_SUCCESS', 'drop');
  }

  void changeOutputTimeToHideLoad() {
    throw const StudioException('OUTPUT_TIME_IMMUTABLE', 'outputTime');
  }

  void deleteAudioSamplesToCatchVideo() {
    throw const StudioException('AUDIO_SAMPLES_NOT_DROPPED', 'catchUp');
  }

  void claimDropTargetMet() {
    if (!v004Met || dropRate > dropRateTarget) {
      throw const StudioException('V004_GATE_UNMET', 'dropRate');
    }
  }

  void claimAvSyncMet() {
    throw const StudioException('V004_GATE_UNMET', 'avSync');
  }

  void claimUnderrunResolved() {
    throw const StudioException('V004_GATE_UNMET', 'underrun');
  }

  void downgradeProxyWithoutDisclosure() {
    throw const StudioException('PROXY_DOWNGRADE_UNDISCLOSED', 'disclose');
  }

  void silentlyStretchAudioOnUnderrun() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'stretchAudio');
  }
}
