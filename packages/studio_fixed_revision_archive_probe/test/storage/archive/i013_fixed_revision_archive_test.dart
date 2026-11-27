import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_fixed_revision_archive_probe/studio_fixed_revision_archive_probe.dart';
import 'package:test/test.dart';

/// Increment 3.30 official I-013 / s5d leftover: a fixed-revision
/// portable archive must not include pending-job future outputs,
/// must not be mutated when a later job completes, must not
/// cancel a paid job on the user's behalf, and must disclose
/// pending jobs when they exist. Edits during the archive only
/// affect a new revision.
///
/// This file does not invent I-013 job archival and does not
/// re-qualify Increment 3.06 ArtifactKindAdmission or Increment
/// 3.04 JobCancelAdmission. The PENDING_MEDIA complete-archive
/// sentence is not officialized. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. I-013 stays
/// partial. Existing I-013 remainingAcceptance wording is not
/// silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('a fixed-revision portable archive excludes future outputs, stays immutable after publish, must not cancel a paid job, and discloses pending jobs', () {
    final admission = FixedRevisionArchiveAdmission();
    final clean = admission.admit(
      const FixedRevisionArchiveRequest(kind: 'portableArchive'),
    );
    expect(clean.admitted, isTrue);
    expect(clean.futureOutputsIncluded, isFalse);
    expect(clean.publishedPackageMutable, isFalse);
    expect(clean.paidJobCancelled, isFalse);
    expect(clean.pendingDisclosed, isFalse);

    final pending = admission.admit(
      const FixedRevisionArchiveRequest(
        kind: 'portableArchive',
        hasPendingJobs: true,
        disclosesPendingJobs: true,
      ),
    );
    expect(pending.admitted, isTrue);
    expect(pending.pendingDisclosed, isTrue);
    expect(pending.futureOutputsIncluded, isFalse);

    expect(
      () => admission.admit(const FixedRevisionArchiveRequest(kind: 'unknown')),
      code('FIXED_REVISION_ARCHIVE_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const FixedRevisionArchiveRequest(
          kind: 'portableArchive',
          includesFutureOutputs: true,
        ),
      ),
      code('FUTURE_OUTPUT_NOT_INCLUDED'),
    );
    expect(
      () => admission.admit(
        const FixedRevisionArchiveRequest(
          kind: 'portableArchive',
          mutatesPublishedPackageOnLaterCompletion: true,
        ),
      ),
      code('PUBLISHED_PACKAGE_IMMUTABLE'),
    );
    expect(
      () => admission.admit(
        const FixedRevisionArchiveRequest(
          kind: 'portableArchive',
          cancelsPaidJob: true,
        ),
      ),
      code('ARCHIVE_PAID_JOB_CANCEL_FORBIDDEN'),
    );
    expect(
      () => admission.admit(
        const FixedRevisionArchiveRequest(
          kind: 'portableArchive',
          hasPendingJobs: true,
        ),
      ),
      code('PENDING_JOB_DISCLOSURE_REQUIRED'),
    );
    expect(
      () => admission.admit(
        const FixedRevisionArchiveRequest(
          kind: 'portableArchive',
          editsAffectArchivedRevision: true,
        ),
      ),
      code('ARCHIVE_EDIT_NEW_REVISION_ONLY'),
    );
  });

  test('I-013 job archival, Increment 3.06 ArtifactKindAdmission, Increment 3.04 JobCancelAdmission, and paid APIs stay closed', () {
    final admission = FixedRevisionArchiveAdmission();
    expect(admission.jobArchivalInvented, isFalse);
    expect(admission.artifactKindRequalified, isFalse);
    expect(admission.jobCancelRequalified, isFalse);
    expect(admission.unknownExtensionPinRequalified, isFalse);
    expect(admission.pendingMediaCompleteRequalified, isFalse);
    expect(admission.generatedOutputRequalified, isFalse);
    expect(admission.attachRequalified, isFalse);
    expect(admission.quoteApplyStarted, isFalse);
    expect(admission.paidApiCalled, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
    expect(admission.restoreInvented, isFalse);
  });
}
