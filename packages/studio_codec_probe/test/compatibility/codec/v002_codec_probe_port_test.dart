import 'package:studio_codec_probe/studio_codec_probe.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

/// Increment 2.76 official s6c CodecProbePort slice. This file
/// does not invent a real codec probe, does not re-qualify V-002
/// format-reason or I-015 leftovers, does not re-qualify the
/// Increment 2.75 DeviceProbeService / CompatibilityRegistry
/// slice, the 2.74 CompatibilityFallbackPlanner, V-001 toolchain
/// probes, or I-042 leases, does not start
/// ResourceAdmissionController, I-059, I-061, or I-055, and does
/// not mark I-037, I-038, V-007, V-020, I-054, I-051, I-046,
/// I-041, I-040, I-053, I-056, I-057, I-052, I-039, V-026,
/// I-043, I-044, I-045, I-047, I-048, V-006, I-058, V-004,
/// I-024, V-005, or V-002 complete. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. V-002 stays
/// partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('decode and encode are not interchangeable', () {
    final port = CodecProbePort();
    expect(
      () => port.probe(
        const CodecProbeRequest(
          direction: ProbeDirection.decode,
          modality: MediaModality.video,
          container: 'mp4',
          codec: 'h264',
          sessionCreated: true,
          sampleProcessed: true,
          applyAs: ProbeDirection.encode,
        ),
      ),
      code('DECODE_ENCODE_NOT_INTERCHANGEABLE'),
    );
    expect(
      () => port.probe(
        const CodecProbeRequest(
          direction: ProbeDirection.encode,
          modality: MediaModality.audio,
          container: 'mp4',
          codec: 'aac',
          sessionCreated: true,
          sampleProcessed: true,
          applyAs: ProbeDirection.decode,
        ),
      ),
      code('DECODE_ENCODE_NOT_INTERCHANGEABLE'),
    );
    final decoded = port.probe(
      const CodecProbeRequest(
        direction: ProbeDirection.decode,
        modality: MediaModality.video,
        container: 'mp4',
        codec: 'h264',
        width: '1920',
        height: '1080',
        sessionCreated: true,
        sampleProcessed: true,
        claimSupported: true,
        applyAs: ProbeDirection.decode,
      ),
    );
    expect(decoded.direction, ProbeDirection.decode);
    expect(decoded.supported, isTrue);
  });

  test('unknown is not written as supported=true; advertised without a processed sample is not a qualification', () {
    final port = CodecProbePort();
    expect(
      () => port.probe(
        const CodecProbeRequest(
          direction: ProbeDirection.decode,
          modality: MediaModality.video,
          container: 'mp4',
          codec: 'hevc',
          unknown: true,
          advertised: true,
          claimSupported: true,
        ),
      ),
      code('UNKNOWN_NOT_SUPPORTED'),
    );
    expect(
      () => port.probe(
        const CodecProbeRequest(
          direction: ProbeDirection.encode,
          modality: MediaModality.video,
          container: 'mp4',
          codec: 'h264',
          advertised: true,
          claimSupported: true,
        ),
      ),
      code('UNKNOWN_NOT_SUPPORTED'),
    );
    final advertisedOnly = port.probe(
      const CodecProbeRequest(
        direction: ProbeDirection.decode,
        modality: MediaModality.video,
        container: 'mp4',
        codec: 'h264',
        advertised: true,
      ),
    );
    expect(advertisedOnly.advertised, isTrue);
    expect(advertisedOnly.sampleProcessed, isFalse);
    expect(advertisedOnly.supported, isFalse);
    expect(
      () => port.probe(
        const CodecProbeRequest(
          direction: ProbeDirection.decode,
          modality: MediaModality.audio,
          container: 'mp4',
          codec: 'aac',
          inferAudioFromVideoCaps: true,
        ),
      ),
      code('COMBINATION_NOT_INFERRED'),
    );
  });

  test('unrelated modality fields stay null, not forged 0; V-002 format-reason and I-015 leftovers stay closed', () {
    final port = CodecProbePort();
    final video = port.probe(
      const CodecProbeRequest(
        direction: ProbeDirection.decode,
        modality: MediaModality.video,
        container: 'mp4',
        codec: 'h264',
        width: '1920',
        height: '1080',
        fpsNum: '30',
        fpsDen: '1',
        sessionCreated: true,
        sampleProcessed: true,
      ),
    );
    expect(video.width, '1920');
    expect(video.sampleRate, isNull);
    expect(video.channelCount, isNull);
    expect(video.bitrate, isNull);
    expect(video.sampleFormat, isNull);
    final audio = port.probe(
      const CodecProbeRequest(
        direction: ProbeDirection.decode,
        modality: MediaModality.audio,
        container: 'mp4',
        codec: 'aac',
        sampleRate: '48000',
        channelCount: '2',
        sessionCreated: true,
        sampleProcessed: true,
      ),
    );
    expect(audio.sampleRate, '48000');
    expect(audio.width, isNull);
    expect(audio.height, isNull);
    expect(audio.fpsNum, isNull);
    expect(
      () => port.probe(
        const CodecProbeRequest(
          direction: ProbeDirection.decode,
          modality: MediaModality.video,
          container: 'mp4',
          codec: 'h264',
          sampleRate: '0',
        ),
      ),
      code('FORGED_MODALITY_ZERO'),
    );
    expect(
      () => port.probe(
        const CodecProbeRequest(
          direction: ProbeDirection.decode,
          modality: MediaModality.audio,
          container: 'mp4',
          codec: 'aac',
          width: '0',
          forgeUnrelatedZeros: true,
        ),
      ),
      code('FORGED_MODALITY_ZERO'),
    );
    expect(port.realProbeInvented, isFalse);
    expect(port.formatReasonRequalified, isFalse);
    expect(port.i015Requalified, isFalse);
    expect(port.registryRequalified, isFalse);
    expect(port.fallbackPlannerRequalified, isFalse);
    expect(port.v001Requalified, isFalse);
    expect(port.i042LeaseRequalified, isFalse);
    expect(port.paidApiCalled, isFalse);
    expect(port.v007Claimed, isFalse);
  });
}
