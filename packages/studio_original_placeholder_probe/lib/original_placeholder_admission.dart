import 'package:studio_contracts/studio_contracts.dart';

const originalRecoveryKinds = {'cache', 'original'};

final class OriginalPlaceholderRequest {
  const OriginalPlaceholderRequest({
    required this.kind,
    this.replaceWithPlaceholder = false,
  });

  /// `cache` or `original`.
  final String kind;
  final bool replaceWithPlaceholder;
}

final class OriginalPlaceholderReceipt {
  const OriginalPlaceholderReceipt({
    required this.admitted,
    required this.reportedMissing,
    required this.placeholderUsed,
    required this.cacheMayRebuild,
  });

  final bool admitted;
  final bool reportedMissing;
  final bool placeholderUsed;
  final bool cacheMayRebuild;
}

/// DEV-PURE I-011 / s5c admission: a bad cache may be rebuilt, but
/// a bad original is reported as a missing resource and must not
/// be replaced with a fake image.
///
/// This does not re-qualify I-011 crash leftovers (last good
/// snapshot+tail, unique-copy, schema roundtrip), Increment 3.14
/// CasDbGapAdmission, AtomicFilePublisher, files_test,
/// save_crash_test, I-004 MISSING_MEDIA / Increment 2.86 proxy
/// delivery, or I-014 “migration keeps a good copy.” ACK-lost
/// receipt retry, crash-after-CAS orphan claim/GC, a RestoreService,
/// and a Flutter widget tree are not invented. The same s5c row’s
/// migration, unique-DB, writer-lock, and WAL-recovery sentences
/// are not officialized here.
final class OriginalPlaceholderAdmission {
  bool lastGoodSnapshotRequalified = false;
  bool uniqueCopyRequalified = false;
  bool schemaRoundtripRequalified = false;
  bool casDbGapRequalified = false;
  bool i004MissingMediaRequalified = false;
  bool proxyDeliveryRequalified = false;
  bool migrationCopyRequalified = false;
  bool writerFenceRequalified = false;
  bool ackLostRetryOfficialized = false;
  bool orphanClaimInvented = false;
  bool restoreInvented = false;
  bool flutterWidgetTreeInvented = false;
  bool walRecoveryDisabled = false;

  OriginalPlaceholderReceipt admit(OriginalPlaceholderRequest request) {
    if (!originalRecoveryKinds.contains(request.kind)) {
      throw const StudioException(
        'ORIGINAL_RECOVERY_KIND_UNKNOWN',
        'publication',
      );
    }
    if (request.kind == 'cache') {
      return const OriginalPlaceholderReceipt(
        admitted: true,
        reportedMissing: false,
        placeholderUsed: false,
        cacheMayRebuild: true,
      );
    }
    if (request.replaceWithPlaceholder) {
      throw const StudioException(
        'PLACEHOLDER_ORIGINAL_FORBIDDEN',
        'publication',
      );
    }
    return const OriginalPlaceholderReceipt(
      admitted: true,
      reportedMissing: true,
      placeholderUsed: false,
      cacheMayRebuild: true,
    );
  }
}
