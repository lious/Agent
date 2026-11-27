import 'package:studio_contracts/studio_contracts.dart';

enum TransferFunction { pq, hlg, sdr }

enum ColorPrimaries { bt2020, bt709 }

enum SampleRange { limited, full }

enum DisplayKind { hdr, sdrNumericOnly }

final class ColorMetadata {
  const ColorMetadata({
    required this.transfer,
    required this.primaries,
    required this.range,
  });

  final TransferFunction transfer;
  final ColorPrimaries primaries;
  final SampleRange range;
}

final class ColorAdmissionReceipt {
  ColorAdmissionReceipt({
    required this.originalHash,
    required this.metadata,
    required this.metadataPreserved,
    required this.rangePreserved,
    required this.appearanceQualified,
    required this.autoAccepted,
    required this.originalUnchanged,
    required this.i059Started,
    required this.numericOnly,
  });

  final String originalHash;
  final ColorMetadata metadata;
  final bool metadataPreserved,
      rangePreserved,
      appearanceQualified,
      autoAccepted,
      originalUnchanged,
      i059Started,
      numericOnly;
}

/// DEV-PURE V-006 color-pipeline admission protocol. This is not a
/// real HDR/LUT runtime, not a V-006 numeric or appearance
/// qualification, and not I-059.
final class ColorPipelineAdmission {
  ColorPipelineAdmission({
    required this.originalHash,
    required this.metadata,
    this.display = DisplayKind.sdrNumericOnly,
    this.v006Met = false,
    this.capabilityAvailable = false,
    this.metadataPresent = true,
    this.tonemapConfirmed = false,
  });

  final String originalHash;
  final ColorMetadata metadata;
  final DisplayKind display;
  final bool v006Met, capabilityAvailable, metadataPresent, tonemapConfirmed;

  bool hdrRuntimeInvented = false;
  bool lutRuntimeInvented = false;
  bool v006Claimed = false;
  bool appearanceClaimed = false;
  bool i059Started = false;
  bool originalDeleted = false;
  bool silentTonemapApplied = false;
  bool publishedUntestedHdr = false;
  bool paidApiCalled = false;

  ColorAdmissionReceipt preview() {
    if (!metadataPresent) {
      throw const StudioException(
        'METADATA_INTERPRETATION_REQUIRED',
        'missing',
      );
    }
    return ColorAdmissionReceipt(
      originalHash: originalHash,
      metadata: metadata,
      metadataPreserved: true,
      rangePreserved: true,
      appearanceQualified: false,
      autoAccepted: false,
      originalUnchanged: true,
      i059Started: false,
      numericOnly: display == DisplayKind.sdrNumericOnly,
    );
  }

  void dropMetadata() {
    throw const StudioException('METADATA_NOT_PRESERVED', 'drop');
  }

  void dropRange() {
    throw const StudioException('RANGE_NOT_PRESERVED', 'drop');
  }

  void silentClipTo8Bit() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'silent8Bit');
  }

  void claimAppearanceQualified() {
    throw const StudioException('APPEARANCE_UNQUALIFIED', 'appearance');
  }

  void publishUntestedHdr() {
    throw const StudioException('HDR_PUBLISH_UNTESTED', 'publish');
  }

  void silentTonemapToSdr() {
    throw const StudioException(
      'TONEMAP_CONFIRMATION_REQUIRED',
      'silentTonemap',
    );
  }

  void mutateParamsWhileCapabilityMissing() {
    if (!capabilityAvailable) {
      throw const StudioException('FIELD_LOCKED', 'originalParams');
    }
  }

  void autoAcceptNumericGate() {
    if (!v006Met) {
      throw const StudioException('V006_GATE_UNMET', 'autoAccept');
    }
  }

  void startI059() {
    if (!v006Met) {
      throw const StudioException('V006_GATE_UNMET', 'i059');
    }
  }

  void claimPqCardNotGreyWashed() {
    throw const StudioException('V006_GATE_UNMET', 'pqCard');
  }
}
