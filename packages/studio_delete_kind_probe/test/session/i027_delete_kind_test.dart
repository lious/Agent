import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_delete_kind_probe/studio_delete_kind_probe.dart';
import 'package:test/test.dart';

/// Increment 3.39 official s9 leftover: project deletion and
/// session deletion are different kinds and must not be treated
/// as each other.
///
/// This file does not officialize the recycle-bin path or a
/// 30-day timer, and does not re-qualify Increment 3.36
/// SessionNavigationAdmission, Increment 3.28
/// ArchiveCountdownAdmission, I-004, I-029, or ADR 0018.
/// InversePatch kind stays restoreSnapshot. Project user_version
/// stays 9. This is not an I-013 packing or archive slice, not
/// an I-002 measurement claim, and not a license, model-context,
/// or offline-capability leftover already officialized in 3.32,
/// 3.35, 3.37, or 3.38.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('project deletion and session deletion are different kinds and must not be treated as each other', () {
    final admission = DeleteKindAdmission();
    final session = admission.admit(
      const DeleteKindRequest(
        kind: 'deleteKind',
        target: 'session',
        treatedAs: 'session',
      ),
    );
    expect(session.admitted, isTrue);
    expect(session.sessionTreatedAsProject, isFalse);
    expect(session.projectTreatedAsSession, isFalse);

    final project = admission.admit(
      const DeleteKindRequest(
        kind: 'deleteKind',
        target: 'project',
        treatedAs: 'project',
      ),
    );
    expect(project.admitted, isTrue);
    expect(project.sessionTreatedAsProject, isFalse);
    expect(project.projectTreatedAsSession, isFalse);

    expect(
      () => admission.admit(
        const DeleteKindRequest(
          kind: 'unknown',
          target: 'session',
          treatedAs: 'session',
        ),
      ),
      code('DELETE_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const DeleteKindRequest(
          kind: 'deleteKind',
          target: 'unknown',
          treatedAs: 'session',
        ),
      ),
      code('DELETE_KIND_UNKNOWN'),
    );
    expect(
      () => admission.admit(
        const DeleteKindRequest(
          kind: 'deleteKind',
          target: 'session',
          treatedAs: 'project',
        ),
      ),
      code('SESSION_DELETE_NOT_PROJECT'),
    );
    expect(
      () => admission.admit(
        const DeleteKindRequest(
          kind: 'deleteKind',
          target: 'project',
          treatedAs: 'session',
        ),
      ),
      code('PROJECT_DELETE_NOT_SESSION'),
    );
  });

  test('SessionNavigationAdmission, ArchiveCountdownAdmission, I-004, I-029, ADR 0018, and the recycle-bin path stay closed', () {
    final admission = DeleteKindAdmission();
    expect(admission.sessionNavigationRequalified, isFalse);
    expect(admission.archiveCountdownRequalified, isFalse);
    expect(admission.i004Requalified, isFalse);
    expect(admission.i029Requalified, isFalse);
    expect(admission.adr0018Requalified, isFalse);
    expect(admission.recycleBinInvented, isFalse);
    expect(admission.countdownTimerInvented, isFalse);
    expect(admission.thirtyDayClaimed, isFalse);
    expect(admission.jobArchivalInvented, isFalse);
    expect(admission.flutterTreeInvented, isFalse);
    expect(admission.offlineCapabilityRequalified, isFalse);
    expect(admission.modelContextRequalified, isFalse);
  });
}
