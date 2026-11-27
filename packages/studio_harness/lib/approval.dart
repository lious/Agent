import 'package:studio_contracts/studio_contracts.dart';

const approvalStale = 'APPROVAL_STALE';
const approvalRequired = 'APPROVAL_REQUIRED';

/// Binding of a prompt, resource, and project revision. A later change of
/// any bound field invalidates the approval. This is not a permission grant.
final class ApprovalBinding {
  ApprovalBinding({
    required this.promptHash,
    required this.resourceId,
    required this.revision,
  }) {
    requireId(resourceId);
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(promptHash)) {
      throw const StudioException('INVALID_ID', 'promptHash');
    }
  }

  final String promptHash, resourceId;
  final int revision;

  bool matches(ApprovalBinding other) =>
      promptHash == other.promptHash &&
      resourceId == other.resourceId &&
      revision == other.revision;
}

final class Approval {
  Approval({
    required this.id,
    required this.summaryHash,
    required this.binding,
  });

  final String id, summaryHash;
  final ApprovalBinding binding;
  bool invalidated = false;
}

final class ApprovalService {
  final Map<String, Approval> _byId = {};
  int _n = 0;

  Approval approve({
    required String summaryHash,
    required ApprovalBinding binding,
  }) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(summaryHash)) {
      throw const StudioException('INVALID_ID', 'summaryHash');
    }
    _n++;
    final approval = Approval(
      id: 'appr-$_n',
      summaryHash: summaryHash,
      binding: binding,
    );
    _byId[approval.id] = approval;
    return approval;
  }

  /// Binding changes invalidate the approval and never auto-increase quota.
  Approval requireFresh(String approvalId, ApprovalBinding current) {
    final approval = _byId[approvalId];
    if (approval == null) {
      throw StudioException(approvalRequired, approvalId);
    }
    if (approval.invalidated || !approval.binding.matches(current)) {
      approval.invalidated = true;
      throw StudioException(approvalStale, approvalId);
    }
    return approval;
  }
}
