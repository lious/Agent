import 'package:studio_color_probe/studio_color_probe.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

/// Increment 2.69 official first V-006 slice: color metadata and
/// range preservation, numeric-only verification when no HDR
/// display is present, no untested HDR publish, no silent
/// tonemap, and no auto-accept of the ≤0.002 error target
/// without V-006. This file does not invent a real HDR/LUT
/// runtime, does not claim V-006 numeric or appearance
/// qualification, does not start I-059, does not re-qualify
/// I-049 (already officialized; no TTS or clone engine), does
/// not re-qualify I-048, I-047, I-046, I-026, or I-025, does
/// not invent a limiter, and does not mark I-037, I-038, V-007,
/// V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056,
/// I-057, I-052, I-039, V-026, I-043, I-044, I-045, I-047, or
/// I-048 complete. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9. V-003 stays unclaimed. I-059
/// stays planned.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

const originalHash =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

const pq2020 = ColorMetadata(
  transfer: TransferFunction.pq,
  primaries: ColorPrimaries.bt2020,
  range: SampleRange.limited,
);

ColorPipelineAdmission admission({
  bool metadataPresent = true,
  DisplayKind display = DisplayKind.sdrNumericOnly,
  bool capabilityAvailable = false,
}) => ColorPipelineAdmission(
  originalHash: originalHash,
  metadata: pq2020,
  display: display,
  metadataPresent: metadataPresent,
  capabilityAvailable: capabilityAvailable,
);

void main() {
  test('HDR metadata and sample range are preserved; the original is not silently clipped or rewritten', () {
    final gate = admission();
    final preview = gate.preview();
    expect(preview.originalHash, originalHash);
    expect(preview.metadata.transfer, TransferFunction.pq);
    expect(preview.metadata.primaries, ColorPrimaries.bt2020);
    expect(preview.metadata.range, SampleRange.limited);
    expect(preview.metadataPreserved, isTrue);
    expect(preview.rangePreserved, isTrue);
    expect(preview.originalUnchanged, isTrue);
    expect(preview.autoAccepted, isFalse);
    expect(preview.appearanceQualified, isFalse);
    expect(() => gate.dropMetadata(), code('METADATA_NOT_PRESERVED'));
    expect(() => gate.dropRange(), code('RANGE_NOT_PRESERVED'));
    expect(() => gate.silentClipTo8Bit(), code('UNSUPPORTED_EDIT_TECHNIQUE'));
    expect(gate.originalDeleted, isFalse);
  });

  test('without an HDR display, verification is numeric only; appearance and untested HDR publish are not claimed', () {
    final gate = admission();
    final preview = gate.preview();
    expect(preview.numericOnly, isTrue);
    expect(preview.appearanceQualified, isFalse);
    expect(
      () => gate.claimAppearanceQualified(),
      code('APPEARANCE_UNQUALIFIED'),
    );
    expect(() => gate.publishUntestedHdr(), code('HDR_PUBLISH_UNTESTED'));
    expect(
      () => admission(metadataPresent: false).preview(),
      code('METADATA_INTERPRETATION_REQUIRED'),
    );
    expect(gate.appearanceClaimed, isFalse);
    expect(gate.publishedUntestedHdr, isFalse);
    expect(gate.v006Claimed, isFalse);
  });

  test('silent tonemap is refused; missing capability keeps original params read-only; V-006 cannot auto-accept', () {
    final gate = admission();
    expect(gate.v006Met, isFalse);
    expect(
      () => gate.silentTonemapToSdr(),
      code('TONEMAP_CONFIRMATION_REQUIRED'),
    );
    expect(
      () => gate.mutateParamsWhileCapabilityMissing(),
      code('FIELD_LOCKED'),
    );
    expect(() => gate.autoAcceptNumericGate(), code('V006_GATE_UNMET'));
    expect(() => gate.claimPqCardNotGreyWashed(), code('V006_GATE_UNMET'));
    expect(() => gate.startI059(), code('V006_GATE_UNMET'));
    expect(gate.i059Started, isFalse);
    expect(gate.silentTonemapApplied, isFalse);
    expect(gate.hdrRuntimeInvented, isFalse);
    expect(gate.lutRuntimeInvented, isFalse);
    expect(gate.v006Claimed, isFalse);
    expect(gate.paidApiCalled, isFalse);
    final preview = gate.preview();
    expect(preview.i059Started, isFalse);
    expect(preview.originalUnchanged, isTrue);
  });
}
