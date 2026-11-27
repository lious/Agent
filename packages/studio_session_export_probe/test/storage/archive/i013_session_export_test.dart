import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_session_export_probe/studio_session_export_probe.dart';
import 'package:test/test.dart';

/// Increment 3.24 official I-013 / s5a–s5d leftover: when session
/// content is not included, contentRefs are redacted placeholder
/// IDs and body blobs are not retained; command bodies are not
/// exported; and runs are historical or interruptedOnExport, not
/// live.
///
/// This file does not re-qualify Increment 1.92 / ADR 0099 default
/// session and command-journal exclusion, Increment 3.22
/// AuditJournalAdmission, or ADR 0018 no job-resume binding. Job
/// archival and an I-014 RestoreService are not invented.
/// InversePatch kind stays restoreSnapshot. Project user_version
/// stays 9. I-013 stays partial. Existing I-013 remainingAcceptance
/// wording is not silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('when session content is omitted, refs stay redacted, command bodies are omitted, and runs are historical', () {
    final admission = SessionExportAdmission();
    final omitted = admission.admit(
      const SessionExportRequest(kind: 'sessionExport'),
    );
    expect(omitted.admitted, isTrue);
    expect(omitted.contentRedacted, isTrue);
    expect(omitted.bodyBlobsIncluded, isFalse);
    expect(omitted.commandBodiesIncluded, isFalse);
    expect(omitted.runsHistorical, isTrue);

    final interrupted = admission.admit(
      const SessionExportRequest(
        kind: 'sessionExport',
        runState: 'interruptedOnExport',
      ),
    );
    expect(interrupted.admitted, isTrue);
    expect(interrupted.runsHistorical, isTrue);

    expect(
      () => admission.admit(const SessionExportRequest(kind: 'unknown')),
      code('SESSION_EXPORT_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const SessionExportRequest(
          kind: 'sessionExport',
          includesBodyBlobs: true,
        ),
      ),
      code('SESSION_BODY_BLOB_FORBIDDEN'),
    );
    expect(
      () => admission.admit(
        const SessionExportRequest(
          kind: 'sessionExport',
          contentRefsRedacted: false,
        ),
      ),
      code('SESSION_CONTENT_NOT_REDACTED'),
    );
    expect(
      () => admission.admit(
        const SessionExportRequest(
          kind: 'sessionExport',
          commandBodiesIncluded: true,
        ),
      ),
      code('COMMAND_BODY_NOT_EXPORTED'),
    );
    expect(
      () => admission.admit(
        const SessionExportRequest(kind: 'sessionExport', runState: 'live'),
      ),
      code('RUN_MUST_BE_HISTORICAL'),
    );
  });

  test('ADR 0099 default session exclusion, AuditJournalAdmission, job-resume binding, and job archival stay closed', () {
    final admission = SessionExportAdmission();
    expect(admission.credentialsDeletedBodyRequalified, isFalse);
    expect(admission.auditJournalRequalified, isFalse);
    expect(admission.jobResumeRequalified, isFalse);
    expect(admission.i054Requalified, isFalse);
    expect(admission.productionFtsClaimed, isFalse);
    expect(admission.jobArchivalInvented, isFalse);
    expect(admission.restoreInvented, isFalse);
    expect(admission.cherryPickInvented, isFalse);
    expect(admission.workspaceW5Merged, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
  });
}
