import 'package:studio_contracts/studio_contracts.dart';

/// First-version policy for a source-audio rate change. Pitch-preserving
/// time-stretch is a later licensed evaluation, not a v1 claim.
enum AudioRatePolicy {
  oneX,
  varispeedPitchChange,
  muted,
  pitchPreserved,
  unspecified,
}

final class VarispeedRequest {
  const VarispeedRequest({
    required this.rateNum,
    required this.rateDen,
    required this.policy,
  });

  final int rateNum, rateDen;
  final AudioRatePolicy policy;

  bool get isOneX => rateNum > 0 && rateDen > 0 && rateNum == rateDen;
}

final class VarispeedReceipt {
  const VarispeedReceipt({
    required this.rateNum,
    required this.rateDen,
    required this.policy,
    required this.pitchPreservedClaimed,
  });

  final int rateNum, rateDen;
  final AudioRatePolicy policy;
  final bool pitchPreservedClaimed;
}

/// DEV-PURE I-023 / s4 admission: a non-1x source-audio rate must be
/// explicit varispeed-and-pitch-change or mute, and must not claim
/// pitch preservation. This is not a time-stretch engine, not I-007
/// PCM remapping, and not a limiter.
final class VarispeedAdmission {
  bool timeStretchInvented = false;
  bool pcmRemapInvented = false;
  bool limiterInvented = false;
  bool i007Requalified = false;
  bool i009Requalified = false;
  bool i024Requalified = false;
  bool v023Requalified = false;
  bool i005Requalified = false;
  bool muxerInvented = false;
  bool paidApiCalled = false;

  VarispeedReceipt admit(VarispeedRequest request) {
    if (request.rateNum <= 0 || request.rateDen <= 0) {
      throw const StudioException('RATE_INVALID', 'rate');
    }
    if (request.isOneX) {
      return VarispeedReceipt(
        rateNum: request.rateNum,
        rateDen: request.rateDen,
        policy: request.policy == AudioRatePolicy.unspecified
            ? AudioRatePolicy.oneX
            : request.policy,
        pitchPreservedClaimed: false,
      );
    }
    if (request.policy == AudioRatePolicy.pitchPreserved) {
      throw const StudioException('PITCH_PRESERVED_UNAVAILABLE', 'rate');
    }
    if (request.policy != AudioRatePolicy.varispeedPitchChange &&
        request.policy != AudioRatePolicy.muted) {
      throw const StudioException('VARISPEED_POLICY_REQUIRED', 'rate');
    }
    return VarispeedReceipt(
      rateNum: request.rateNum,
      rateDen: request.rateDen,
      policy: request.policy,
      pitchPreservedClaimed: false,
    );
  }
}
