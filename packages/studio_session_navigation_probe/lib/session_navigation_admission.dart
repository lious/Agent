import 'package:studio_contracts/studio_contracts.dart';

const sessionNavigationKinds = {'sessionNavigation'};

final class SessionNavigationRequest {
  const SessionNavigationRequest({
    required this.kind,
    this.leavesScreen = false,
    this.switchesSession = false,
    this.cancelsRun = false,
    this.resetsPlayhead = false,
  });

  /// `sessionNavigation`.
  final String kind;
  final bool leavesScreen;
  final bool switchesSession;
  final bool cancelsRun;
  final bool resetsPlayhead;
}

final class SessionNavigationReceipt {
  const SessionNavigationReceipt({
    required this.admitted,
    required this.runCancelled,
    required this.playheadReset,
  });

  final bool admitted;
  final bool runCancelled;
  final bool playheadReset;
}

/// DEV-PURE s9 admission: leaving a screen is not a cancel, and
/// switching sessions must not cancel a running job or reset the
/// playhead.
///
/// This does not re-qualify Increment 3.04 JobCancelAdmission,
/// ADR 0028 gesture cancel or close-discard-ghosts, Increment
/// 3.32 LicenseExecutionAdmission, or Increment 3.35
/// LicenseProvenanceAdmission. A Flutter widget tree,
/// WorkflowCoordinator, PatchGroup cherry-pick, chat workbench,
/// or workspace SQLite w5 is not invented. I-013 job archival
/// and the recycle-bin path are not invented.
final class SessionNavigationAdmission {
  bool jobCancelRequalified = false;
  bool adr0028Requalified = false;
  bool licenseExecutionRequalified = false;
  bool licenseProvenanceRequalified = false;
  bool errorClassRequalified = false;
  bool dropFrameRequalified = false;
  bool llmPathRequalified = false;
  bool flutterTreeInvented = false;
  bool workflowCoordinatorInvented = false;
  bool cherryPickInvented = false;
  bool chatWorkbenchInvented = false;
  bool jobArchivalInvented = false;
  bool recycleBinInvented = false;

  SessionNavigationReceipt admit(SessionNavigationRequest request) {
    if (!sessionNavigationKinds.contains(request.kind)) {
      throw const StudioException(
        'SESSION_NAVIGATION_KIND_UNKNOWN',
        'validator',
      );
    }
    if (request.leavesScreen && request.cancelsRun) {
      throw const StudioException('LEAVE_SCREEN_NOT_CANCEL', 'validator');
    }
    if (request.switchesSession && request.cancelsRun) {
      throw const StudioException('SWITCH_SESSION_NOT_CANCEL', 'validator');
    }
    if (request.switchesSession && request.resetsPlayhead) {
      throw const StudioException(
        'SWITCH_SESSION_NOT_RESET_PLAYHEAD',
        'validator',
      );
    }
    return const SessionNavigationReceipt(
      admitted: true,
      runCancelled: false,
      playheadReset: false,
    );
  }
}
