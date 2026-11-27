import 'package:studio_contracts/studio_contracts.dart';

enum EnhanceDisposition { preview, paused, resumed, cancelled }

final class ProtectedWarning {
  const ProtectedWarning({required this.id, required this.message});

  final String id;
  final String message;
}

final class EnhanceReceipt {
  EnhanceReceipt({
    required this.sourceHash,
    required this.nativeScale,
    required this.outputPreset,
    required this.coreTile,
    required this.halo,
    required this.generatedDetailIsFact,
    required this.warnings,
    required this.autoAccepted,
    required this.fullFilmResident,
    required this.disposition,
    required this.failedFramesApplied,
  });

  final String sourceHash, outputPreset;
  final int nativeScale, coreTile, halo;
  final bool generatedDetailIsFact,
      autoAccepted,
      fullFilmResident,
      failedFramesApplied;
  final List<ProtectedWarning> warnings;
  final EnhanceDisposition disposition;
}

/// DEV-PURE I-048 RestoreImageJob protocol. This is not a real
/// SR/denoise runtime and not a V-013 qualification.
final class RestoreImageJob {
  RestoreImageJob({
    required this.sourceHash,
    this.nativeScale = 4,
    this.outputPreset = 'realesrganX4plus',
    this.coreTile = 256,
    this.halo = 32,
    this.v013Met = false,
    this.imageGateMet = false,
    this.videoGateMet = false,
    List<ProtectedWarning>? warnings,
    List<int>? failedFrames,
  }) : warnings = List.unmodifiable(
         warnings ??
             const [
               ProtectedWarning(
                 id: 'watermark.logo',
                 message: 'logo and text may be altered; compare with source',
               ),
             ],
       ),
       failedFrames = List.unmodifiable(failedFrames ?? const [7]);

  final String sourceHash;
  final int nativeScale;
  final String outputPreset;
  final bool v013Met, imageGateMet, videoGateMet;
  final List<ProtectedWarning> warnings;
  final List<int> failedFrames;

  int coreTile;
  int halo;
  EnhanceDisposition disposition = EnhanceDisposition.preview;
  bool fullFilmResident = false;
  bool srEngineInvented = false;
  bool denoiseEngineInvented = false;
  bool v013Claimed = false;
  bool generatedDetailIsFact = false;
  bool paidApiCalled = false;
  bool submitted = false;
  bool autoAddedFps = false;

  EnhanceReceipt preview() {
    return EnhanceReceipt(
      sourceHash: sourceHash,
      nativeScale: nativeScale,
      outputPreset: outputPreset,
      coreTile: coreTile,
      halo: halo,
      generatedDetailIsFact: false,
      warnings: warnings,
      autoAccepted: false,
      fullFilmResident: fullFilmResident,
      disposition: disposition,
      failedFramesApplied: false,
    );
  }

  EnhanceReceipt deliverDownsampledX2() {
    return EnhanceReceipt(
      sourceHash: sourceHash,
      nativeScale: nativeScale,
      outputPreset: 'deliveryX2FromX4',
      coreTile: coreTile,
      halo: halo,
      generatedDetailIsFact: false,
      warnings: warnings,
      autoAccepted: false,
      fullFilmResident: false,
      disposition: disposition,
      failedFramesApplied: false,
    );
  }

  void claimScaleIsRecoveredFact() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'scaleAsFact');
  }

  void relabelDownsampledX2AsNativeX2() {
    throw const StudioException(
      'UNSUPPORTED_EDIT_TECHNIQUE',
      'nativeX2Relabel',
    );
  }

  void onOom({
    required bool changeScale,
    required bool changeModel,
    int? reducedCoreTile,
  }) {
    if (changeScale || changeModel) {
      throw const StudioException(
        'UNSUPPORTED_EDIT_TECHNIQUE',
        'oomSilentChange',
      );
    }
    if (reducedCoreTile != null) {
      coreTile = reducedCoreTile;
    }
  }

  void feedBgrAsRgb() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'bgrAsRgb');
  }

  void swapToRealGan() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'realGanSwap');
  }

  void labelNlmeansAsAi() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'nlmeansAsAi');
  }

  void addHqdn3dToLgplPack() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'hqdn3dLgpl');
  }

  void equateRnnoiseWithScunetOrSr() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'capabilityMix');
  }

  void pauseForOs() {
    disposition = EnhanceDisposition.paused;
  }

  EnhanceReceipt resumeAfterOs() {
    if (disposition != EnhanceDisposition.paused) {
      throw const StudioException('LEASE_STATE_INVALID', 'resume');
    }
    disposition = EnhanceDisposition.resumed;
    return preview();
  }

  void loadFullFilmIntoRam() {
    throw const StudioException('FULL_FILM_RESIDENT', 'ram');
  }

  void releaseVideoByImageQualification() {
    if (!videoGateMet) {
      throw const StudioException(
        'VIDEO_GATE_INDEPENDENT',
        'imageDoesNotLicenseVideo',
      );
    }
  }

  void autoAddFps() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'autoFps');
  }

  void claimInverseTonemapRestoresHdr() {
    throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'hdrInverse');
  }

  void dropWatermarkWarning() {
    throw const StudioException('WATERMARK_WARNING_REQUIRED', 'dropWarning');
  }

  void replaceProtectedTextWithoutWarning() {
    throw const StudioException('WATERMARK_WARNING_REQUIRED', 'replaceText');
  }

  void removeCopyrightWatermark() {
    throw const StudioException('RIGHTS_FORBIDDEN', 'copyrightWatermark');
  }

  void autoApplyFailedFrame() {
    throw const StudioException('FAILED_FRAME_NOT_AUTO_APPLIED', 'failedFrame');
  }

  void autoAccept() {
    if (!v013Met) {
      throw const StudioException('V013_GATE_UNMET', 'autoAccept');
    }
  }

  void fillWithoutQualifiedPack() {
    throw const StudioException('MODEL_ABI_UNVERIFIED', 'srPack');
  }
}
