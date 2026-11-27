import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_quality/studio_quality.dart';
import 'package:test/test.dart';

/// Increment 2.59 official first I-056 slice: TraceViewer redaction,
/// revision/job correlation, and de-duplicated cost. This file does not
/// rewrite I-054 PrivacyService or I-029 DeletionBarrier, does not claim
/// production FTS/RAG, does not start I-055, does not default-upload
/// logs, does not invent a telemetry backend, does not re-qualify I-053
/// or I-033 leftovers, does not start I-035, and does not mark I-037,
/// I-038, V-007, V-020, I-054, I-051, I-046, I-041, I-040, or I-053
/// complete. InversePatch kind stays restoreSnapshot. Project
/// user_version stays 9.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

TraceEvent event({
  String eventKey = 'evt-1',
  int costMicros = 40,
  int revision = 101,
}) => TraceEvent(
  eventKey: eventKey,
  traceId: 'trace-1',
  runId: 'run-1',
  jobId: 'job-1',
  planId: 'plan-1',
  nodeId: 'node-1',
  attempt: 1,
  providerJobId: 'provider-job-1',
  revision: revision,
  stage: 'render',
  errorCode: 'CODEC_UNSUPPORTED',
  durationMs: 12,
  peakBytes: 64,
  thermalSummary: 'warm',
  costMicros: costMicros,
  secret: 'sk-canary',
  body: 'private prompt body',
  chainOfThought: 'hidden reasoning',
  embedding: 'emb-vector',
  sourcePath: '/Users/canary/clip.mov',
  fileName: 'clip.mov',
  exifGps: '31.2,121.5',
  signedUrl: 'https://example.invalid/grant?token=abc',
  storeToken: 'store-token-canary',
  identifiableImageHash:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  email: 'canary@example.invalid',
);

void main() {
  test('secrets, bodies, embeddings, identifiable image hashes, paths, GPS, signed URLs, store tokens, and canary emails are filtered; whitelist status fields remain', () {
    final viewer = TraceViewer();
    viewer.record(event());
    final exported = viewer.export();
    final record = exported.records.single;
    expect(record['traceId'], 'trace-1');
    expect(record['runId'], 'run-1');
    expect(record['jobId'], 'job-1');
    expect(record['revision'], 101);
    expect(record['stage'], 'render');
    expect(record['errorCode'], 'CODEC_UNSUPPORTED');
    expect(record['deviceTier'], 'mid');
    expect(record['durationMs'], 12);
    expect(record.containsKey('secret'), isFalse);
    expect(record.containsKey('body'), isFalse);
    expect(record.containsKey('chainOfThought'), isFalse);
    expect(record.containsKey('embedding'), isFalse);
    expect(record.containsKey('identifiableImageHash'), isFalse);
    expect(record.containsKey('sourcePath'), isFalse);
    expect(record.containsKey('fileName'), isFalse);
    expect(record.containsKey('exifGps'), isFalse);
    expect(record.containsKey('signedUrl'), isFalse);
    expect(record.containsKey('storeToken'), isFalse);
    expect(record.containsKey('email'), isFalse);
    final blob = record.values.map((v) => '$v').join(' ');
    expect(blob.contains('sk-canary'), isFalse);
    expect(blob.contains('private prompt body'), isFalse);
    expect(blob.contains('canary@example.invalid'), isFalse);
    expect(blob.contains('/Users/canary/clip.mov'), isFalse);
    expect(exported.productionFtsEnabled, isFalse);
    expect(exported.productionRagEnabled, isFalse);
    expect(viewer.documentWrites, 0);
  });

  test('a fault trace correlates revision and job identifiers; local export works without a telemetry backend; upload without consent is refused', () {
    final viewer = TraceViewer();
    expect(viewer.crashSdkConnected, isFalse);
    expect(viewer.defaultLogUpload, isFalse);
    viewer.record(event());
    final exported = viewer.export();
    expect(exported.records.single['traceId'], 'trace-1');
    expect(exported.records.single['revision'], 101);
    expect(exported.records.single['jobId'], 'job-1');
    expect(exported.records.single['runId'], 'run-1');
    expect(exported.records.single['planId'], 'plan-1');
    expect(exported.records.single['nodeId'], 'node-1');
    expect(exported.records.single['attempt'], 1);
    expect(exported.records.single['providerJobId'], 'provider-job-1');
    expect(exported.telemetryBackendRequired, isFalse);
    expect(exported.defaultUpload, isFalse);
    expect(exported.uploaded, isFalse);
    expect(exported.crashSdkConnected, isFalse);
    expect(
      () => viewer.export(upload: true, userConsent: false),
      code('UPLOAD_CONSENT_REQUIRED'),
    );
    expect(
      () => TraceViewer(
        config: const PrivacyRedactionConfig(filterSecrets: false),
      ).export(upload: true, userConsent: true),
      code('REDACTION_UNPROVEN'),
    );
    expect(viewer.paidApiCalled, isFalse);
    expect(viewer.submitted, isFalse);
  });

  test('duplicate events do not double-count cost; purged diagnostic bodies are not revived for debugging', () {
    final viewer = TraceViewer();
    viewer.record(event(eventKey: 'evt-dup', costMicros: 40));
    viewer.record(event(eventKey: 'evt-dup', costMicros: 40));
    viewer.record(event(eventKey: 'evt-2', costMicros: 10, revision: 102));
    final exported = viewer.export();
    expect(exported.totalCostMicros, 50);
    expect(exported.records, hasLength(3));

    viewer.purgeDiagnosticBodies(const ['evt-dup']);
    final afterPurge = viewer.export();
    expect(
      afterPurge.records.every((r) => r.containsKey('body') == false),
      isTrue,
    );
    expect(afterPurge.records, hasLength(1));
    expect(afterPurge.records.single['revision'], 102);
    expect(afterPurge.totalCostMicros, 10);
    expect(viewer.documentWrites, 0);
  });
}
