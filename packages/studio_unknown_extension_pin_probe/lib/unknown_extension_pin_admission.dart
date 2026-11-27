import 'package:studio_contracts/studio_contracts.dart';

const unknownExtensionPinKinds = {'archiveClosure'};

final class UnknownExtensionPinRequest {
  const UnknownExtensionPinRequest({
    required this.kind,
    this.unknownExtensionPresent = false,
    this.referencesEnumerable = true,
    this.conservativelyPinned = false,
    this.claimsCompleteArchive = false,
  });

  /// `archiveClosure`.
  final String kind;
  final bool unknownExtensionPresent;
  final bool referencesEnumerable;
  final bool conservativelyPinned;
  final bool claimsCompleteArchive;
}

final class UnknownExtensionPinReceipt {
  const UnknownExtensionPinReceipt({
    required this.admitted,
    required this.conservativelyPinned,
    required this.completeArchiveClaimed,
  });

  final bool admitted;
  final bool conservativelyPinned;
  final bool completeArchiveClaimed;
}

/// DEV-PURE I-013 / s5d admission: when an unknown extension's
/// references cannot be enumerated, those bytes must be pinned
/// conservatively and the archive must not be claimed complete.
///
/// This does not re-qualify I-004 same-hash single blob, ADR 0099
/// session/journal exclusion, I-029 DeletionBarrier, Increment
/// 2.50 packMode / sourceCompleteness, or the PENDING_MEDIA /
/// RESOURCE_MISSING “do not mislabel a complete archive or final
/// render” sentence, which remains unofficial. Increment 3.28
/// ArchiveCountdownAdmission and Increment 3.27
/// LibraryArchiveAdmission are not re-qualified. A BackupStore
/// runtime is not invented. Incremental blob dedup, private
/// session-DB backup exclusion, and privacy-immediate purge are
/// not officialized here.
final class UnknownExtensionPinAdmission {
  bool sameHashRequalified = false;
  bool credentialsDeletedBodyRequalified = false;
  bool deletionBarrierRequalified = false;
  bool packModeRequalified = false;
  bool pendingMediaCompleteRequalified = false;
  bool archiveCountdownRequalified = false;
  bool libraryArchiveRequalified = false;
  bool artifactKindRequalified = false;
  bool backupStoreInvented = false;
  bool jobArchivalInvented = false;
  bool productionFtsClaimed = false;

  UnknownExtensionPinReceipt admit(UnknownExtensionPinRequest request) {
    if (!unknownExtensionPinKinds.contains(request.kind)) {
      throw const StudioException(
        'UNKNOWN_EXTENSION_PIN_KIND_UNKNOWN',
        'publication',
      );
    }
    final unenumerable =
        request.unknownExtensionPresent && !request.referencesEnumerable;
    if (unenumerable && !request.conservativelyPinned) {
      throw const StudioException('CONSERVATIVE_PIN_REQUIRED', 'publication');
    }
    if (unenumerable && request.claimsCompleteArchive) {
      throw const StudioException(
        'UNKNOWN_EXTENSION_FALSE_COMPLETE',
        'publication',
      );
    }
    return UnknownExtensionPinReceipt(
      admitted: true,
      conservativelyPinned: unenumerable,
      completeArchiveClaimed: false,
    );
  }
}
