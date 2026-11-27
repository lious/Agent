import 'package:studio_context/studio_context.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

SourceUseGrant grant(
  String sourceId, {
  Set<String> permitted = const {'read', 'analyze'},
}) {
  return SourceUseGrant(
    id: 'grant-$sourceId',
    sourceId: sourceId,
    permitted: permitted,
  );
}

void main() {
  test('over-limit text is refused and is not silently truncated', () {
    final ingestor = AttachmentIngestor(
      limits: const IngestLimits(maxBytes: 32, maxChars: 16, charsPerPage: 8),
    );
    const long = 'abcdefghijklmnopqrstuvwxyz';
    expect(
      () => ingestor.stageText(id: 'att-long', text: long, displayName: 'notes.txt'),
      code(overLimit),
    );
    expect(ingestor.attachments.containsKey('att-long'), isFalse);
    final ok = ingestor.stageText(
      id: 'att-ok',
      text: 'abcdefghijklmnop',
      displayName: 'ok.txt',
    );
    expect(ok.body, 'abcdefghijklmnop');
    expect(ok.sizeBytes, 16);
    expect(ok.pages, hasLength(2));
    expect(ok.pages.first.page, 1);
    expect(ok.pages.first.startByte, 0);
    expect(ok.pages.last.endByte, 16);
  });

  test('observations and inferences stay separate and remain page or PTS traceable', () {
    final ingestor = AttachmentIngestor(
      limits: const IngestLimits(charsPerPage: 12),
    );
    final att = ingestor.stageText(
      id: 'att-demo',
      text: 'DEMO cup lid. Please look.',
      displayName: 'demo.txt',
    );
    final executor = AnalysisExecutor();
    final observationOnly = executor.execute(
      attachment: att,
      request: AnalysisRequest(id: 'req-1', attachmentId: att.id, level: 'literal'),
      grant: grant(att.id),
      now: DateTime.utc(2026, 11, 27),
    );
    expect(observationOnly.observations, isNotEmpty);
    expect(observationOnly.inferences, isEmpty);
    expect(
      observationOnly.observations.every((o) => o.evidence.every((e) => e.page != null)),
      isTrue,
    );

    final pts = EvidenceLocator(
      kind: LocatorKind.time,
      sourceId: 'att-video',
      version: 1,
      streamId: 'v0',
      startPtsMs: 2000,
      endPtsMs: 4000,
    );
    final inference = EvidenceUnit(
      id: 'inf-1',
      kind: EvidenceKind.inference,
      text: '抽样帧中杯盖位置变化，可能在旋开',
      evidence: [pts],
      supports: ['obs-req-1-p1'],
      limitations: ['2..4秒没有连续观察，不能确认完整旋开动作'],
    );
    expect(
      () => EvidenceUnit(
        id: 'inf-bad',
        kind: EvidenceKind.inference,
        text: '正在跑',
        evidence: [pts],
      ),
      code(inferenceWithoutEvidence),
    );
    final mixed = AnalysisExecutor().execute(
      attachment: att,
      request: AnalysisRequest(id: 'req-2', attachmentId: att.id, level: 'literal'),
      grant: grant(att.id),
      now: DateTime.utc(2026, 11, 27),
      extraInferences: [inference],
    );
    expect(mixed.inferences, hasLength(1));
    expect(mixed.observations.any((o) => o.text.contains('可能在旋开')), isFalse);
    final projection = ProjectionCompiler().project(id: 'proj-1', artifacts: [mixed]);
    expect(projection.complete, isTrue);
    expect(projection.chunks.any((c) => c.kind == 'observation' && c.text.contains('观察')), isTrue);
    expect(projection.chunks.any((c) => c.kind == 'inference' && c.text.contains('推断')), isTrue);
    expect(projection.chunks.any((c) => c.text.contains('pts[2000,4000)')), isTrue);
    expect(projection.chunks.any((c) => c.text.contains('page')), isTrue);
  });

  test('hash plus model parameters cache deduplicates, and a new question misses', () {
    final ingestor = AttachmentIngestor();
    final att = ingestor.stageText(
      id: 'att-cache',
      text: 'hello cache world',
      displayName: 'c.txt',
    );
    final executor = AnalysisExecutor();
    final req = AnalysisRequest(
      id: 'req-c1',
      attachmentId: att.id,
      level: 'literal',
      parameters: {'lang': 'en'},
    );
    final g = grant(att.id);
    final first = executor.execute(
      attachment: att,
      request: req,
      grant: g,
      now: DateTime.utc(2026, 11, 27),
    );
    final second = executor.execute(
      attachment: att,
      request: AnalysisRequest(
        id: 'req-c2',
        attachmentId: att.id,
        level: 'literal',
        parameters: {'lang': 'en'},
      ),
      grant: g,
      now: DateTime.utc(2026, 11, 27),
    );
    expect(second.id, first.id);
    expect(executor.executeCount, 1);
    expect(executor.cache.hitCount, 1);
    final other = executor.execute(
      attachment: att,
      request: AnalysisRequest(
        id: 'req-c3',
        attachmentId: att.id,
        level: 'literal',
        question: 'is this the lead?',
        parameters: {'lang': 'en'},
      ),
      grant: g,
      now: DateTime.utc(2026, 11, 27),
    );
    expect(other.id, isNot(first.id));
    expect(executor.executeCount, 2);
  });

  test('missing upload consent does not upload, and a license warning cannot exempt it', () {
    final ingestor = AttachmentIngestor();
    final att = ingestor.stageText(
      id: 'att-up',
      text: 'secret notes',
      displayName: 's.txt',
    );
    final analyzeOnly = grant(att.id);
    final plan = UploadPlan(id: 'plan-1', attachmentId: att.id);
    final now = DateTime.utc(2026, 11, 27);
    expect(
      () => ingestor.upload(
        attachmentId: att.id,
        grant: analyzeOnly,
        plan: plan,
        now: now,
      ),
      code(uploadConsentRequired),
    );
    expect(ingestor.networkRequestCount, 0);
    expect(
      () => ingestor.upload(
        attachmentId: att.id,
        grant: analyzeOnly,
        plan: plan,
        now: now,
        licenseWarning: true,
      ),
      code(warningDoesNotExempt),
    );
    expect(ingestor.networkRequestCount, 0);
    final allowed = grant(att.id, permitted: {'read', 'analyze', 'uploadSubset'});
    ingestor.upload(attachmentId: att.id, grant: allowed, plan: plan, now: now);
    expect(ingestor.networkRequestCount, 1);
  });

  test('a tight projection budget is partial and does not silently drop citations', () {
    final ingestor = AttachmentIngestor(limits: const IngestLimits(charsPerPage: 8));
    final att = ingestor.stageText(
      id: 'att-proj',
      text: 'abcdefghijklmnop',
      displayName: 'p.txt',
    );
    final artifact = AnalysisExecutor().execute(
      attachment: att,
      request: AnalysisRequest(id: 'req-p', attachmentId: att.id, level: 'literal'),
      grant: grant(att.id),
      now: DateTime.utc(2026, 11, 27),
    );
    expect(artifact.claims.length, greaterThan(1));
    final partial = ProjectionCompiler().project(
      id: 'proj-partial',
      artifacts: [artifact],
      maxChunks: 1,
    );
    expect(partial.complete, isFalse);
    expect(partial.omittedIds, isNotEmpty);
    expect(partial.chunks, hasLength(1));
    expect(partial.chunks.single.citationIds, isNotEmpty);
    expect(
      () => TextProjection(
        id: 'proj-bad',
        chunks: partial.chunks,
        sourceArtifactIds: [artifact.id],
        complete: true,
        omittedIds: partial.omittedIds,
      ),
      code(silentTruncateForbidden),
    );
  });

  test('unsupported or unconfigured visual analysis is explicit, not a silent model run', () {
    final ingestor = AttachmentIngestor();
    final denied = ingestor.stageBytes(
      id: 'att-bin',
      kind: MediaKind.unsupported,
      bytes: const [0, 1, 2],
      displayName: 'x.bin',
    );
    expect(denied.state, AttachmentState.unsupported);
    expect(denied.errorCode, formatUnsupported);
    final text = ingestor.stageText(id: 'att-t', text: 'hi', displayName: 't.txt');
    expect(
      () => AnalysisExecutor().execute(
        attachment: text,
        request: AnalysisRequest(
          id: 'req-v',
          attachmentId: text.id,
          level: 'visual',
        ),
        grant: grant(text.id),
        now: DateTime.utc(2026, 11, 27),
      ),
      code(modelUnavailable),
    );
    expect(
      () => AnalysisExecutor().execute(
        attachment: denied,
        request: AnalysisRequest(id: 'req-u', attachmentId: denied.id, level: 'literal'),
        grant: grant(denied.id),
        now: DateTime.utc(2026, 11, 27),
      ),
      code(formatUnsupported),
    );
  });
}
