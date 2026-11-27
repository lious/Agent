import 'package:studio_contracts/studio_contracts.dart';

const fixedRevisionArchiveKinds = {'portableArchive'};

final class FixedRevisionArchiveRequest {
  const FixedRevisionArchiveRequest({
    required this.kind,
    this.hasPendingJobs = false,
    this.disclosesPendingJobs = false,
    this.includesFutureOutputs = false,
    this.mutatesPublishedPackageOnLaterCompletion = false,
    this.cancelsPaidJob = false,
    this.editsAffectArchivedRevision = false,
  });

  /// `portableArchive`.
  final String kind;
  final bool hasPendingJobs;
  final bool disclosesPendingJobs;
  final bool includesFutureOutputs;
  final bool mutatesPublishedPackageOnLaterCompletion;
  final bool cancelsPaidJob;
  final bool editsAffectArchivedRevision;
}

final class FixedRevisionArchiveReceipt {
  const FixedRevisionArchiveReceipt({
    required this.admitted,
    required this.futureOutputsIncluded,
    required this.publishedPackageMutable,
    required this.paidJobCancelled,
    required this.pendingDisclosed,
  });

  final bool admitted;
  final bool futureOutputsIncluded;
  final bool publishedPackageMutable;
  final bool paidJobCancelled;
  final bool pendingDisclosed;
}

/// DEV-PURE I-013 / s5d admission: a fixed-revision portable
/// archive must not include pending-job future outputs, must
/// not be mutated when a later job completes, must not cancel
/// a paid job on the user's behalf, and must disclose pending
/// jobs when they exist. Edits during the archive only affect
/// a new revision.
///
/// This does not invent I-013 job archival and does not
/// re-qualify Increment 3.06 ArtifactKindAdmission, Increment
/// 3.04 JobCancelAdmission, Increment 3.29
/// UnknownExtensionPinAdmission, or the unofficialized
/// PENDING_MEDIA complete-archive sentence. Quote/apply and
/// paid APIs are not started. I-040 generated output and I-004
/// attach are not re-qualified.
final class FixedRevisionArchiveAdmission {
  bool jobArchivalInvented = false;
  bool artifactKindRequalified = false;
  bool jobCancelRequalified = false;
  bool unknownExtensionPinRequalified = false;
  bool pendingMediaCompleteRequalified = false;
  bool generatedOutputRequalified = false;
  bool attachRequalified = false;
  bool quoteApplyStarted = false;
  bool paidApiCalled = false;
  bool flutterWidgetTreeInvented = false;
  bool restoreInvented = false;

  FixedRevisionArchiveReceipt admit(FixedRevisionArchiveRequest request) {
    if (!fixedRevisionArchiveKinds.contains(request.kind)) {
      throw const StudioException(
        'FIXED_REVISION_ARCHIVE_KIND_UNKNOWN',
        'publication',
      );
    }
    if (request.includesFutureOutputs) {
      throw const StudioException('FUTURE_OUTPUT_NOT_INCLUDED', 'publication');
    }
    if (request.mutatesPublishedPackageOnLaterCompletion) {
      throw const StudioException('PUBLISHED_PACKAGE_IMMUTABLE', 'publication');
    }
    if (request.cancelsPaidJob) {
      throw const StudioException(
        'ARCHIVE_PAID_JOB_CANCEL_FORBIDDEN',
        'publication',
      );
    }
    if (request.hasPendingJobs && !request.disclosesPendingJobs) {
      throw const StudioException(
        'PENDING_JOB_DISCLOSURE_REQUIRED',
        'publication',
      );
    }
    if (request.editsAffectArchivedRevision) {
      throw const StudioException(
        'ARCHIVE_EDIT_NEW_REVISION_ONLY',
        'publication',
      );
    }
    return FixedRevisionArchiveReceipt(
      admitted: true,
      futureOutputsIncluded: false,
      publishedPackageMutable: false,
      paidJobCancelled: false,
      pendingDisclosed: request.hasPendingJobs,
    );
  }
}
