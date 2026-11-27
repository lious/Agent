import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_audit_journal_probe/studio_audit_journal_probe.dart';
import 'package:test/test.dart';

/// Increment 3.22 official I-014 / s5a leftover: an audit journal
/// is CommandArchive metadata only, must not carry original
/// payload, a newFileToken, or an executable body, must not be
/// replayed on import, must not execute an old Undo as-is, and a
/// new project's undo stack starts empty.
///
/// This file does not re-qualify Increment 1.92 / ADR 0099 default
/// command-journal exclusion, Increment 3.21
/// ArchiveLimitConsentAdmission, Increment 3.16
/// FutureMajorAdmission, “不支持feature只读保留”, Increment 3.15
/// IdentityCollisionAdmission, Increment 2.51, or
/// fork-new-projectId. An I-014 RestoreService and PatchGroup
/// cherry-pick are not invented. InversePatch kind stays
/// restoreSnapshot. Project user_version stays 9. I-014 stays
/// partial. Existing I-014 remainingAcceptance wording is not
/// silently cleared.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('an audit journal is metadata only, must not be replayed on import, and a new undo stack starts empty', () {
    final admission = AuditJournalAdmission();
    final exported = admission.admit(
      const AuditJournalRequest(kind: 'auditJournalExport'),
    );
    expect(exported.admitted, isTrue);
    expect(exported.metadataOnly, isTrue);
    expect(exported.executableBody, isFalse);

    final imported = admission.admit(
      const AuditJournalRequest(kind: 'auditJournalImport'),
    );
    expect(imported.admitted, isTrue);
    expect(imported.replayed, isFalse);
    expect(imported.oldUndoExecuted, isFalse);
    expect(imported.undoStackEmpty, isTrue);

    expect(
      () => admission.admit(const AuditJournalRequest(kind: 'unknown')),
      code('AUDIT_JOURNAL_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const AuditJournalRequest(
          kind: 'auditJournalExport',
          includesOriginalPayload: true,
        ),
      ),
      code('AUDIT_JOURNAL_PAYLOAD_FORBIDDEN'),
    );
    expect(
      () => admission.admit(
        const AuditJournalRequest(
          kind: 'auditJournalExport',
          includesNewFileToken: true,
        ),
      ),
      code('AUDIT_JOURNAL_PAYLOAD_FORBIDDEN'),
    );
    expect(
      () => admission.admit(
        const AuditJournalRequest(
          kind: 'auditJournalExport',
          includesExecutableBody: true,
        ),
      ),
      code('AUDIT_JOURNAL_EXECUTABLE_FORBIDDEN'),
    );
    expect(
      () => admission.admit(
        const AuditJournalRequest(
          kind: 'auditJournalImport',
          replaysJournal: true,
        ),
      ),
      code('AUDIT_JOURNAL_REPLAY_FORBIDDEN'),
    );
    expect(
      () => admission.admit(
        const AuditJournalRequest(
          kind: 'auditJournalImport',
          executesOldUndo: true,
        ),
      ),
      code('OLD_UNDO_NOT_EXECUTABLE'),
    );
    expect(
      () => admission.admit(
        const AuditJournalRequest(
          kind: 'auditJournalImport',
          claimsInheritedUndoStack: true,
        ),
      ),
      code('UNDO_STACK_STARTS_EMPTY'),
    );
  });

  test('ADR 0099 default journal exclusion, ArchiveLimitConsentAdmission, FutureMajorAdmission, and a RestoreService stay closed', () {
    final admission = AuditJournalAdmission();
    expect(admission.credentialsDeletedBodyRequalified, isFalse);
    expect(admission.archiveLimitConsentRequalified, isFalse);
    expect(admission.futureMajorRequalified, isFalse);
    expect(admission.identityCollisionRequalified, isFalse);
    expect(admission.forkNewProjectIdRequalified, isFalse);
    expect(admission.restoreInvented, isFalse);
    expect(admission.cherryPickInvented, isFalse);
    expect(admission.workspaceW5Merged, isFalse);
    expect(admission.schemaMigratorInvented, isFalse);
    expect(admission.flutterWidgetTreeInvented, isFalse);
  });
}
