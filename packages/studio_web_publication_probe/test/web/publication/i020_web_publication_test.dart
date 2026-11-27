import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_web_publication_probe/studio_web_publication_probe.dart';
import 'package:test/test.dart';

/// Increment 3.17 official I-020 / s5c leftover: an external download
/// or file handle is an independent publication and must not reuse
/// POSIX semantics.
///
/// This file does not re-qualify Increment 2.37 / ADR 0136
/// WebMediaPort codec refusal, the OPFS eviction hint, or “canceling
/// a file picker is not a save”. A real OPFS/IndexedDB runtime is not
/// invented. A 60s WebCodecs/OPFS roundtrip and a V-007 production
/// lock are not claimed. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9. I-020 stays partial. Existing I-020
/// remainingAcceptance labels (60s roundtrip within one frame, same
/// project versus native golden command semantics) are not silently
/// cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('an external download or file handle is admitted as independent publication and must not reuse POSIX semantics', () {
    final admission = WebPublicationAdmission();
    for (final kind in const ['externalDownload', 'fileHandle']) {
      final receipt = admission.admit(WebPublicationRequest(kind: kind));
      expect(receipt.admitted, isTrue);
      expect(receipt.independentPublication, isTrue);
      expect(receipt.posixSemantics, isFalse);
    }
    expect(
      () => admission.admit(const WebPublicationRequest(kind: 'unknown')),
      code('WEB_PUBLICATION_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const WebPublicationRequest(
          kind: 'fileHandle',
          claimsPosixSemantics: true,
        ),
      ),
      code('POSIX_SEMANTICS_NOT_REUSED'),
    );
  });

  test('Increment 2.37 WebMediaPort, a V-007 claim, an OPFS runtime, and a StoragePort runtime stay closed', () {
    final admission = WebPublicationAdmission();
    expect(admission.webMediaPortRequalified, isFalse);
    expect(admission.v007Claimed, isFalse);
    expect(admission.sixtySecondRoundtripClaimed, isFalse);
    expect(admission.opfsRuntimeInvented, isFalse);
    expect(admission.storagePortInvented, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
    expect(admission.futureMajorRequalified, isFalse);
    expect(admission.i014RestoreInvented, isFalse);
    expect(admission.ffmpegWasmDefaulted, isFalse);
  });
}
