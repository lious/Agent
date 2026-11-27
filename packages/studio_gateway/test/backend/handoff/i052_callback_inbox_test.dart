import 'dart:math';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_gateway/studio_gateway.dart';
import 'package:test/test.dart';

/// Increment 2.61 official first I-052 slice: AsyncJobService callback
/// inbox de-duplication and unknown-no-repost. This file does not
/// invent a WorkflowCoordinator or a real GPU worker, does not claim
/// V-021, does not invent device-disconnect durability or multi-tenant
/// fairness, does not rewrite I-040 VideoGenerationProvider or I-033
/// SubmissionReconciler, does not re-qualify I-057 or I-037, does not
/// start I-035 or I-055, does not invent I-013 job archival or an
/// I-014 RestoreService commit path, and does not mark I-037, I-038,
/// V-007, V-020, I-054, I-051, I-046, I-041, I-040, I-053, I-056, or
/// I-057 complete. InversePatch kind stays restoreSnapshot. Project
/// user_version stays 9.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

OpenJob job({int cancelEpoch = 0, int planGeneration = 1}) => OpenJob(
  jobId: 'job-1',
  logicalCallId: 'call-1',
  tenantId: 'tenant-a',
  idempotencyKey: 'key-1',
  reservedMicros: 40,
  planGeneration: planGeneration,
  cancelEpoch: cancelEpoch,
);

ProviderCallback cb({
  String eventId = 'evt-1',
  String hash = 'hash-1',
  int amount = 40,
  bool signatureValid = true,
  String tenantId = 'tenant-a',
  String jobId = 'job-1',
  String callId = 'call-1',
  int planGeneration = 1,
  int cancelEpoch = 0,
  String status = 'succeeded',
}) => ProviderCallback(
  providerEventId: eventId,
  logicalCallId: callId,
  jobId: jobId,
  tenantId: tenantId,
  payloadHash: hash,
  amountMicros: amount,
  signatureValid: signatureValid,
  planGeneration: planGeneration,
  cancelEpoch: cancelEpoch,
  status: status,
);

void main() {
  test('100 out-of-order or duplicate callbacks for the same job settle once and ingest one candidate', () {
    final service = AsyncJobService();
    service.submit(job());
    final events = <ProviderCallback>[
      for (var i = 0; i < 50; i++) ...[
        cb(eventId: 'evt-1', hash: 'hash-1'),
        cb(eventId: 'evt-2', hash: 'hash-2'),
      ],
    ];
    events.shuffle(Random(52));
    for (final event in events) {
      service.ingest(event);
    }
    expect(events, hasLength(100));
    expect(service.settleCount, 1);
    expect(service.candidateCount, 1);
    expect(service.settledMicros, 40);
    expect(service.timelineAttaches, 0);
    expect(service.refundPromised, isFalse);
    expect(service.documentWrites, 0);
    expect(service.realGpuWorker, isFalse);
    expect(service.workflowCoordinatorInvented, isFalse);
    expect(service.v021Claimed, isFalse);
  });

  test('conflicting event hashes and bill amounts are refused; stale or old-plan callbacks settle once and stay off the current timeline', () {
    final service = AsyncJobService();
    service.submit(job(cancelEpoch: 2, planGeneration: 2));
    service.ingest(
      cb(eventId: 'evt-1', hash: 'hash-1', cancelEpoch: 2, planGeneration: 2),
      currentPlanGeneration: 2,
    );
    expect(
      () => service.ingest(cb(eventId: 'evt-1', hash: 'hash-other')),
      code('IMMUTABLE_ID_CONFLICT'),
    );
    expect(
      () => service.ingest(cb(eventId: 'evt-3', hash: 'hash-3', amount: 80)),
      code('ACCOUNTING_MISMATCH'),
    );
    expect(service.settledMicros, 40);
    expect(service.discrepancyCount, 1);
    expect(service.settleCount, 1);
    expect(service.candidateCount, 1);

    final other = AsyncJobService();
    other.submit(job(cancelEpoch: 2, planGeneration: 2));
    expect(
      () => other.ingest(cb(signatureValid: false)),
      code('SIGNATURE_INVALID'),
    );
    expect(() => other.ingest(cb(tenantId: 'tenant-b')), code('TENANT_DENIED'));
    expect(other.settleCount, 0);

    other.ingest(
      cb(cancelEpoch: 1, planGeneration: 1),
      currentPlanGeneration: 2,
    );
    expect(other.settleCount, 1);
    expect(other.settledMicros, 40);
    expect(other.quarantinedCount, 1);
    expect(other.publishedToCurrentPlan, 0);
    expect(other.timelineAttaches, 0);
    expect(other.refundPromised, isFalse);
  });

  test('an unknown submit does not re-POST; the reservation is not spent and is not reusable', () {
    final service = AsyncJobService();
    service.submit(job());
    expect(service.postCount, 1);
    service.markUnknown('job-1');
    expect(
      () => service.repostUnknown('job-1'),
      code('UNKNOWN_NO_BLIND_RETRY'),
    );
    service.poll('job-1');
    service.submit(job());
    expect(service.postCount, 1);
    expect(service.pollCount, 1);
    expect(service.reservedMicrosFor('job-1'), 40);
    expect(service.settledMicros, 0);
    expect(service.reservedReusable, isFalse);
    expect(service.paidApiCalled, isFalse);
    expect(service.realGpuWorker, isFalse);
    expect(service.v021Claimed, isFalse);
  });
}
