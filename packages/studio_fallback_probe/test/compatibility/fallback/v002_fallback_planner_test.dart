import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_fallback_probe/studio_fallback_probe.dart';
import 'package:test/test.dart';

/// Increment 2.74 official s6c CompatibilityFallbackPlanner slice.
/// This file does not re-qualify V-004 proxy downgrade or I-024
/// no-encoder export refusal, does not invent a muxer, encoder,
/// limiter, SAF/iCloud adapter, or payment vendor, does not
/// re-qualify the Increment 2.73 V-005 provider-restriction
/// slice, AtomicFilePublisher, files_test, save_crash_test, or
/// I-011 crash leftovers, does not start I-059, I-061, or I-055,
/// and does not mark I-037, I-038, V-007, V-020, I-054, I-051,
/// I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039,
/// V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058,
/// V-004, I-024, or V-005 complete. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. V-002 stays
/// partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('same-format already-verified software falls back per local preference and is logged; each proposal carries time, quality, privacy, cost, and approval hash fields', () {
    final planner = CompatibilityFallbackPlanner();
    final plan = planner.propose(
      const FallbackRequest(
        sameFormatSoftwareVerified: true,
        localPreferenceAllowsSoftware: true,
        encoderAvailable: true,
        applySameFormatSoftware: true,
        previewProxyAvailable: true,
      ),
    );
    expect(plan.appliedSameFormatSoftware, isTrue);
    expect(plan.logged, isTrue);
    expect(planner.logged, isTrue);
    expect(plan.pendingAdaptation, isFalse);
    expect(plan.cloudAutoSelected, isFalse);
    expect(
      plan.proposals.map((p) => p.kind),
      containsAll([
        FallbackKind.sameFormatSoftware,
        FallbackKind.lowerPreviewProxy,
        FallbackKind.approvedCloud,
        FallbackKind.manual,
      ]),
    );
    for (final proposal in plan.proposals) {
      expect(proposal.timeNote, isNotEmpty);
      expect(proposal.qualityNote, isNotEmpty);
      expect(proposal.privacyNote, isNotEmpty);
      expect(proposal.costNote, isNotEmpty);
    }
  });

  test('output size, HDR, model, upload, or cost changes need confirmation; a missing encoder is not disguised as a CPU fallback', () {
    final planner = CompatibilityFallbackPlanner();
    expect(
      () => planner.propose(
        const FallbackRequest(
          sameFormatSoftwareVerified: true,
          localPreferenceAllowsSoftware: true,
          applySameFormatSoftware: true,
          hdrChanges: true,
        ),
      ),
      code('APPROVAL_REQUIRED'),
    );
    expect(
      () => planner.propose(
        const FallbackRequest(
          sameFormatSoftwareVerified: true,
          applySameFormatSoftware: true,
          outputSizeChanges: true,
        ),
      ),
      code('APPROVAL_REQUIRED'),
    );
    expect(
      () => planner.propose(
        const FallbackRequest(
          sameFormatSoftwareVerified: true,
          applySameFormatSoftware: true,
          modelSemanticsChange: true,
          uploadChanges: true,
          costChanges: true,
        ),
      ),
      code('APPROVAL_REQUIRED'),
    );
    expect(
      () => planner.propose(
        const FallbackRequest(
          encoderAvailable: false,
          claimCpuEncoderFallback: true,
        ),
      ),
      code('CPU_ENCODER_FALLBACK_FORBIDDEN'),
    );
  });

  test('with no local path the plan is pending adaptation or unsupported; cloud is not selected silently; V-004 and I-024 leftovers stay closed', () {
    final planner = CompatibilityFallbackPlanner();
    expect(
      () => planner.propose(const FallbackRequest(autoSelectCloud: true)),
      code('SILENT_CLOUD_FORBIDDEN'),
    );
    final plan = planner.propose(const FallbackRequest());
    expect(plan.pendingAdaptation, isTrue);
    expect(plan.unsupported, isTrue);
    expect(plan.appliedSameFormatSoftware, isFalse);
    expect(plan.cloudAutoSelected, isFalse);
    expect(
      plan.proposals.map((p) => p.kind),
      isNot(contains(FallbackKind.sameFormatSoftware)),
    );
    expect(planner.v004ProxyRequalified, isFalse);
    expect(planner.i024EncoderRequalified, isFalse);
    expect(planner.encoderInvented, isFalse);
    expect(planner.cloudCalled, isFalse);
    expect(planner.paidApiCalled, isFalse);
    expect(planner.muxerInvented, isFalse);
    expect(planner.limiterInvented, isFalse);
    expect(planner.v005Requalified, isFalse);
  });
}
