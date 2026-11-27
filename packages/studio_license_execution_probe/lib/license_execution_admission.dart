import 'package:studio_contracts/studio_contracts.dart';

const licenseExecutionKinds = {'licenseExecution'};

final class LicenseExecutionRequest {
  const LicenseExecutionRequest({
    required this.kind,
    this.autoSwitchesModel = false,
    this.relabelsHttp403AsLicenseWarning = false,
    this.licenseFactChangeCancelsRunningJob = false,
    this.licenseFactChangeDropsCandidates = false,
    this.licenseFactChangeTriggersPaidRetry = false,
  });

  /// `licenseExecution`.
  final String kind;
  final bool autoSwitchesModel;
  final bool relabelsHttp403AsLicenseWarning;
  final bool licenseFactChangeCancelsRunningJob;
  final bool licenseFactChangeDropsCandidates;
  final bool licenseFactChangeTriggersPaidRetry;
}

final class LicenseExecutionReceipt {
  const LicenseExecutionReceipt({
    required this.admitted,
    required this.autoSwitchedModel,
    required this.http403Relabeled,
    required this.jobCancelled,
    required this.candidatesDropped,
    required this.paidRetryTriggered,
  });

  final bool admitted;
  final bool autoSwitchedModel;
  final bool http403Relabeled;
  final bool jobCancelled;
  final bool candidatesDropped;
  final bool paidRetryTriggered;
}

/// DEV-PURE s1c admission: a commercial-license gap must not
/// automatically switch models; an HTTP 403 must not be
/// relabeled as a license warning and retried; and a
/// license-fact-only change must not cancel a running job,
/// drop candidates, or trigger a paid retry.
///
/// This does not re-qualify I-033 (idempotent POST, unknown
/// no-blind-retry, late cancel settles only, consent not
/// exempted by a license warning, “不代表许可grant”), I-058
/// (a license warning is not a release hard-block and does
/// not exempt V-022), I-053 WARNING_DOES_NOT_EXEMPT,
/// FONT_REDISTRIBUTION_FACT, or
/// MODELS_REFERENCED_NOT_DOWNLOADED. Quote/apply and paid
/// APIs are not started. Increment 3.30
/// FixedRevisionArchiveAdmission and Increment 3.31
/// ErrorClassAdmission are not re-qualified. The s5d
/// “再分发/执行许可分开” collection sentences are not
/// officialized here.
final class LicenseExecutionAdmission {
  bool i033Requalified = false;
  bool i058Requalified = false;
  bool i053WarningExemptRequalified = false;
  bool fontRedistributionRequalified = false;
  bool modelsReferencedRequalified = false;
  bool quoteApplyStarted = false;
  bool paidApiCalled = false;
  bool jobArchivalInvented = false;
  bool fixedRevisionArchiveRequalified = false;
  bool errorClassRequalified = false;

  LicenseExecutionReceipt admit(LicenseExecutionRequest request) {
    if (!licenseExecutionKinds.contains(request.kind)) {
      throw const StudioException(
        'LICENSE_EXECUTION_KIND_UNKNOWN',
        'publication',
      );
    }
    if (request.autoSwitchesModel) {
      throw const StudioException('LICENSE_GAP_NO_AUTO_SWITCH', 'publication');
    }
    if (request.relabelsHttp403AsLicenseWarning) {
      throw const StudioException(
        'HTTP_403_NOT_LICENSE_WARNING',
        'publication',
      );
    }
    if (request.licenseFactChangeCancelsRunningJob) {
      throw const StudioException('LICENSE_FACT_NO_JOB_CANCEL', 'publication');
    }
    if (request.licenseFactChangeDropsCandidates) {
      throw const StudioException(
        'LICENSE_FACT_NO_DROP_CANDIDATE',
        'publication',
      );
    }
    if (request.licenseFactChangeTriggersPaidRetry) {
      throw const StudioException('LICENSE_FACT_NO_PAID_RETRY', 'publication');
    }
    return const LicenseExecutionReceipt(
      admitted: true,
      autoSwitchedModel: false,
      http403Relabeled: false,
      jobCancelled: false,
      candidatesDropped: false,
      paidRetryTriggered: false,
    );
  }
}
