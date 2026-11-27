import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_media_retention/studio_media_retention.dart';
import 'package:test/test.dart';

/// Increment 2.80 official s6c original/PTS/color-metadata
/// retention slice. This file does not re-qualify V-006 metadata
/// preservation or the Increment 2.79 delivery-fps PTS resample
/// slice, does not invent a real HDR, LUT, or retimer runtime,
/// does not start I-059, does not re-qualify I-024, I-007, V-004
/// leftovers, the Increment 2.78 container-demux slice,
/// CodecProbePort, V-002 format-reason leftovers,
/// ResourceAdmissionController, or I-042 pack leases, does not
/// start CompatibilityStore / ModelLease, and does not mark
/// I-037, I-038, V-007, V-020, I-054, I-051, I-046, I-041,
/// I-040, I-053, I-056, I-057, I-052, I-039, V-026, I-043,
/// I-044, I-045, I-047, I-048, V-006, I-058, V-004, I-024,
/// V-005, V-002, I-007, or I-042 complete. InversePatch kind
/// stays restoreSnapshot. Project user_version stays 9. V-002
/// stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

const sourcePts = [0, 3000, 6000, 9000];

void main() {
  test('original essence and original PTS are retained; replacing the source or dropping PTS is refused', () {
    final port = MediaRetentionAdmission();
    final receipt = port.inspect(
      const RetentionRequest(
        originalHash: 'essence.source.a',
        ptsTicks: sourcePts,
        colorMetadata: 'bt709-limited',
      ),
    );
    expect(receipt.originalRetained, isTrue);
    expect(receipt.ptsRetained, isTrue);
    expect(receipt.originalHash, 'essence.source.a');
    expect(receipt.ptsTicks, sourcePts);
    expect(receipt.unsupportedNotice, isTrue);
    expect(receipt.derivedNormalization, isFalse);
    expect(
      () => port.inspect(
        const RetentionRequest(
          originalHash: 'essence.source.a',
          ptsTicks: sourcePts,
          colorMetadata: 'bt709-limited',
          replaceOriginal: true,
        ),
      ),
      code('SOURCE_NOT_RETAINED'),
    );
    expect(
      () => port.inspect(
        const RetentionRequest(
          originalHash: 'essence.source.a',
          ptsTicks: sourcePts,
          colorMetadata: 'bt709-limited',
          dropPts: true,
        ),
      ),
      code('PTS_NOT_RETAINED'),
    );
  });

  test('color metadata stays with the retained original; normalization must be explicit or the path is an unsupported notice', () {
    final port = MediaRetentionAdmission();
    expect(
      () => port.inspect(
        const RetentionRequest(
          originalHash: 'essence.source.a',
          ptsTicks: sourcePts,
          colorMetadata: 'bt709-limited',
          dropColorMetadata: true,
        ),
      ),
      code('COLOR_METADATA_NOT_RETAINED'),
    );
    expect(
      () => port.inspect(
        const RetentionRequest(
          originalHash: 'essence.source.a',
          ptsTicks: sourcePts,
          colorMetadata: 'bt709-limited',
          normalize: true,
        ),
      ),
      code('NORMALIZATION_MUST_BE_EXPLICIT'),
    );
    final derived = port.inspect(
      const RetentionRequest(
        originalHash: 'essence.source.a',
        ptsTicks: sourcePts,
        colorMetadata: 'bt709-limited',
        normalize: true,
        explicitNormalize: true,
      ),
    );
    expect(derived.derivedNormalization, isTrue);
    expect(derived.unsupportedNotice, isFalse);
    expect(derived.originalRetained, isTrue);
    expect(derived.ptsRetained, isTrue);
    expect(derived.colorMetadataRetained, isTrue);
    expect(derived.originalHash, 'essence.source.a');
    expect(derived.colorMetadata, 'bt709-limited');
  });

  test('V-006 metadata preservation and Increment 2.79 delivery-fps leftovers stay closed', () {
    final port = MediaRetentionAdmission();
    expect(port.v006Requalified, isFalse);
    expect(port.deliveryFpsRequalified, isFalse);
    expect(port.hdrRuntimeInvented, isFalse);
    expect(port.lutRuntimeInvented, isFalse);
    expect(port.retimerInvented, isFalse);
    expect(port.muxerInvented, isFalse);
    expect(port.i059Started, isFalse);
    expect(port.paidApiCalled, isFalse);
  });
}
