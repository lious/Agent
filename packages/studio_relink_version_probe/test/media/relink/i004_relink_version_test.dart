import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_relink_version_probe/studio_relink_version_probe.dart';
import 'package:test/test.dart';

/// Increment 2.87 official I-004 / s4 leftover: a different hash is
/// admitted only as an explicit new version after duration/stream/color
/// differences are reviewed, and must not be auto-replaced by filename.
/// This file does not rewrite files_test, blob_store, or Increment 2.86
/// ProxyDeliveryAdmission, does not invent RelinkProposal / FileToken /
/// AssetRepository as a product surface, and does not re-qualify
/// RELINK_HASH_MISMATCH. InversePatch kind stays restoreSnapshot.
/// Project user_version stays 9. I-004 stays partial.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

const expected = 'sha256:expected';
const actual = 'sha256:actual';

void main() {
  test('a different hash is admitted only as an explicit new version after duration, stream, and color differences are reviewed', () {
    final admission = RelinkVersionAdmission();
    expect(
      admission
          .admit(
            const RelinkVersionRequest(
              expectedHash: expected,
              actualHash: expected,
            ),
          )
          .newVersion,
      isFalse,
    );
    final created = admission.admit(
      const RelinkVersionRequest(
        expectedHash: expected,
        actualHash: actual,
        explicitNewVersion: true,
        durationReviewed: true,
        streamReviewed: true,
        colorReviewed: true,
      ),
    );
    expect(created.newVersion, isTrue);
    expect(
      () => admission.admit(
        const RelinkVersionRequest(expectedHash: expected, actualHash: actual),
      ),
      code('RELINK_VERSION_UNCONFIRMED'),
    );
  });

  test('auto-replace by filename is refused; an unreviewed explicit new version is refused', () {
    final admission = RelinkVersionAdmission();
    expect(
      () => admission.admit(
        const RelinkVersionRequest(
          expectedHash: expected,
          actualHash: actual,
          autoReplaceByFilename: true,
        ),
      ),
      code('FILENAME_AUTOREPLACE_FORBIDDEN'),
    );
    expect(
      () => admission.admit(
        const RelinkVersionRequest(
          expectedHash: expected,
          actualHash: actual,
          explicitNewVersion: true,
          durationReviewed: true,
          streamReviewed: true,
        ),
      ),
      code('RELINK_DIFFERENCES_UNREVIEWED'),
    );
  });

  test('files_test RELINK_HASH_MISMATCH, ProxyDeliveryAdmission, and RelinkProposal product surfaces stay closed', () {
    final admission = RelinkVersionAdmission();
    expect(admission.filesTestRequalified, isFalse);
    expect(admission.proxyDeliveryRequalified, isFalse);
    expect(admission.relinkProposalInvented, isFalse);
    expect(admission.fileTokenInvented, isFalse);
    expect(admission.assetRepositoryInvented, isFalse);
    expect(admission.paidApiCalled, isFalse);
  });
}
