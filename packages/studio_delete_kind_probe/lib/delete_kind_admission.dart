import 'package:studio_contracts/studio_contracts.dart';

const deleteKindKinds = {'deleteKind'};
const deleteKindTargets = {'session', 'project'};

final class DeleteKindRequest {
  const DeleteKindRequest({
    required this.kind,
    required this.target,
    required this.treatedAs,
  });

  /// `deleteKind`.
  final String kind;

  /// `session` or `project`.
  final String target;

  /// `session` or `project`. Must match [target].
  final String treatedAs;
}

final class DeleteKindReceipt {
  const DeleteKindReceipt({
    required this.admitted,
    required this.sessionTreatedAsProject,
    required this.projectTreatedAsSession,
  });

  final bool admitted;
  final bool sessionTreatedAsProject;
  final bool projectTreatedAsSession;
}

/// DEV-PURE s9 admission: project deletion and session deletion
/// are different kinds and must not be treated as each other.
///
/// This does not officialize the project-deletion recycle-bin
/// path or the 30-day figure, does not invent a recycle-bin
/// runtime or countdown timer, and does not re-qualify
/// Increment 3.28 ArchiveCountdownAdmission, Increment 3.36
/// SessionNavigationAdmission, I-004 reachable-media retention,
/// I-029 DeletionBarrier, or ADR 0018. “删除聊天不删除时间线已引用的素材”
/// and “generation完成只发布candidate.ready，不执行accept” are
/// not officialized here.
final class DeleteKindAdmission {
  bool sessionNavigationRequalified = false;
  bool archiveCountdownRequalified = false;
  bool i004Requalified = false;
  bool i029Requalified = false;
  bool adr0018Requalified = false;
  bool recycleBinInvented = false;
  bool countdownTimerInvented = false;
  bool thirtyDayClaimed = false;
  bool jobArchivalInvented = false;
  bool flutterTreeInvented = false;
  bool offlineCapabilityRequalified = false;
  bool modelContextRequalified = false;

  DeleteKindReceipt admit(DeleteKindRequest request) {
    if (!deleteKindKinds.contains(request.kind)) {
      throw const StudioException('DELETE_KIND_UNKNOWN', 'validator');
    }
    if (!deleteKindTargets.contains(request.target) ||
        !deleteKindTargets.contains(request.treatedAs)) {
      throw const StudioException('DELETE_KIND_UNKNOWN', 'validator');
    }
    if (request.target == 'session' && request.treatedAs == 'project') {
      throw const StudioException('SESSION_DELETE_NOT_PROJECT', 'validator');
    }
    if (request.target == 'project' && request.treatedAs == 'session') {
      throw const StudioException('PROJECT_DELETE_NOT_SESSION', 'validator');
    }
    return const DeleteKindReceipt(
      admitted: true,
      sessionTreatedAsProject: false,
      projectTreatedAsSession: false,
    );
  }
}
