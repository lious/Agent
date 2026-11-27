import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_session_navigation_probe/studio_session_navigation_probe.dart';
import 'package:test/test.dart';

/// Increment 3.36 official s9 leftover: leaving a screen is not a
/// cancel, and switching sessions must not cancel a running job or
/// reset the playhead.
///
/// This file does not re-qualify Increment 3.04 JobCancelAdmission,
/// ADR 0028, Increment 3.32 LicenseExecutionAdmission, or
/// Increment 3.35 LicenseProvenanceAdmission. InversePatch kind
/// stays restoreSnapshot. Project user_version stays 9. This is
/// not an I-013 packing or archive slice, not an I-002 measurement
/// claim, and not a license leftover already officialized in 3.32
/// or 3.35.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('leaving a screen or switching sessions must not cancel a running job or reset the playhead', () {
    final admission = SessionNavigationAdmission();
    final leave = admission.admit(
      const SessionNavigationRequest(
        kind: 'sessionNavigation',
        leavesScreen: true,
      ),
    );
    expect(leave.admitted, isTrue);
    expect(leave.runCancelled, isFalse);
    expect(leave.playheadReset, isFalse);

    final switchSession = admission.admit(
      const SessionNavigationRequest(
        kind: 'sessionNavigation',
        switchesSession: true,
      ),
    );
    expect(switchSession.admitted, isTrue);
    expect(switchSession.runCancelled, isFalse);
    expect(switchSession.playheadReset, isFalse);

    expect(
      () => admission.admit(const SessionNavigationRequest(kind: 'unknown')),
      code('SESSION_NAVIGATION_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const SessionNavigationRequest(
          kind: 'sessionNavigation',
          leavesScreen: true,
          cancelsRun: true,
        ),
      ),
      code('LEAVE_SCREEN_NOT_CANCEL'),
    );
    expect(
      () => admission.admit(
        const SessionNavigationRequest(
          kind: 'sessionNavigation',
          switchesSession: true,
          cancelsRun: true,
        ),
      ),
      code('SWITCH_SESSION_NOT_CANCEL'),
    );
    expect(
      () => admission.admit(
        const SessionNavigationRequest(
          kind: 'sessionNavigation',
          switchesSession: true,
          resetsPlayhead: true,
        ),
      ),
      code('SWITCH_SESSION_NOT_RESET_PLAYHEAD'),
    );
  });

  test('JobCancelAdmission, ADR 0028, license-execution, license-provenance, and deferred runtimes stay closed', () {
    final admission = SessionNavigationAdmission();
    expect(admission.jobCancelRequalified, isFalse);
    expect(admission.adr0028Requalified, isFalse);
    expect(admission.licenseExecutionRequalified, isFalse);
    expect(admission.licenseProvenanceRequalified, isFalse);
    expect(admission.errorClassRequalified, isFalse);
    expect(admission.dropFrameRequalified, isFalse);
    expect(admission.llmPathRequalified, isFalse);
    expect(admission.flutterTreeInvented, isFalse);
    expect(admission.workflowCoordinatorInvented, isFalse);
    expect(admission.cherryPickInvented, isFalse);
    expect(admission.chatWorkbenchInvented, isFalse);
    expect(admission.jobArchivalInvented, isFalse);
    expect(admission.recycleBinInvented, isFalse);
  });
}
