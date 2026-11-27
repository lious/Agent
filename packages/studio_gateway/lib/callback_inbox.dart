import 'package:studio_contracts/studio_contracts.dart';

/// Official s10d/s10h inbound provider callback. This is not an I-040
/// generation submitter and not an I-033 SubmissionReconciler rewrite.
final class ProviderCallback {
  ProviderCallback({
    required this.providerEventId,
    required this.logicalCallId,
    required this.jobId,
    required this.tenantId,
    required this.payloadHash,
    required this.amountMicros,
    this.signatureValid = true,
    this.planGeneration = 1,
    this.cancelEpoch = 0,
    this.status = 'succeeded',
  }) {
    requireId(providerEventId);
    requireId(logicalCallId);
    requireId(jobId);
    requireId(tenantId);
  }

  final String providerEventId,
      logicalCallId,
      jobId,
      tenantId,
      payloadHash,
      status;
  final int amountMicros, planGeneration, cancelEpoch;
  final bool signatureValid;
}

final class OpenJob {
  OpenJob({
    required this.jobId,
    required this.logicalCallId,
    required this.tenantId,
    required this.idempotencyKey,
    this.reservedMicros = 40,
    this.planGeneration = 1,
    this.cancelEpoch = 0,
  }) {
    requireId(jobId);
    requireId(logicalCallId);
    requireId(tenantId);
    requireId(idempotencyKey);
  }

  final String jobId, logicalCallId, tenantId, idempotencyKey;
  final int reservedMicros, planGeneration, cancelEpoch;
}

/// DEV-PURE I-052 AsyncJobService / callback inbox. Local simulation
/// only: not a WorkflowCoordinator, not a real GPU worker, and not a
/// V-021 serverless qualification.
final class AsyncJobService {
  final _jobs = <String, OpenJob>{};
  final _jobsByKey = <String, OpenJob>{};
  final _eventHashes = <String, String>{};
  final _settledCalls = <String>{};
  final _settledAmounts = <String, int>{};
  final _candidates = <String>{};
  final _discrepancies = <String>[];

  int postCount = 0;
  int pollCount = 0;
  int settleCount = 0;
  int candidateCount = 0;
  int timelineAttaches = 0;
  int quarantinedCount = 0;
  int publishedToCurrentPlan = 0;
  int settledMicros = 0;
  int documentWrites = 0;
  bool refundPromised = false;
  bool realGpuWorker = false;
  bool workflowCoordinatorInvented = false;
  bool v021Claimed = false;
  bool paidApiCalled = false;
  bool submitted = false;

  final _unknownJobs = <String>{};

  /// First submit POSTs once per idempotency key. A later unknown
  /// timeout must poll, not re-POST.
  OpenJob submit(OpenJob job) {
    final existing = _jobsByKey[job.idempotencyKey];
    if (existing != null) {
      return existing;
    }
    _jobs[job.jobId] = job;
    _jobsByKey[job.idempotencyKey] = job;
    postCount += 1;
    documentWrites = 0;
    return job;
  }

  void markUnknown(String jobId) {
    requireId(jobId);
    if (!_jobs.containsKey(jobId)) {
      throw const StudioException('FEATURE_NOT_IMPLEMENTED', 'unknownJob');
    }
    _unknownJobs.add(jobId);
    documentWrites = 0;
  }

  void poll(String jobId) {
    requireId(jobId);
    pollCount += 1;
    documentWrites = 0;
  }

  void repostUnknown(String jobId) {
    requireId(jobId);
    throw const StudioException('UNKNOWN_NO_BLIND_RETRY', 'callbackInbox');
  }

  /// Ingest one provider webhook. At-least-once HTTP may deliver the
  /// same or sibling events many times; business settle happens once.
  void ingest(ProviderCallback callback, {int currentPlanGeneration = 1}) {
    if (!callback.signatureValid) {
      throw const StudioException('SIGNATURE_INVALID', 'webhook');
    }
    final job = _jobs[callback.jobId];
    if (job == null || job.tenantId != callback.tenantId) {
      throw const StudioException('TENANT_DENIED', 'webhook');
    }
    if (job.logicalCallId != callback.logicalCallId) {
      throw const StudioException('TENANT_DENIED', 'jobBinding');
    }

    final priorHash = _eventHashes[callback.providerEventId];
    if (priorHash != null && priorHash != callback.payloadHash) {
      throw const StudioException('IMMUTABLE_ID_CONFLICT', 'providerEventId');
    }
    _eventHashes[callback.providerEventId] = callback.payloadHash;

    final callId = callback.logicalCallId;
    if (_settledCalls.contains(callId)) {
      final prior = _settledAmounts[callId]!;
      if (callback.amountMicros != prior) {
        _discrepancies.add(callId);
        throw const StudioException('ACCOUNTING_MISMATCH', 'settlement');
      }
      documentWrites = 0;
      return;
    }

    if (callback.status == 'unknown') {
      markUnknown(callback.jobId);
      documentWrites = 0;
      return;
    }

    _settledCalls.add(callId);
    _settledAmounts[callId] = callback.amountMicros;
    settleCount += 1;
    settledMicros += callback.amountMicros;
    _candidates.add(callId);
    candidateCount = _candidates.length;

    final stale = callback.cancelEpoch < job.cancelEpoch;
    final wrongPlan = callback.planGeneration != currentPlanGeneration;
    if (stale || wrongPlan) {
      quarantinedCount += 1;
    } else {
      // A retained or current-plan candidate is ready but is not
      // auto-attached to the NLE / timeline.
    }
    refundPromised = false;
    timelineAttaches = 0;
    documentWrites = 0;
  }

  int get discrepancyCount => _discrepancies.length;

  int reservedMicrosFor(String jobId) => _jobs[jobId]?.reservedMicros ?? 0;

  bool get reservedReusable => false;
}
