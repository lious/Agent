import 'package:studio_contracts/studio_contracts.dart';

const licenseProvenanceKinds = {'licenseProvenance'};

final class LicenseProvenanceRequest {
  const LicenseProvenanceRequest({
    required this.kind,
    this.washesUpstreamConditions = false,
    this.modelNameSubstitutesHash = false,
    this.roleIssuedByTrustedConfig = true,
    this.requestSelectsPersonalExemption = false,
  });

  /// `licenseProvenance`.
  final String kind;

  /// True when quantize, LoRA, merge, or rename drops upstream conditions.
  final bool washesUpstreamConditions;

  /// True when a model name is used in place of a file hash.
  final bool modelNameSubstitutesHash;

  /// False when the operator role is not issued by trusted config.
  final bool roleIssuedByTrustedConfig;

  /// True when the request self-selects a personal exemption.
  final bool requestSelectsPersonalExemption;
}

final class LicenseProvenanceReceipt {
  const LicenseProvenanceReceipt({
    required this.admitted,
    required this.upstreamConditionsPreserved,
    required this.modelNameUsedAsHash,
    required this.roleIssuedByTrustedConfig,
    required this.personalExemptionSelfSelected,
  });

  final bool admitted;
  final bool upstreamConditionsPreserved;
  final bool modelNameUsedAsHash;
  final bool roleIssuedByTrustedConfig;
  final bool personalExemptionSelfSelected;
}

/// DEV-PURE s1a admission: quantize, LoRA, merge, or rename must not
/// wash away upstream license conditions; a model name must not
/// substitute for a file hash; and an operator role must be issued
/// by trusted configuration, not by a request that self-selects a
/// personal exemption.
///
/// This does not re-qualify Increment 3.32 LicenseExecutionAdmission,
/// I-033 (idempotent POST, unknown no-blind-retry, late cancel,
/// consent not exempted by a license warning, “不代表许可grant,”
/// grantRef/verified writeback), I-058, I-053
/// WARNING_DOES_NOT_EXEMPT, FONT_REDISTRIBUTION_FACT, or
/// MODELS_REFERENCED_NOT_DOWNLOADED. Quote/apply and paid APIs are
/// not started. ADR 0001 allow_with_warning is not re-stated as a
/// new default. The s5d “再分发/执行许可分开” collection sentences
/// are not officialized here. A LoRA, training, or quantizer
/// runtime is not invented. Increments 3.31–3.34 I-002 admissions
/// are not re-qualified.
final class LicenseProvenanceAdmission {
  bool i033Requalified = false;
  bool i058Requalified = false;
  bool i053WarningExemptRequalified = false;
  bool fontRedistributionRequalified = false;
  bool modelsReferencedRequalified = false;
  bool licenseExecutionRequalified = false;
  bool quoteApplyStarted = false;
  bool paidApiCalled = false;
  bool allowWithWarningRestated = false;
  bool jobArchivalInvented = false;
  bool loraRuntimeInvented = false;
  bool llmPathRequalified = false;
  bool dropFrameRequalified = false;
  bool errorClassRequalified = false;

  LicenseProvenanceReceipt admit(LicenseProvenanceRequest request) {
    if (!licenseProvenanceKinds.contains(request.kind)) {
      throw const StudioException(
        'LICENSE_PROVENANCE_KIND_UNKNOWN',
        'publication',
      );
    }
    if (request.washesUpstreamConditions) {
      throw const StudioException('UPSTREAM_CONDITIONS_WASHED', 'publication');
    }
    if (request.modelNameSubstitutesHash) {
      throw const StudioException('MODEL_NAME_NOT_HASH', 'publication');
    }
    if (!request.roleIssuedByTrustedConfig) {
      throw const StudioException('ROLE_NOT_TRUSTED_CONFIG', 'publication');
    }
    if (request.requestSelectsPersonalExemption) {
      throw const StudioException(
        'PERSONAL_EXEMPTION_SELF_SELECTED',
        'publication',
      );
    }
    return const LicenseProvenanceReceipt(
      admitted: true,
      upstreamConditionsPreserved: true,
      modelNameUsedAsHash: false,
      roleIssuedByTrustedConfig: true,
      personalExemptionSelfSelected: false,
    );
  }
}
