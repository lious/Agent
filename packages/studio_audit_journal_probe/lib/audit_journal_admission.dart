import 'package:studio_contracts/studio_contracts.dart';

const auditJournalKinds = {'auditJournalExport', 'auditJournalImport'};

final class AuditJournalRequest {
  const AuditJournalRequest({
    required this.kind,
    this.includesOriginalPayload = false,
    this.includesNewFileToken = false,
    this.includesExecutableBody = false,
    this.replaysJournal = false,
    this.executesOldUndo = false,
    this.claimsInheritedUndoStack = false,
  });

  /// `auditJournalExport` or `auditJournalImport`.
  final String kind;
  final bool includesOriginalPayload;
  final bool includesNewFileToken;
  final bool includesExecutableBody;
  final bool replaysJournal;
  final bool executesOldUndo;
  final bool claimsInheritedUndoStack;
}

final class AuditJournalReceipt {
  const AuditJournalReceipt({
    required this.admitted,
    required this.metadataOnly,
    required this.executableBody,
    required this.replayed,
    required this.oldUndoExecuted,
    required this.undoStackEmpty,
  });

  final bool admitted;
  final bool metadataOnly;
  final bool executableBody;
  final bool replayed;
  final bool oldUndoExecuted;
  final bool undoStackEmpty;
}

/// DEV-PURE I-014 / s5a admission: an audit journal is CommandArchive
/// metadata only, must not carry original payload, a newFileToken, or
/// an executable body, must not be replayed on import, must not
/// execute an old Undo as-is, and a new project's undo stack starts
/// empty.
///
/// This does not re-qualify Increment 1.92 / ADR 0099 default
/// exclusion of the command journal from an embedded package,
/// Increment 3.21 ArchiveLimitConsentAdmission, Increment 3.16
/// FutureMajorAdmission, “不支持feature只读保留”, Increment 3.15
/// IdentityCollisionAdmission, Increment 2.51, or
/// fork-new-projectId. An I-014 RestoreService, PatchGroup
/// cherry-pick, workspace SQLite w5, and a schema migrator are not
/// invented. Inverse snapshots may be read; they are not executed.
final class AuditJournalAdmission {
  bool credentialsDeletedBodyRequalified = false;
  bool archiveLimitConsentRequalified = false;
  bool futureMajorRequalified = false;
  bool identityCollisionRequalified = false;
  bool forkNewProjectIdRequalified = false;
  bool restoreInvented = false;
  bool cherryPickInvented = false;
  bool workspaceW5Merged = false;
  bool schemaMigratorInvented = false;
  bool flutterWidgetTreeInvented = false;

  AuditJournalReceipt admit(AuditJournalRequest request) {
    if (!auditJournalKinds.contains(request.kind)) {
      throw const StudioException('AUDIT_JOURNAL_KIND_UNKNOWN', 'publication');
    }
    if (request.kind == 'auditJournalExport') {
      if (request.includesOriginalPayload || request.includesNewFileToken) {
        throw const StudioException(
          'AUDIT_JOURNAL_PAYLOAD_FORBIDDEN',
          'publication',
        );
      }
      if (request.includesExecutableBody) {
        throw const StudioException(
          'AUDIT_JOURNAL_EXECUTABLE_FORBIDDEN',
          'publication',
        );
      }
      return const AuditJournalReceipt(
        admitted: true,
        metadataOnly: true,
        executableBody: false,
        replayed: false,
        oldUndoExecuted: false,
        undoStackEmpty: true,
      );
    }
    if (request.replaysJournal) {
      throw const StudioException(
        'AUDIT_JOURNAL_REPLAY_FORBIDDEN',
        'publication',
      );
    }
    if (request.executesOldUndo) {
      throw const StudioException('OLD_UNDO_NOT_EXECUTABLE', 'publication');
    }
    if (request.claimsInheritedUndoStack) {
      throw const StudioException('UNDO_STACK_STARTS_EMPTY', 'publication');
    }
    return const AuditJournalReceipt(
      admitted: true,
      metadataOnly: true,
      executableBody: false,
      replayed: false,
      oldUndoExecuted: false,
      undoStackEmpty: true,
    );
  }
}
