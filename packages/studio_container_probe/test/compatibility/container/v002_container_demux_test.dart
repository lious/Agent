import 'package:studio_container_probe/studio_container_probe.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

/// Increment 2.78 official s6c container-demux admission slice.
/// This file does not invent a real demuxer or muxer, does not
/// re-qualify the Increment 2.76 CodecProbePort slice or V-002
/// format-reason leftovers, does not re-qualify the Increment
/// 2.77 ResourceAdmissionController slice or I-042 pack leases,
/// does not start CompatibilityStore / ModelLease, does not
/// re-qualify the 2.75 registry, 2.74 fallback planner, V-001,
/// or I-015 leftovers, does not start I-059, I-061, or I-055,
/// and does not mark I-037, I-038, V-007, V-020, I-054, I-051,
/// I-046, I-041, I-040, I-053, I-056, I-057, I-052, I-039,
/// V-026, I-043, I-044, I-045, I-047, I-048, V-006, I-058,
/// V-004, I-024, V-005, V-002, or I-042 complete. InversePatch
/// kind stays restoreSnapshot. Project user_version stays 9.
/// V-002 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a demuxed container does not imply the bitstream can be decoded', () {
    final port = ContainerDemuxAdmission();
    final receipt = port.inspect(
      const DemuxRequest(container: 'mp4', containerDemuxed: true),
    );
    expect(receipt.containerDemuxed, isTrue);
    expect(receipt.bitstreamDecodable, isFalse);
    expect(receipt.bitstreamEncodable, isFalse);
    expect(
      () => port.inspect(
        const DemuxRequest(
          container: 'mp4',
          containerDemuxed: true,
          claimDecodableFromDemux: true,
        ),
      ),
      code('DEMUX_NOT_DECODE'),
    );
  });

  test('a demuxed container does not imply the bitstream can be encoded', () {
    final port = ContainerDemuxAdmission();
    expect(
      () => port.inspect(
        const DemuxRequest(
          container: 'mp4',
          containerDemuxed: true,
          claimEncodableFromDemux: true,
        ),
      ),
      code('DEMUX_NOT_ENCODE'),
    );
    final decodedOnly = port.inspect(
      const DemuxRequest(
        container: 'mp4',
        containerDemuxed: true,
        bitstreamDecoded: true,
      ),
    );
    expect(decodedOnly.bitstreamDecodable, isTrue);
    expect(decodedOnly.bitstreamEncodable, isFalse);
  });

  test('independent fixtures are not inherited from a baseline MP4 demux; CodecProbePort and format-reason leftovers stay closed', () {
    final port = ContainerDemuxAdmission();
    expect(
      () => port.inspect(
        const DemuxRequest(
          container: 'mp4',
          containerDemuxed: true,
          inheritIndependentFixture: IndependentFixture.hevc10,
        ),
      ),
      code('INDEPENDENT_FIXTURE_REQUIRED'),
    );
    expect(
      () => port.inspect(
        const DemuxRequest(
          container: 'mp4',
          containerDemuxed: true,
          inheritIndependentFixture: IndependentFixture.hdrPq,
        ),
      ),
      code('INDEPENDENT_FIXTURE_REQUIRED'),
    );
    final receipt = port.inspect(
      const DemuxRequest(container: 'mp4', containerDemuxed: true),
    );
    expect(receipt.independentFixtureInherited, isFalse);
    expect(port.realDemuxerInvented, isFalse);
    expect(port.codecProbeRequalified, isFalse);
    expect(port.formatReasonRequalified, isFalse);
    expect(port.i015Requalified, isFalse);
    expect(port.resourceAdmissionRequalified, isFalse);
    expect(port.i042LeaseRequalified, isFalse);
    expect(port.v007Claimed, isFalse);
    expect(port.muxerInvented, isFalse);
    expect(port.paidApiCalled, isFalse);
  });
}
