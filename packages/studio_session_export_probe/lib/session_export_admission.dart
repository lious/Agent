import 'package:studio_contracts/studio_contracts.dart';

const sessionExportKinds = {'sessionExport'};
const historicalRunStates = {'historical', 'interruptedOnExport'};

final class SessionExportRequest {
  const SessionExportRequest({
    required this.kind,
    this.contentIncluded = false,
    this.contentRefsRedacted = true,
    this.includesBodyBlobs = false,
    this.commandBodiesIncluded = false,
    this.runState = 'historical',
  });

  /// `sessionExport`.
  final String kind;
  final bool contentIncluded;
  final bool contentRefsRedacted;
  final bool includesBodyBlobs;
  final bool commandBodiesIncluded;
  final String runState;
}

final class SessionExportReceipt {
  const SessionExportReceipt({
    required this.admitted,
    required this.contentRedacted,
    required this.bodyBlobsIncluded,
    required this.commandBodiesIncluded,
    required this.runsHistorical,
  });

  final bool admitted;
  final bool contentRedacted;
  final bool bodyBlobsIncluded;
  final bool commandBodiesIncluded;
  final bool runsHistorical;
}

/// DEV-PURE I-013 / s5a–s5d admission: when session content is not
/// included, contentRefs are redacted placeholder IDs and body
/// blobs are not retained; command bodies are not exported; and
/// runs are historical or interruptedOnExport, not live.
///
/// This does not re-qualify Increment 1.92 / ADR 0099 default
/// exclusion of sessions and the command journal, Increment 3.22
/// AuditJournalAdmission, ADR 0018 no job-resume binding, or
/// I-054 default-diagnostic exclusions. Production FTS/RAG is not
/// claimed. Job archival, an I-014 RestoreService, PatchGroup
/// cherry-pick, and workspace SQLite w5 are not invented. The
/// “package must not mix in a temporary session database”
/// sentence is not officialized here.
final class SessionExportAdmission {
  bool credentialsDeletedBodyRequalified = false;
  bool auditJournalRequalified = false;
  bool jobResumeRequalified = false;
  bool i054Requalified = false;
  bool productionFtsClaimed = false;
  bool jobArchivalInvented = false;
  bool restoreInvented = false;
  bool cherryPickInvented = false;
  bool workspaceW5Merged = false;
  bool flutterWidgetTreeInvented = false;

  SessionExportReceipt admit(SessionExportRequest request) {
    if (!sessionExportKinds.contains(request.kind)) {
      throw const StudioException('SESSION_EXPORT_KIND_UNKNOWN', 'publication');
    }
    if (request.commandBodiesIncluded) {
      throw const StudioException('COMMAND_BODY_NOT_EXPORTED', 'publication');
    }
    if (!historicalRunStates.contains(request.runState)) {
      throw const StudioException('RUN_MUST_BE_HISTORICAL', 'publication');
    }
    if (!request.contentIncluded) {
      if (request.includesBodyBlobs) {
        throw const StudioException(
          'SESSION_BODY_BLOB_FORBIDDEN',
          'publication',
        );
      }
      if (!request.contentRefsRedacted) {
        throw const StudioException(
          'SESSION_CONTENT_NOT_REDACTED',
          'publication',
        );
      }
    }
    return SessionExportReceipt(
      admitted: true,
      contentRedacted: !request.contentIncluded,
      bodyBlobsIncluded: false,
      commandBodiesIncluded: false,
      runsHistorical: true,
    );
  }
}
