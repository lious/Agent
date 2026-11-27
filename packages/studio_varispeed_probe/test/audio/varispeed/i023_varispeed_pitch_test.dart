import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_varispeed_probe/studio_varispeed_probe.dart';
import 'package:test/test.dart';

/// Increment 2.83 official s4 leftover: a non-1x source-audio rate must
/// be explicit varispeed-and-pitch-change or mute, and must not claim
/// pitch preservation. This file does not invent a time-stretch engine,
/// limiter, or I-007 PCM remapping, does not re-qualify Increment 2.82
/// I-005 0.02s link-offset work, Increment 2.81 V-023 PressureAdmission,
/// Increments 2.74–2.80, I-007 / I-009 / I-024 leftovers, or V-004 Pulse
/// work, and does not claim a 20ms A/V achievement or a resolved
/// underrun. InversePatch kind stays restoreSnapshot. Project
/// user_version stays 9. I-023 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('non-1x source audio must be explicit varispeed-and-pitch-change or mute; claiming pitch preservation is refused', () {
    final admission = VarispeedAdmission();
    final varispeed = admission.admit(
      const VarispeedRequest(
        rateNum: 2,
        rateDen: 1,
        policy: AudioRatePolicy.varispeedPitchChange,
      ),
    );
    expect(varispeed.policy, AudioRatePolicy.varispeedPitchChange);
    expect(varispeed.pitchPreservedClaimed, isFalse);
    final muted = admission.admit(
      const VarispeedRequest(
        rateNum: 1,
        rateDen: 2,
        policy: AudioRatePolicy.muted,
      ),
    );
    expect(muted.policy, AudioRatePolicy.muted);
    expect(
      () => admission.admit(
        const VarispeedRequest(
          rateNum: 2,
          rateDen: 1,
          policy: AudioRatePolicy.pitchPreserved,
        ),
      ),
      code('PITCH_PRESERVED_UNAVAILABLE'),
    );
  });

  test('a non-1x rate with no explicit policy is refused; 1x needs no special policy', () {
    final admission = VarispeedAdmission();
    final oneX = admission.admit(
      const VarispeedRequest(
        rateNum: 1,
        rateDen: 1,
        policy: AudioRatePolicy.unspecified,
      ),
    );
    expect(oneX.policy, AudioRatePolicy.oneX);
    expect(oneX.pitchPreservedClaimed, isFalse);
    expect(
      () => admission.admit(
        const VarispeedRequest(
          rateNum: 2,
          rateDen: 1,
          policy: AudioRatePolicy.unspecified,
        ),
      ),
      code('VARISPEED_POLICY_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const VarispeedRequest(
          rateNum: 0,
          rateDen: 1,
          policy: AudioRatePolicy.varispeedPitchChange,
        ),
      ),
      code('RATE_INVALID'),
    );
  });

  test('a time-stretch engine, I-007 PCM remapping, limiter, and related leftovers stay closed', () {
    final admission = VarispeedAdmission();
    expect(admission.timeStretchInvented, isFalse);
    expect(admission.pcmRemapInvented, isFalse);
    expect(admission.limiterInvented, isFalse);
    expect(admission.i007Requalified, isFalse);
    expect(admission.i009Requalified, isFalse);
    expect(admission.i024Requalified, isFalse);
    expect(admission.v023Requalified, isFalse);
    expect(admission.i005Requalified, isFalse);
    expect(admission.muxerInvented, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
