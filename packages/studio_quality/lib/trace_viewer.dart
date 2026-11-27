import 'package:studio_contracts/studio_contracts.dart';

/// DEV-PURE I-056 privacy filter for observability traces. This is not
/// I-054 PrivacyService and not production FTS/RAG.
final class PrivacyRedactionConfig {
  const PrivacyRedactionConfig({
    this.filterSecrets = true,
    this.filterBodies = true,
    this.filterEmbeddings = true,
    this.filterIdentifiableImageHashes = true,
  });

  final bool filterSecrets,
      filterBodies,
      filterEmbeddings,
      filterIdentifiableImageHashes;
}

/// Official s10h/s12d trace event. Logs may keep hashes, meters, and
/// status, not media bodies.
final class TraceEvent {
  TraceEvent({
    required this.eventKey,
    required this.traceId,
    required this.runId,
    required this.jobId,
    required this.revision,
    this.planId,
    this.nodeId,
    this.attempt = 0,
    this.providerJobId,
    this.stage = 'planning',
    this.errorCode,
    this.durationMs,
    this.peakBytes,
    this.thermalSummary,
    this.deviceTier = 'mid',
    this.buildVersion = 'dev',
    this.costMicros = 0,
    this.secret,
    this.body,
    this.chainOfThought,
    this.embedding,
    this.sourcePath,
    this.fileName,
    this.exifGps,
    this.signedUrl,
    this.storeToken,
    this.identifiableImageHash,
    this.email,
  }) {
    requireId(eventKey);
    requireId(traceId);
    requireId(runId);
    requireId(jobId);
  }

  final String eventKey, traceId, runId, jobId, stage, deviceTier, buildVersion;
  final String? planId, nodeId, providerJobId, errorCode, thermalSummary;
  final int revision, attempt, costMicros;
  final int? durationMs, peakBytes;
  final String? secret,
      body,
      chainOfThought,
      embedding,
      sourcePath,
      fileName,
      exifGps,
      signedUrl,
      storeToken,
      identifiableImageHash,
      email;
}

final class DiagnosticExport {
  DiagnosticExport({required this.records, required this.totalCostMicros});

  final List<Map<String, Object?>> records;
  final int totalCostMicros;

  bool get defaultUpload => false;
  bool get uploaded => false;
  bool get crashSdkConnected => false;
  bool get telemetryBackendRequired => false;
  bool get productionFtsEnabled => false;
  bool get productionRagEnabled => false;
}

/// Official I-056 DiagnosticsPort / TraceViewer. Outbound upload needs
/// explicit consent. A missing telemetry backend does not block local use.
final class TraceViewer {
  TraceViewer({this.config = const PrivacyRedactionConfig()});

  final PrivacyRedactionConfig config;
  final _events = <TraceEvent>[];
  final _purgedEventKeys = <String>{};
  int documentWrites = 0;

  bool get crashSdkConnected => false;
  bool get defaultLogUpload => false;
  bool get paidApiCalled => false;
  bool get submitted => false;

  void record(TraceEvent event) {
    _events.add(event);
    documentWrites = 0;
  }

  /// Deleting a session or source clears related diagnostic bodies and
  /// must not revive them for debugging.
  void purgeDiagnosticBodies(List<String> eventKeys) {
    _purgedEventKeys.addAll(eventKeys);
    documentWrites = 0;
  }

  DiagnosticExport export({bool upload = false, bool userConsent = false}) {
    if (upload && !userConsent) {
      throw const StudioException(
        'UPLOAD_CONSENT_REQUIRED',
        'diagnosticUpload',
      );
    }
    if (upload && !_canProveRedaction()) {
      throw const StudioException('REDACTION_UNPROVEN', 'stayLocal');
    }
    final seen = <String>{};
    var cost = 0;
    final records = <Map<String, Object?>>[];
    for (final event in _events) {
      if (_purgedEventKeys.contains(event.eventKey)) continue;
      records.add(_redact(event));
      if (seen.add(event.eventKey)) {
        cost += event.costMicros;
      }
    }
    documentWrites = 0;
    return DiagnosticExport(records: records, totalCostMicros: cost);
  }

  bool _canProveRedaction() =>
      config.filterSecrets &&
      config.filterBodies &&
      config.filterEmbeddings &&
      config.filterIdentifiableImageHashes;

  Map<String, Object?> _redact(TraceEvent event) {
    return {
      'traceId': event.traceId,
      'runId': event.runId,
      'jobId': event.jobId,
      'planId': event.planId,
      'nodeId': event.nodeId,
      'attempt': event.attempt,
      'providerJobId': event.providerJobId,
      'revision': event.revision,
      'stage': event.stage,
      'errorCode': event.errorCode,
      'durationMs': event.durationMs,
      'peakBytes': event.peakBytes,
      'thermalSummary': event.thermalSummary,
      'deviceTier': event.deviceTier,
      'buildVersion': event.buildVersion,
      if (!config.filterSecrets) 'secret': event.secret,
      if (!config.filterBodies) ...{
        'body': event.body,
        'chainOfThought': event.chainOfThought,
      },
      if (!config.filterEmbeddings) 'embedding': event.embedding,
      if (!config.filterIdentifiableImageHashes)
        'identifiableImageHash': event.identifiableImageHash,
      // Source paths, filenames, EXIF GPS, signed URLs, store tokens,
      // and canary emails stay off the default whitelist.
    };
  }
}
