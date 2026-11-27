import 'package:studio_contracts/studio_contracts.dart';

enum IndependentFixture {
  hevc10,
  chroma422,
  chroma444,
  uhd60,
  hdrPq,
  hdrHlg,
  prores,
  alpha,
  vfr,
}

final class DemuxRequest {
  const DemuxRequest({
    required this.container,
    this.containerDemuxed = false,
    this.bitstreamDecoded = false,
    this.bitstreamEncoded = false,
    this.claimDecodableFromDemux = false,
    this.claimEncodableFromDemux = false,
    this.inheritIndependentFixture,
  });

  final String container;
  final bool containerDemuxed,
      bitstreamDecoded,
      bitstreamEncoded,
      claimDecodableFromDemux,
      claimEncodableFromDemux;
  final IndependentFixture? inheritIndependentFixture;
}

final class DemuxReceipt {
  DemuxReceipt({
    required this.containerDemuxed,
    required this.bitstreamDecodable,
    required this.bitstreamEncodable,
    required this.independentFixtureInherited,
  });

  final bool containerDemuxed,
      bitstreamDecodable,
      bitstreamEncodable,
      independentFixtureInherited;
}

/// DEV-PURE s6c container-demux admission. A demuxed container does
/// not imply the bitstream can be decoded or encoded. This is not a
/// real demuxer and not a re-qualification of CodecProbePort or
/// V-002 format-reason leftovers.
final class ContainerDemuxAdmission {
  bool realDemuxerInvented = false;
  bool codecProbeRequalified = false;
  bool formatReasonRequalified = false;
  bool i015Requalified = false;
  bool resourceAdmissionRequalified = false;
  bool i042LeaseRequalified = false;
  bool v007Claimed = false;
  bool muxerInvented = false;
  bool paidApiCalled = false;

  DemuxReceipt inspect(DemuxRequest request) {
    if (request.claimDecodableFromDemux) {
      throw const StudioException('DEMUX_NOT_DECODE', 'bitstream');
    }
    if (request.claimEncodableFromDemux) {
      throw const StudioException('DEMUX_NOT_ENCODE', 'bitstream');
    }
    if (request.inheritIndependentFixture != null && request.containerDemuxed) {
      throw StudioException(
        'INDEPENDENT_FIXTURE_REQUIRED',
        request.inheritIndependentFixture!.name,
      );
    }
    return DemuxReceipt(
      containerDemuxed: request.containerDemuxed,
      bitstreamDecodable: request.bitstreamDecoded,
      bitstreamEncodable: request.bitstreamEncoded,
      independentFixtureInherited: false,
    );
  }
}
