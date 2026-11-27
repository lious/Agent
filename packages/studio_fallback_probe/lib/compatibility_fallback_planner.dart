import 'package:studio_contracts/studio_contracts.dart';

enum FallbackKind {
  sameFormatSoftware,
  lowerPreviewProxy,
  smallerQualifiedModel,
  selfOwnedWorker,
  approvedCloud,
  manual,
}

final class FallbackProposal {
  FallbackProposal({
    required this.kind,
    required this.timeNote,
    required this.qualityNote,
    required this.privacyNote,
    required this.costNote,
    this.newApprovalHash,
  });

  final FallbackKind kind;
  final String timeNote, qualityNote, privacyNote, costNote;
  final String? newApprovalHash;
}

final class FallbackRequest {
  const FallbackRequest({
    this.encoderAvailable = true,
    this.sameFormatSoftwareVerified = false,
    this.localPreferenceAllowsSoftware = false,
    this.previewProxyAvailable = false,
    this.smallerQualifiedModelAvailable = false,
    this.selfOwnedWorkerAvailable = false,
    this.outputSizeChanges = false,
    this.hdrChanges = false,
    this.modelSemanticsChange = false,
    this.uploadChanges = false,
    this.costChanges = false,
    this.confirmed = false,
    this.approvalHash,
    this.autoSelectCloud = false,
    this.claimCpuEncoderFallback = false,
    this.applySameFormatSoftware = false,
  });

  final bool encoderAvailable,
      sameFormatSoftwareVerified,
      localPreferenceAllowsSoftware,
      previewProxyAvailable,
      smallerQualifiedModelAvailable,
      selfOwnedWorkerAvailable,
      outputSizeChanges,
      hdrChanges,
      modelSemanticsChange,
      uploadChanges,
      costChanges,
      confirmed,
      autoSelectCloud,
      claimCpuEncoderFallback,
      applySameFormatSoftware;
  final String? approvalHash;

  bool get attributesChange =>
      outputSizeChanges ||
      hdrChanges ||
      modelSemanticsChange ||
      uploadChanges ||
      costChanges;
}

final class FallbackPlan {
  FallbackPlan({
    required this.proposals,
    required this.appliedSameFormatSoftware,
    required this.logged,
    required this.pendingAdaptation,
    required this.unsupported,
    required this.cloudAutoSelected,
  });

  final List<FallbackProposal> proposals;
  final bool appliedSameFormatSoftware,
      logged,
      pendingAdaptation,
      unsupported,
      cloudAutoSelected;
}

/// DEV-PURE s6c CompatibilityFallbackPlanner. This is not a real
/// encoder, cloud worker, or model runtime, and it is not a
/// re-qualification of V-004 proxy downgrade or I-024 no-encoder
/// export refusal.
final class CompatibilityFallbackPlanner {
  bool logged = false;
  bool v004ProxyRequalified = false;
  bool i024EncoderRequalified = false;
  bool encoderInvented = false;
  bool cloudCalled = false;
  bool paidApiCalled = false;
  bool muxerInvented = false;
  bool limiterInvented = false;
  bool v005Requalified = false;

  FallbackPlan propose(FallbackRequest request) {
    if (request.claimCpuEncoderFallback && !request.encoderAvailable) {
      throw const StudioException(
        'CPU_ENCODER_FALLBACK_FORBIDDEN',
        'sameFormatSoftware',
      );
    }
    if (request.attributesChange &&
        (request.applySameFormatSoftware || request.autoSelectCloud) &&
        !(request.confirmed && (request.approvalHash?.isNotEmpty ?? false))) {
      throw const StudioException('APPROVAL_REQUIRED', 'fallback');
    }
    if (request.autoSelectCloud && !_hasLocalPath(request)) {
      throw const StudioException('SILENT_CLOUD_FORBIDDEN', 'approvedCloud');
    }

    final proposals = <FallbackProposal>[
      if (request.sameFormatSoftwareVerified)
        _proposal(FallbackKind.sameFormatSoftware, request),
      if (request.previewProxyAvailable)
        _proposal(FallbackKind.lowerPreviewProxy, request),
      if (request.smallerQualifiedModelAvailable)
        _proposal(FallbackKind.smallerQualifiedModel, request),
      if (request.selfOwnedWorkerAvailable)
        _proposal(FallbackKind.selfOwnedWorker, request),
      _proposal(FallbackKind.approvedCloud, request),
      _proposal(FallbackKind.manual, request),
    ];

    final canApplySoftware =
        request.applySameFormatSoftware &&
        request.sameFormatSoftwareVerified &&
        request.localPreferenceAllowsSoftware &&
        !request.attributesChange;
    if (canApplySoftware) {
      logged = true;
    }

    final local = _hasLocalPath(request);
    if (!local && request.autoSelectCloud) {
      throw const StudioException('SILENT_CLOUD_FORBIDDEN', 'approvedCloud');
    }

    return FallbackPlan(
      proposals: proposals,
      appliedSameFormatSoftware: canApplySoftware,
      logged: canApplySoftware,
      pendingAdaptation: !local,
      unsupported: !local,
      cloudAutoSelected: false,
    );
  }

  bool _hasLocalPath(FallbackRequest request) {
    return request.sameFormatSoftwareVerified ||
        request.previewProxyAvailable ||
        request.smallerQualifiedModelAvailable ||
        request.selfOwnedWorkerAvailable;
  }

  FallbackProposal _proposal(FallbackKind kind, FallbackRequest request) {
    final needsApproval = request.attributesChange;
    return FallbackProposal(
      kind: kind,
      timeNote: 'time',
      qualityNote: 'quality',
      privacyNote: 'privacy',
      costNote: 'cost',
      newApprovalHash: needsApproval ? request.approvalHash : null,
    );
  }
}
