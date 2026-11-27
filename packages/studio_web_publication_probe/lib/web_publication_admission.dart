import 'package:studio_contracts/studio_contracts.dart';

const webPublicationKinds = {'externalDownload', 'fileHandle'};

final class WebPublicationRequest {
  const WebPublicationRequest({
    required this.kind,
    this.claimsPosixSemantics = false,
  });

  /// `externalDownload` or `fileHandle`.
  final String kind;
  final bool claimsPosixSemantics;
}

final class WebPublicationReceipt {
  const WebPublicationReceipt({
    required this.admitted,
    required this.independentPublication,
    required this.posixSemantics,
  });

  final bool admitted;
  final bool independentPublication;
  final bool posixSemantics;
}

/// DEV-PURE I-020 / s5c admission: an external download or file handle
/// is an independent publication and must not reuse POSIX semantics.
///
/// This does not re-qualify Increment 2.37 / ADR 0136 WebMediaPort
/// codec refusal, the OPFS eviction hint, or “canceling a file picker
/// is not a save”. A real OPFS/IndexedDB runtime is not invented. A
/// 60s WebCodecs/OPFS roundtrip and a V-007 production lock are not
/// claimed. A StoragePort runtime is not invented.
final class WebPublicationAdmission {
  bool webMediaPortRequalified = false;
  bool v007Claimed = false;
  bool sixtySecondRoundtripClaimed = false;
  bool opfsRuntimeInvented = false;
  bool storagePortInvented = false;
  bool flutterWidgetTreeInvented = false;
  bool futureMajorRequalified = false;
  bool i014RestoreInvented = false;
  bool ffmpegWasmDefaulted = false;

  WebPublicationReceipt admit(WebPublicationRequest request) {
    if (!webPublicationKinds.contains(request.kind)) {
      throw const StudioException(
        'WEB_PUBLICATION_KIND_UNKNOWN',
        'publication',
      );
    }
    if (request.claimsPosixSemantics) {
      throw const StudioException('POSIX_SEMANTICS_NOT_REUSED', 'publication');
    }
    return const WebPublicationReceipt(
      admitted: true,
      independentPublication: true,
      posixSemantics: false,
    );
  }
}
