import 'package:studio_contracts/studio_contracts.dart';

final class RelinkVersionRequest {
  const RelinkVersionRequest({
    required this.expectedHash,
    required this.actualHash,
    this.explicitNewVersion = false,
    this.durationReviewed = false,
    this.streamReviewed = false,
    this.colorReviewed = false,
    this.autoReplaceByFilename = false,
  });

  final String expectedHash, actualHash;
  final bool explicitNewVersion,
      durationReviewed,
      streamReviewed,
      colorReviewed,
      autoReplaceByFilename;

  bool get sameHash => expectedHash == actualHash;
}

final class RelinkVersionReceipt {
  const RelinkVersionReceipt({required this.newVersion});

  final bool newVersion;
}

/// DEV-PURE I-004 / s4 admission: a different hash may be adopted only as
/// an explicit new version after duration/stream/color differences are
/// reviewed, and must not be auto-replaced by filename. This is not
/// `RELINK_HASH_MISMATCH`, not a RelinkProposal / FileToken / AssetRepository
/// product surface, and not a re-qualification of files_test or Increment
/// 2.86 ProxyDeliveryAdmission.
final class RelinkVersionAdmission {
  bool filesTestRequalified = false;
  bool proxyDeliveryRequalified = false;
  bool relinkProposalInvented = false;
  bool fileTokenInvented = false;
  bool assetRepositoryInvented = false;
  bool paidApiCalled = false;

  RelinkVersionReceipt admit(RelinkVersionRequest request) {
    if (request.sameHash) {
      return const RelinkVersionReceipt(newVersion: false);
    }
    if (request.autoReplaceByFilename) {
      throw const StudioException('FILENAME_AUTOREPLACE_FORBIDDEN', 'relink');
    }
    if (!request.explicitNewVersion) {
      throw const StudioException('RELINK_VERSION_UNCONFIRMED', 'relink');
    }
    if (!request.durationReviewed ||
        !request.streamReviewed ||
        !request.colorReviewed) {
      throw const StudioException('RELINK_DIFFERENCES_UNREVIEWED', 'relink');
    }
    return const RelinkVersionReceipt(newVersion: true);
  }
}
